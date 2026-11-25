const {
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

const workerWageAccrualPrefix = "WORKER_PAYROLL:ACCRUAL:";
const workerWagePaymentPrefix = "WORKER_PAYROLL:PAYMENT:";

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
