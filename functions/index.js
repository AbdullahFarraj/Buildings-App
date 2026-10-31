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

    // Clean up user_tokens and phone_index entries belonging to this user
    try {
      const db = admin.firestore();
      const batch = db.batch();
      let hasDeletes = true;

      batch.delete(db.collection("user_tokens").doc(userId));

      const byUidSnap = await db.collection("phone_index").where("uid", "==", userId).get();
      byUidSnap.forEach((doc) => {
        batch.delete(doc.ref);
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
        }
      }

      if (hasDeletes) {
        await batch.commit();
      }
    } catch (cleanupErr) {
      console.error(`Error cleaning up phone_index / user_tokens for ${userId}:`, cleanupErr);
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
  const db = admin.firestore();
  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (!callerDoc.exists || callerDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only administrators can create technician accounts.'
    );
  }

  const { name, email, password, phone, profession } = data || {};

  if (!email || !password || !name) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'The function must be called with name, email, and password.'
    );
  }

  if (String(password).length < 6) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Password must be at least 6 characters long.'
    );
  }

  const normalizedEmail = String(email).trim().toLowerCase();
  const trimmedName = String(name).trim();
  const trimmedPhone = phone ? String(phone).trim() : '';
  const phoneVariants = getPhoneVariants(trimmedPhone);

  // Verify phone number is not already claimed by another user
  for (const variant of phoneVariants) {
    const existingPhoneDoc = await db.collection('phone_index').doc(variant).get();
    if (existingPhoneDoc.exists) {
      const existingData = existingPhoneDoc.data() || {};
      if (existingData.email && existingData.email !== normalizedEmail) {
        throw new functions.https.HttpsError(
          'already-exists',
          'This phone number is already linked to another account.'
        );
      }
    }
  }

  try {
    // Create the user in Firebase Auth
    const userRecord = await admin.auth().createUser({
      email: normalizedEmail,
      password: String(password),
      displayName: trimmedName,
    });

    // Set role custom claim for fast Storage & Firestore rule checks
    await admin.auth().setCustomUserClaims(userRecord.uid, { role: 'technician' });

    // Save the user data in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      name: trimmedName,
      email: normalizedEmail,
      phone: trimmedPhone,
      profession: profession ? String(profession).trim() : '',
      role: 'technician',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Index technician phone variants in phone_index for phone-based login
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
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    throw new functions.https.HttpsError('internal', error.message || 'Failed to create technician.');
  }
});

// Trigger on new notification document
exports.sendPushNotification = functions.firestore
  .document("notifications/{docId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = notification.userId;
    const senderId = notification.senderId;
    const title = notification.title || "Elite Living";
    const message = notification.message || "";
    const relatedTaskId = notification.relatedTaskId || "";

    if (!userId) {
      console.log('No user ID found in notification.');
      return null;
    }

    // Do not notify the user if they triggered the event themselves
    if (senderId && senderId === userId) {
      console.log(`Skipping notification for user ${userId} because senderId equals userId.`);
      return null;
    }

    const db = admin.firestore();

    try {
      // Retrieve fcmToken from isolated user_tokens collection first, fallback to users/{userId}
      let fcmToken = null;
      const tokenDoc = await db.collection('user_tokens').doc(userId).get();
      if (tokenDoc.exists && tokenDoc.data()?.fcmToken) {
        fcmToken = tokenDoc.data().fcmToken;
      } else {
        const userDoc = await db.collection('users').doc(userId).get();
        if (!userDoc.exists) {
          console.log(`User ${userId} not found.`);
          return null;
        }
        fcmToken = userDoc.data()?.fcmToken || null;
      }

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
        await db.collection('user_tokens').doc(userId).delete().catch(() => {});
        await db.collection('users').doc(userId).update({
          fcmToken: admin.firestore.FieldValue.delete()
        }).catch(() => {});
      } else {
        console.error('Error sending push notification:', error);
      }
    }
    return null;
  });

// Isolate FCM tokens into user_tokens/{userId} (unreadable by clients) and unlink shared device tokens
exports.onUserTokenUpdated = functions.firestore
  .document("users/{userId}")
  .onWrite(async (change, context) => {
    const userId = context.params.userId;
    const db = admin.firestore();

    if (!change.after.exists) {
      await db.collection("user_tokens").doc(userId).delete().catch(() => {});
      return null;
    }

    const afterData = change.after.data() || {};
    const beforeData = change.before.exists ? (change.before.data() || {}) : {};

    const newToken = afterData.fcmToken || null;

    // If token was explicitly cleared on logout (fcmToken is null AND fcmTokenUpdatedAt changed)
    if (!newToken) {
      const beforeTs = beforeData.fcmTokenUpdatedAt ? beforeData.fcmTokenUpdatedAt.toMillis?.() : null;
      const afterTs = afterData.fcmTokenUpdatedAt ? afterData.fcmTokenUpdatedAt.toMillis?.() : null;
      if (beforeTs !== afterTs && afterTs !== null) {
        await db.collection("user_tokens").doc(userId).delete().catch(() => {});
      }
      return null;
    }

    const batch = db.batch();

    // 1. Save token to private user_tokens/{userId} collection
    batch.set(db.collection("user_tokens").doc(userId), {
      fcmToken: newToken,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Remove fcmToken from the readable users/{userId} document so no other user can read/steal it
    batch.update(change.after.ref, {
      fcmToken: admin.firestore.FieldValue.delete(),
    });

    // 3. Unlink this device token from any previous user on the same device
    const duplicateTokensSnap = await db
      .collection("user_tokens")
      .where("fcmToken", "==", newToken)
      .get();

    duplicateTokensSnap.forEach((doc) => {
      if (doc.id !== userId) {
        batch.delete(doc.ref);
      }
    });

    const duplicateUsersSnap = await db
      .collection("users")
      .where("fcmToken", "==", newToken)
      .get();

    duplicateUsersSnap.forEach((doc) => {
      if (doc.id !== userId) {
        batch.update(doc.ref, {
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    });

    await batch.commit();
    return null;
  });
