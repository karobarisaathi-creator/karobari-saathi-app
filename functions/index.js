const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotificationOnCreate = onDocumentCreated(
  "users/{userId}/notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      console.log("No data associated with the event");
      return null;
    }

    const notification = snapshot.data();
    const userId = event.params.userId;
    const userRef = admin.firestore().collection("users").doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
      console.log(`Notification recipient not found: ${userId}`);
      return null;
    }

    const userData = userDoc.data();
    const tokens = [
      ...new Set([
        ...(Array.isArray(userData.fcmTokens) ? userData.fcmTokens : []),
        ...(typeof userData.fcmToken === "string" ? [userData.fcmToken] : []),
      ]),
    ].filter((token) => typeof token === "string" && token.length > 0);

    if (tokens.length === 0) {
      console.log(`No FCM token found for user: ${userId}`);
      return null;
    }

    const dataPayload = {
      click_action: "FLUTTER_NOTIFICATION_CLICK",
      type: String(notification.type || "general"),
      notificationId: String(event.params.notificationId),
    };

    if (notification.data && typeof notification.data === "object") {
      for (const [key, value] of Object.entries(notification.data)) {
        if (value == null) continue;
        dataPayload[key] =
          typeof value === "string" ? value : JSON.stringify(value);
      }
    }

    const message = {
      tokens,
      notification: {
        title: String(notification.title || "نیا نوٹیفیکیشن"),
        body: String(
          notification.message || "آپ کے اکاؤنٹ میں نئی سرگرمی ہوئی ہے",
        ),
      },
      data: dataPayload,
      android: {
        priority: "high",
        ttl: 24 * 60 * 60 * 1000,
        notification: {
          channelId: "account_channel",
          sound: "default",
        },
      },
      apns: {
        headers: {
          "apns-priority": "10",
        },
        payload: {
          aps: {
            sound: "default",
          },
        },
      },
    };

    try {
      const invalidTokens = [];
      let successCount = 0;
      let failureCount = 0;

      for (let offset = 0; offset < tokens.length; offset += 500) {
        const tokenBatch = tokens.slice(offset, offset + 500);
        const response = await admin.messaging().sendEachForMulticast({
          ...message,
          tokens: tokenBatch,
        });
        successCount += response.successCount;
        failureCount += response.failureCount;

        response.responses.forEach((result, index) => {
          if (result.success) return;

          const code = result.error?.code;
          console.error(
            `FCM delivery failed for ${userId}: ${code || result.error}`,
          );
          if (
            code === "messaging/invalid-registration-token" ||
            code === "messaging/registration-token-not-registered"
          ) {
            invalidTokens.push(tokenBatch[index]);
          }
        });
      }

      if (invalidTokens.length > 0) {
        const updates = {
          fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        };
        if (
          typeof userData.fcmToken === "string" &&
          invalidTokens.includes(userData.fcmToken)
        ) {
          updates.fcmToken = admin.firestore.FieldValue.delete();
        }
        await userRef.update(updates);
      }

      console.log(
        `FCM notification ${event.params.notificationId}: ` +
          `${successCount} sent, ${failureCount} failed`,
      );
    } catch (error) {
      console.error(
        `Error sending notification ${event.params.notificationId}:`,
        error,
      );
      throw error;
    }
  },
);
