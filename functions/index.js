const {
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

const workerWageAccrualPrefix = "WORKER_PAYROLL:ACCRUAL:";
const workerWagePaymentPrefix = "WORKER_PAYROLL:PAYMENT:";
const deletionGracePeriodMs = 30 * 24 * 60 * 60 * 1000;

function requireAuthenticatedUid(request) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in to continue.");
  }
  return request.auth.uid;
}

function accountDeletionDate(value) {
  if (value && typeof value.toDate === "function") return value.toDate();
  if (value instanceof Date) return value;
  return null;
}

function getPublicProfileData(uid, userData, authUser) {
  const profile = {
    uid,
    phoneNumber: authUser.phoneNumber || userData.phoneNumber || null,
    displayName:
      userData.displayName || userData.name || authUser.displayName || null,
    photoURL:
      userData.photoURL ||
      userData.photoUrl ||
      userData.profileImage ||
      authUser.photoURL ||
      null,
    profession: userData.profession || null,
    businessAddress:
      userData.businessAddress ||
      userData.address ||
      userData.shopAddress ||
      userData.storeAddress ||
      userData.location ||
      null,
    shopName: userData.shopName || userData.storeName || null,
  };
  return Object.fromEntries(
    Object.entries(profile).filter(([, value]) => value != null),
  );
}

exports.requestAccountDeletion = onCall(async (request) => {
  const uid = requireAuthenticatedUid(request);
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const deletionRef = db.collection("account_deletion_requests").doc(uid);
  const profileRef = db.collection("public_profiles").doc(uid);
  const authUser = await admin.auth().getUser(uid);
  const now = admin.firestore.Timestamp.now();

  const deleteAfter = await db.runTransaction(async (transaction) => {
    const [userSnapshot, deletionSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(deletionRef),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError("failed-precondition", "Account data was not found.");
    }

    const userData = userSnapshot.data();
    const existingDeadline = accountDeletionDate(userData.restoreDeadline);
    let deadline;
    if (userData.isDeactivated === true) {
      if (deletionSnapshot.exists) {
        deadline = accountDeletionDate(deletionSnapshot.data().deleteAfter);
      } else {
        deadline = existingDeadline;
      }
      if (!deadline || deadline.getTime() <= now.toMillis()) {
        throw new HttpsError(
          "failed-precondition",
          "The account recovery period has ended.",
        );
      }
    } else {
      deadline = new Date(now.toMillis() + deletionGracePeriodMs);
    }

    const deadlineTimestamp =
      admin.firestore.Timestamp.fromDate(deadline);
    if (userData.isDeactivated !== true || !deletionSnapshot.exists) {
      transaction.set(deletionRef, {
        uid,
        phoneNumber: authUser.phoneNumber || userData.phoneNumber || null,
        email: authUser.email || userData.email || null,
        requestedAt: now,
        deleteAfter: deadlineTimestamp,
        status: "pending",
      });
    }
    if (userData.isDeactivated !== true) {
      transaction.update(userRef, {
        isDeactivated: true,
        deactivatedAt: now,
        restoreDeadline: deadlineTimestamp,
      });
    }
    transaction.delete(profileRef);
    return deadline.getTime();
  });

  return {deleteAfter};
});

exports.restoreAccountDeletion = onCall(async (request) => {
  const uid = requireAuthenticatedUid(request);
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const deletionRef = db.collection("account_deletion_requests").doc(uid);
  const profileRef = db.collection("public_profiles").doc(uid);
  const authUser = await admin.auth().getUser(uid);
  const now = admin.firestore.Timestamp.now();

  await db.runTransaction(async (transaction) => {
    const [userSnapshot, deletionSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(deletionRef),
    ]);
    if (!userSnapshot.exists || userSnapshot.data().isDeactivated !== true) {
      throw new HttpsError(
        "failed-precondition",
        "There is no pending account deletion to restore.",
      );
    }

    const userData = userSnapshot.data();
    const deadline = deletionSnapshot.exists
      ? accountDeletionDate(deletionSnapshot.data().deleteAfter)
      : accountDeletionDate(userData.restoreDeadline);
    if (
      !deadline ||
      deadline.getTime() <= now.toMillis() ||
      deletionSnapshot.data()?.status === "purging"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The account recovery period has ended.",
      );
    }

    transaction.update(userRef, {
      isDeactivated: false,
      deactivatedAt: admin.firestore.FieldValue.delete(),
      restoreDeadline: admin.firestore.FieldValue.delete(),
    });
    if (deletionSnapshot.exists) transaction.delete(deletionRef);
    transaction.set(
      profileRef,
      getPublicProfileData(uid, userData, authUser),
    );
  });

  return {restored: true};
});

async function deleteQueryResults(query, pageSize = 200) {
  while (true) {
    const snapshot = await query.limit(pageSize).get();
    if (snapshot.empty) return;
    for (let index = 0; index < snapshot.docs.length; index += 400) {
      const batch = admin.firestore().batch();
      snapshot.docs.slice(index, index + 400).forEach((document) => {
        batch.delete(document.ref);
      });
      await batch.commit();
    }
  }
}

async function deleteUserData(uid, deletionRequest) {
  const db = admin.firestore();
  const userRef = db.collection("users").doc(uid);
  const identity = {
    phoneNumber: deletionRequest.phoneNumber || null,
    email: deletionRequest.email || null,
  };
  try {
    const authUser = await admin.auth().getUser(uid);
    identity.phoneNumber = identity.phoneNumber || authUser.phoneNumber || null;
    identity.email = identity.email || authUser.email || null;
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }

  const ownMappings = await userRef.collection("workerWageMirrors").get();
  for (let index = 0; index < ownMappings.docs.length; index += 150) {
    const batch = db.batch();
    ownMappings.docs.slice(index, index + 150).forEach((mappingDocument) => {
      const mapping = mappingDocument.data();
      if (mapping.recipientUid && mapping.mirrorTransactionId) {
        const recipientRef = db.collection("users").doc(mapping.recipientUid);
        batch.delete(
          recipientRef
            .collection("transactions")
            .doc(mapping.mirrorTransactionId),
        );
        if (mapping.notificationId) {
          batch.delete(
            recipientRef
              .collection("notifications")
              .doc(mapping.notificationId),
          );
        }
      }
      batch.delete(mappingDocument.ref);
    });
    await batch.commit();
  }

  await deleteQueryResults(
    db.collectionGroup("workerWageMirrors")
      .where("recipientUid", "==", uid),
  );
  await deleteQueryResults(
    db.collectionGroup("notifications")
      .where("data.senderUid", "==", uid),
  );
  await deleteQueryResults(
    db.collectionGroup("reports")
      .where("reporterId", "==", uid),
  );

  await deleteQueryResults(
    db.collectionGroup("reviews").where("userId", "==", uid),
  );

  const listingsQuery = db.collection("marketplace_listings")
    .where("ownerId", "==", uid);
  while (true) {
    const listings = await listingsQuery.limit(10).get();
    if (listings.empty) break;
    await Promise.all(
      listings.docs.map((listing) =>
        db.recursiveDelete(listing.ref),
      ),
    );
  }

  const publicShopRef = db.collection("public_shops").doc(uid);
  await db.recursiveDelete(publicShopRef);

  const userDataIds = new Set([uid]);
  if (identity.phoneNumber) {
    phoneLookupCandidates(identity.phoneNumber).forEach((candidate) => {
      userDataIds.add(candidate);
    });
  }
  if (identity.email) userDataIds.add(identity.email.toLowerCase());
  for (const identifier of userDataIds) {
    const legacyDataRef = db.collection("userData").doc(identifier);
    const legacyDataSnapshot = await legacyDataRef.get();
    if (legacyDataSnapshot.exists) await db.recursiveDelete(legacyDataRef);
  }

  const backupRef = db.collection("backups").doc(uid);
  await db.recursiveDelete(backupRef);

  const bucket = admin.storage().bucket();
  await bucket.deleteFiles({prefix: `users/${uid}/`});
  await bucket.deleteFiles({prefix: `marketplace/${uid}/`});

  try {
    await admin.auth().deleteUser(uid);
  } catch (error) {
    if (error.code !== "auth/user-not-found") throw error;
  }

  await db.recursiveDelete(userRef);
}

async function enqueueLegacyDeletionRequests() {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const activeDeactivations = await db.collection("users")
    .where("isDeactivated", "==", true)
    .where("restoreDeadline", "<=", now)
    .limit(200)
    .get();
  for (const userDocument of activeDeactivations.docs) {
    const deletionRef = db.collection("account_deletion_requests")
      .doc(userDocument.id);
    const deletionSnapshot = await deletionRef.get();
    if (deletionSnapshot.exists) continue;

    const userData = userDocument.data();
    const deadline = accountDeletionDate(userData.restoreDeadline);
    if (!deadline) {
      console.error(
        `Cannot schedule legacy deactivated account ${userDocument.id}: missing recovery deadline`,
      );
      continue;
    }
    let authUser = null;
    try {
      authUser = await admin.auth().getUser(userDocument.id);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
    await db.runTransaction(async (transaction) => {
      const [currentUserSnapshot, currentDeletionSnapshot] = await Promise.all([
        transaction.get(userDocument.ref),
        transaction.get(deletionRef),
      ]);
      if (
        !currentUserSnapshot.exists ||
        currentUserSnapshot.data().isDeactivated !== true ||
        currentDeletionSnapshot.exists
      ) {
        return;
      }

      transaction.create(deletionRef, {
        uid: userDocument.id,
        phoneNumber:
          authUser?.phoneNumber || userData.phoneNumber || null,
        email: authUser?.email || userData.email || null,
        requestedAt: accountDeletionDate(userData.deactivatedAt) || new Date(),
        deleteAfter: admin.firestore.Timestamp.fromDate(deadline),
        status: "pending",
      });
    });
  }
}

exports.purgeExpiredAccountDeletions = onSchedule(
  {
    schedule: "every 6 hours",
    timeZone: "UTC",
    timeoutSeconds: 540,
    memory: "512MiB",
  },
  async () => {
    const db = admin.firestore();
    await enqueueLegacyDeletionRequests();
    const expiredRequests = await db.collection("account_deletion_requests")
      .where("deleteAfter", "<=", admin.firestore.Timestamp.now())
      .limit(20)
      .get();

    for (const deletionDocument of expiredRequests.docs) {
      const deletionRef = deletionDocument.ref;
      const shouldPurge = await db.runTransaction(async (transaction) => {
        const latest = await transaction.get(deletionRef);
        if (!latest.exists) return false;
        const data = latest.data();
        const deadline = accountDeletionDate(data.deleteAfter);
        const now = admin.firestore.Timestamp.now();
        const leaseUntil = accountDeletionDate(data.purgingUntil);
        if (
          !deadline ||
          deadline.getTime() > now.toMillis() ||
          leaseUntil?.getTime() > now.toMillis()
        ) {
          return false;
        }
        transaction.set(
          deletionRef,
          {
            status: "purging",
            lastAttemptAt: now,
            purgingUntil: admin.firestore.Timestamp.fromMillis(
              now.toMillis() + 12 * 60 * 1000,
            ),
          },
          {merge: true},
        );
        return true;
      });
      if (!shouldPurge) continue;

      try {
        await deleteUserData(deletionDocument.id, deletionDocument.data());
        await deletionRef.delete();
      } catch (error) {
        console.error(
          `Failed to purge account ${deletionDocument.id}:`,
          error,
        );
        await deletionRef.set(
          {
            status: "pending",
            lastAttemptAt: admin.firestore.Timestamp.now(),
            purgingUntil: admin.firestore.FieldValue.delete(),
          },
          {merge: true},
        );
      }
    }
  },
);

function phoneLookupCandidates(phone) {
  const trimmed = typeof phone === "string" ? phone.trim() : "";
  const digits = trimmed.replace(/\D/g, "");
  if (!digits) return [];

  const candidates = new Set([trimmed, digits]);
  if (trimmed.startsWith("+")) candidates.add(`00${digits}`);
  if (digits.startsWith("00") && digits.length > 4) {
    candidates.add(`+${digits.slice(2)}`);
  }
  if (digits.startsWith("92") && digits.length >= 12) {
    candidates.add(`+${digits}`);
    candidates.add(`0${digits.slice(2)}`);
    candidates.add(digits.slice(2));
  } else if (digits.startsWith("0") && digits.length === 11) {
    candidates.add(`+92${digits.slice(1)}`);
    candidates.add(`92${digits.slice(1)}`);
    candidates.add(digits.slice(1));
  } else if (digits.startsWith("3") && digits.length === 10) {
    candidates.add(`+92${digits}`);
    candidates.add(`92${digits}`);
    candidates.add(`0${digits}`);
  }
  return [...candidates].filter(Boolean).slice(0, 30);
}

async function findUserByPhone(db, phone) {
  const candidates = phoneLookupCandidates(phone);
  if (candidates.length === 0) return null;

  const snapshot = await db
    .collection("users")
    .where("phoneNumber", "in", candidates)
    .limit(2)
    .get();
  if (snapshot.size > 1) {
    console.error(`Multiple app users match phone number ${phone}`);
    return null;
  }
  return snapshot.empty ? null : snapshot.docs[0];
}

async function findAccountByPhone(accountsRef, phone) {
  const candidates = phoneLookupCandidates(phone);
  if (candidates.length === 0) return null;

  const snapshot = await accountsRef
    .where("phone", "in", candidates)
    .get();
  if (snapshot.empty) return null;

  return snapshot.docs.sort((first, second) =>
    first.id.localeCompare(second.id),
  )[0];
}

async function removeWorkerWageMirror(db, senderUid, transactionId, mapping) {
  const batch = db.batch();
  if (mapping?.recipientUid && mapping?.mirrorTransactionId) {
    const recipientRef = db.collection("users").doc(mapping.recipientUid);
    batch.delete(
      recipientRef.collection("transactions").doc(mapping.mirrorTransactionId),
    );
    if (mapping.notificationId) {
      batch.delete(
        recipientRef.collection("notifications").doc(mapping.notificationId),
      );
    }
  }
  batch.delete(
    db.collection("users")
      .doc(senderUid)
      .collection("workerWageMirrors")
      .doc(transactionId),
  );
  await batch.commit();
}

exports.aggregateShopReview = onDocumentWritten(
  "public_shops/{shopId}/reviews/{userId}",
  async (event) => {
    const db = admin.firestore();
    const shopRef = db.collection("public_shops").doc(event.params.shopId);
    const reviewRef = shopRef.collection("reviews").doc(event.params.userId);
    const stateRef = shopRef
      .collection("_rating_state")
      .doc(event.params.userId);

    await db.runTransaction(async (transaction) => {
      const [shopSnapshot, reviewSnapshot, stateSnapshot] = await Promise.all([
        transaction.get(shopRef),
        transaction.get(reviewRef),
        transaction.get(stateRef),
      ]);
      if (!shopSnapshot.exists) return;

      const previousRating = stateSnapshot.exists
        ? Number(stateSnapshot.data().rating)
        : null;
      const currentValue = reviewSnapshot.exists
        ? Number(reviewSnapshot.data().rating)
        : null;
      const currentRating =
        Number.isInteger(currentValue) && currentValue >= 1 && currentValue <= 5
          ? currentValue
          : null;
      if (previousRating === currentRating) return;

      const shop = shopSnapshot.data();
      const oldTotal = Number(shop.communityRatingTotal) || 0;
      const oldCount = Number(shop.communityReviewCount) || 0;
      const ratingTotal = Math.max(
        0,
        oldTotal - (previousRating || 0) + (currentRating || 0),
      );
      const reviewCount = Math.max(
        0,
        oldCount - (previousRating == null ? 0 : 1) +
          (currentRating == null ? 0 : 1),
      );

      transaction.update(shopRef, {
        communityRatingTotal: ratingTotal,
        communityReviewCount: reviewCount,
        communityRating: reviewCount > 0 ? ratingTotal / reviewCount : 0,
      });
      if (currentRating == null) {
        if (stateSnapshot.exists) transaction.delete(stateRef);
      } else {
        transaction.set(stateRef, { rating: currentRating });
      }
    });
  },
);
exports.syncWorkerAttendanceWage = onDocumentWritten(
  {
    document: "users/{senderUid}/transactions/{transactionId}",
    retry: false,
  },
  async (event) => {
    const db = admin.firestore();
    const {senderUid, transactionId} = event.params;
    const transactionRef = db
      .collection("users")
      .doc(senderUid)
      .collection("transactions")
      .doc(transactionId);
    const mappingRef = db
      .collection("users")
      .doc(senderUid)
      .collection("workerWageMirrors")
      .doc(transactionId);
    const [transactionSnapshot, mappingSnapshot] = await Promise.all([
      transactionRef.get(),
      mappingRef.get(),
    ]);
    const mapping = mappingSnapshot.exists ? mappingSnapshot.data() : null;
    const source = transactionSnapshot.exists
      ? transactionSnapshot.data()
      : null;

    if (source?.receiptFromCounterparty === true) return null;

    const referenceNumber = String(source?.referenceNumber || "");
    const isWorkerWageAccrual =
      source?.id === transactionId &&
      source.type === "income" &&
      source.category === "حاضری کی واجب اجرت" &&
      referenceNumber.startsWith(workerWageAccrualPrefix);
    const isWorkerWagePayment =
      source?.id === transactionId &&
      source.type === "expense" &&
      source.category === "اجرت کی ادائیگی" &&
      referenceNumber.startsWith(workerWagePaymentPrefix);
    const amount = Number(source?.amount);
    if (
      (!isWorkerWageAccrual && !isWorkerWagePayment) ||
      !Number.isFinite(amount) ||
      amount <= 0
    ) {
      if (mapping) {
        await removeWorkerWageMirror(db, senderUid, transactionId, mapping);
      }
      return null;
    }

    const senderRef = db.collection("users").doc(senderUid);
    const workerAccountId = String(source.accountId || "");
    if (!workerAccountId) {
      console.error(
        `Worker account ID missing for wage transaction ${transactionId}`,
      );
      if (mapping) {
        await removeWorkerWageMirror(db, senderUid, transactionId, mapping);
      }
      return null;
    }
    const workerAccountRef = senderRef
      .collection("accounts")
      .doc(workerAccountId);
    const [senderSnapshot, workerAccountSnapshot] = await Promise.all([
      senderRef.get(),
      workerAccountRef.get(),
    ]);
    if (!workerAccountSnapshot.exists) {
      console.error(
        `Worker account missing for wage transaction ${transactionId}`,
      );
      if (mapping) {
        await removeWorkerWageMirror(db, senderUid, transactionId, mapping);
      }
      return null;
    }

    const workerAccount = workerAccountSnapshot.data();
    const workerCategory = String(workerAccount.category || "").toLowerCase();
    if (
      !["worker", "technician", "employee", "مزدور"].includes(workerCategory)
    ) {
      console.log(`Skipping non-worker wage transaction ${transactionId}`);
      if (mapping) {
        await removeWorkerWageMirror(db, senderUid, transactionId, mapping);
      }
      return null;
    }

    const recipientSnapshot = await findUserByPhone(db, workerAccount.phone);
    if (!recipientSnapshot) {
      console.log(
        `No app account found for worker in transaction ${transactionId}`,
      );
      if (mapping) {
        await removeWorkerWageMirror(db, senderUid, transactionId, mapping);
      }
      return null;
    }

    const senderData = senderSnapshot.data() || {};
    const [senderAuthUser, senderProfileSnapshot] = await Promise.all([
      admin.auth().getUser(senderUid),
      db.collection("public_profiles").doc(senderUid).get(),
    ]);
    const senderProfile = senderProfileSnapshot.data() || {};
    const senderPhone = String(
      senderAuthUser.phoneNumber ||
        senderData.phoneNumber ||
        senderProfile.phoneNumber ||
        "",
    );
    if (!senderPhone) {
      console.error(
        `Sender phone missing for wage transaction ${transactionId}`,
      );
      if (mapping) {
        await removeWorkerWageMirror(db, senderUid, transactionId, mapping);
      }
      return null;
    }

    const recipientRef = recipientSnapshot.ref;
    const recipientAccountsRef = recipientRef.collection("accounts");
    let counterpartyAccount = await findAccountByPhone(
      recipientAccountsRef,
      senderPhone,
    );
    const now = admin.firestore.Timestamp.now();
    const senderName = String(
      senderProfile.displayName ||
        senderProfile.shopName ||
        senderAuthUser.displayName ||
        senderPhone,
    );
    const batch = db.batch();

    if (!counterpartyAccount) {
      const accountId = `employer_${senderUid}`;
      const accountRef = recipientAccountsRef.doc(accountId);
      const account = {
        id: accountId,
        name: senderName,
        phone: senderPhone,
        address: "",
        category: "Customer",
        initialBalance: 0,
        balanceType: "none",
        balance: 0,
        settlementNotes: {},
        profileImage: senderData.photoURL || senderAuthUser?.photoURL || null,
        createdAt: now,
        updatedAt: now,
        isActive: true,
      };
      batch.set(accountRef, account, {merge: true});
      counterpartyAccount = {id: accountId, ref: accountRef};
    }

    const mirrorTransactionId = `worker_wage_${senderUid}_${transactionId}`;
    const notificationId = isWorkerWageAccrual
      ? `worker_wage_${senderUid}_${transactionId}`
      : `transaction_${senderUid}_${transactionId}`;
    const hasExistingMapping =
      mapping?.recipientUid && mapping.recipientUid !== recipientRef.id;
    const mirrorTransaction = {
      ...source,
      id: mirrorTransactionId,
      accountId: counterpartyAccount.id,
      amount,
      type: isWorkerWageAccrual ? "expense" : "income",
      receivedAmount: 0,
      pendingAmount: isWorkerWageAccrual ? amount : 0,
      paymentMethod: isWorkerWageAccrual
        ? "credit"
        : String(source.paymentMethod || "cash"),
      isPending: isWorkerWageAccrual,
      receiptFromCounterparty: true,
      updatedAt: now,
    };
    if (hasExistingMapping) {
      const previousRecipientRef = db
        .collection("users")
        .doc(mapping.recipientUid);
      batch.delete(
        previousRecipientRef
          .collection("transactions")
          .doc(mapping.mirrorTransactionId),
      );
      if (mapping.notificationId) {
        batch.delete(
          previousRecipientRef
            .collection("notifications")
            .doc(mapping.notificationId),
        );
      }
    }
    batch.set(
      recipientRef.collection("transactions").doc(mirrorTransactionId),
      mirrorTransaction,
    );
    if (!mapping || hasExistingMapping) {
      const sourceDate = source.date instanceof admin.firestore.Timestamp
        ? source.date.toDate().toISOString()
        : String(source.date || now.toDate().toISOString());
      const notification = {
        id: notificationId,
        title: isWorkerWageAccrual
          ? "حاضری کی اجرت درج ہوئی"
          : "مزدوری کی ادائیگی درج ہوئی",
        message: isWorkerWageAccrual
          ? `${senderName} نے حاضری کی واجب اجرت Rs. ${amount.toFixed(0)} درج کی`
          : `${senderName} نے مزدوری کی ادائیگی Rs. ${amount.toFixed(0)} درج کی`,
        type: "transaction",
        timestamp: now,
        data: {
          amount: String(amount),
          transactionType: String(source.type),
          category: String(source.category),
          paymentMethod: mirrorTransaction.paymentMethod,
          senderName,
          senderPhone,
          senderUid,
          senderPhotoUrl:
            senderData.photoURL || senderAuthUser?.photoURL || null,
          description: String(source.description || "حاضری کی واجب اجرت"),
          items: [],
          receivedAmount: isWorkerWageAccrual ? "0" : String(amount),
          pendingAmount: String(mirrorTransaction.pendingAmount),
          transactionId: mirrorTransactionId,
          transactionDate: sourceDate,
          referenceNumber: source.referenceNumber,
          subtotal: String(amount),
          discountAmount: "0",
          discountPercent: null,
          discountReason: null,
          isAdded: true,
        },
        relatedAccountId: counterpartyAccount.id,
        relatedTransactionId: mirrorTransactionId,
      };
      batch.set(
        recipientRef.collection("notifications").doc(notificationId),
        {
          ...notification,
          isRead: false,
        },
        {merge: true},
      );
    }
    batch.set(mappingRef, {
      recipientUid: recipientRef.id,
      accountId: counterpartyAccount.id,
      mirrorTransactionId,
      notificationId,
      updatedAt: now,
    });
    await batch.commit();
    return null;
  },
);
