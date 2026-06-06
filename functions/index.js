const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendNotificationOnCreate = onDocumentCreated("users/{userId}/notifications/{notificationId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
        console.log("No data associated with the event");
        return;
    }

    const notification = snapshot.data();
    const userId = event.params.userId;

    // 1. صارف کا FCM ٹوکن حاصل کریں
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists) {
        console.log('User not found');
        return null;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
        console.log('No Token found for user: ', userId);
        return null;
    }

    // Data payload setup
    let dataPayload = {
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
        type: notification.type || 'general',
    };
    
    // Merge extra data if available (convert values to string for FCM)
    if (notification.data) {
        for (const [key, value] of Object.entries(notification.data)) {
            dataPayload[key] = String(value);
        }
    }

    // 2. میسج تیار کریں
    const payload = {
      notification: {
        title: notification.title || 'نیا نوٹیفکیشن',
        body: notification.message || 'آپ کے اکاؤنٹ میں نئی سرگرمی ہوئی ہے',
        sound: 'default',
        android_channel_id: 'account_channel', 
      },
      data: dataPayload
    };

    // سکرین آف پر جگانے کے لیے یہ آپشنز لازمی ہیں
    const options = {
        priority: "high",
        timeToLive: 60 * 60 * 24
    };

    // 3. میسج بھیجیں
    try {
      const response = await admin.messaging().sendToDevice(fcmToken, payload, options);
      console.log('Successfully sent message:', response);
    } catch (error) {
      console.log('Error sending message:', error);
    }
});
