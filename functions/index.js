const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

function getPhoneVariants(rawPhone) {
  if (!rawPhone) return [];
  const cleaned = String(rawPhone).replace(/[\s\-()]/g, "");
  if (!cleaned) return [];
  const variants = new Set([cleaned]);
  if (cleaned.startsWith("05") && cleaned.length === 10) {
    variants.add("971" + cleaned.substring(1));
    variants.add("+971" + cleaned.substring(1));
  } else if (cleaned.startsWith("9715") && cleaned.length === 12) {
    variants.add("0" + cleaned.substring(3));
    variants.add("+" + cleaned);
  } else if (cleaned.startsWith("+9715") && cleaned.length === 13) {
    variants.add("0" + cleaned.substring(4));
    variants.add(cleaned.substring(1));
  }
  return Array.from(variants);
}

exports.deleteAuthUser = functions.firestore
  .document("users/{userId}")
  .onDelete(async (snap, context) => {
    const userId = context.params.userId;
    const deletedData = snap.data() || {};
    console.log(`Firestore document for user ${userId} was deleted.`);

    try {
      await admin.auth().deleteUser(userId);
      console.log(`Successfully deleted auth user: ${userId}`);
    } catch (error) {
      if (error.code === 'auth/user-not-found') {
        console.log(`Auth user ${userId} does not exist, nothing to delete.`);
      } else {
        console.error(`Error deleting auth user ${userId}:`, error);
      }
    }

    // Clean up phone_index entries belonging to this user
    try {
      const db = admin.firestore();
      const batch = db.batch();
      let hasDeletes = false;

      const byUidSnap = await db.collection("phone_index").where("uid", "==", userId).get();
      byUidSnap.forEach((doc) => {
        batch.delete(doc.ref);
        hasDeletes = true;
      });

      const phoneVariants = getPhoneVariants(deletedData.phone);
      for (const variant of phoneVariants) {
        const ref = db.collection("phone_index").doc(variant);
        const snapDoc = await ref.get();
        if (
          snapDoc.exists &&
          (snapDoc.data().uid === userId ||
            (deletedData.email && snapDoc.data().email === String(deletedData.email).trim().toLowerCase()))
        ) {
          batch.delete(ref);
          hasDeletes = true;
        }
      }

      if (hasDeletes) {
        await batch.commit();
      }
    } catch (cleanupErr) {
      console.error(`Error cleaning up phone_index for ${userId}:`, cleanupErr);
    }
  });

exports.createTechnician = functions.https.onCall(async (data, context) => {
  // Check if the user making the request is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  // 🛡️ Security Check: Ensure caller is an admin
  const callerDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only administrators can create technician accounts.'
    );
  }

  const { name, email, password, phone, profession } = data;

  if (!email || !password || !name) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'The function must be called with name, email, and password.'
    );
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  const trimmedName = String(name).trim();
  const trimmedPhone = phone ? String(phone).trim() : '';

  try {
    // Create the user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: normalizedEmail,
      password: password,
      displayName: trimmedName,
    });

    const db = admin.firestore();

    // Save the user data in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      name: trimmedName,
      email: normalizedEmail,
      phone: trimmedPhone,
      profession: profession || '',
      role: 'technician',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Index technician phone variants in phone_index for phone-based login
    const phoneVariants = getPhoneVariants(trimmedPhone);
    if (phoneVariants.length > 0) {
      const batch = db.batch();
      for (const variant of phoneVariants) {
        batch.set(db.collection('phone_index').doc(variant), {
          email: normalizedEmail,
          uid: userRecord.uid,
        });
      }
      await batch.commit();
    }

    return { success: true, uid: userRecord.uid };
  } catch (error) {
    console.error('Error creating technician:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Trigger on new notification document
exports.sendPushNotification = functions.firestore
  .document("notifications/{docId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = notification.userId;
    const title = notification.title || "Elite Living";
    const message = notification.message || "";
    const relatedTaskId = notification.relatedTaskId || "";

    if (!userId) {
      console.log('No user ID found in notification.');
      return null;
    }

    try {
      // Get user document to retrieve fcmToken
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) {
        console.log(`User ${userId} not found.`);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData.fcmToken;

      if (!fcmToken) {
        console.log(`User ${userId} does not have an FCM token.`);
        return null;
      }

      // Send Push Notification via FCM
      const payload = {
        notification: {
          title: title,
          body: message,
        },
        data: {
          title: String(title),
          body: String(message),
          relatedTaskId: String(relatedTaskId),
          chatId: String(relatedTaskId),
          userId: String(userId),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'high_importance_channel',
            sound: 'default',
            priority: 'max',
            defaultSound: true,
            defaultVibrateTimings: true,
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
            'apns-push-type': 'alert',
          },
          payload: {
            aps: {
              alert: {
                title: String(title),
                body: String(message),
              },
              sound: 'default',
              badge: 1,
              'content-available': 1,
            },
          },
        },
        token: fcmToken,
      };

      const response = await admin.messaging().send(payload);
      console.log(`Successfully sent push notification to user ${userId}:`, response);
    } catch (error) {
      if (error.code === 'messaging/registration-token-not-registered') {
        console.log(`Token for user ${userId} expired. Cleaning up.`);
        await admin.firestore().collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete()
        });
      } else {
        console.error('Error sending push notification:', error);
      }
    }
    return null;
  });
