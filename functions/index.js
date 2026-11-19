const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

function isDemoIdentity({ email, data, token } = {}) {
  const e = String(email || data?.email || token?.email || "").trim().toLowerCase();
  return e.startsWith("demo.") || data?.isDemo === true || token?.isDemo === true;
}

function getFirebaseWebApiKey() {
  if (process.env.FIREBASE_WEB_API_KEY) {
    return process.env.FIREBASE_WEB_API_KEY;
  }
  const projectId = process.env.GCLOUD_PROJECT || admin.app().options.projectId || "";
  if (projectId === "binshafar-properties-dev") {
    return "AIzaSyABj5AnKJnMNOc-T6DL9hCDoiD0Y86BvCU";
  }
  return "AIzaSyDnomqKd15sF6Z_MosqCiaKlcS674on6Bs";
}

function sanitizeUaePhoneForAuth(raw) {
  const trimmed = String(raw || "").trim();
  const cleaned = trimmed.replace(/\D/g, "");
  let fullPhone = cleaned;
  if (cleaned.startsWith("009715") && cleaned.length === 14) {
    fullPhone = cleaned.substring(2);
  } else if (cleaned.startsWith("05") && cleaned.length === 10) {
    fullPhone = "971" + cleaned.substring(1);
  } else if (cleaned.startsWith("5") && cleaned.length === 9) {
    fullPhone = "971" + cleaned;
  }

  let localPhone = null;
  const variants = [];
  const addVariant = (v) => {
    if (v && !variants.includes(v)) variants.push(v);
  };

  if (fullPhone.startsWith("9715") && fullPhone.length === 12) {
    localPhone = "05" + fullPhone.substring(4);
    addVariant(fullPhone);
    addVariant(localPhone);
    addVariant("+" + fullPhone);
  }
  addVariant(cleaned);
  addVariant(trimmed);

  return { fullPhone, localPhone, variants };
}

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

async function deleteDocumentsInChunks(db, docRefs) {
  for (let i = 0; i < docRefs.length; i += 400) {
    const chunk = docRefs.slice(i, i + 400);
    const batch = db.batch();
    for (const ref of chunk) {
      batch.delete(ref);
    }
    await batch.commit();
  }
}

exports.deleteAuthUser = functions.firestore
  .document("users/{userId}")
  .onDelete(async (snap, context) => {
    const userId = context.params.userId;
    const deletedData = snap.data() || {};

    // Never delete shared Demo Auth accounts or demo assets
    if (isDemoIdentity({ data: deletedData })) {
      console.warn(`Skipping auth/data cleanup for protected demo account ${userId}.`);
      return null;
    }

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

    const db = admin.firestore();

    // Clean up user_tokens and phone_index entries belonging to this user
    try {
      const refsToDelete = [db.collection("user_tokens").doc(userId)];

      const byUidSnap = await db.collection("phone_index").where("uid", "==", userId).get();
      byUidSnap.forEach((doc) => {
        refsToDelete.push(doc.ref);
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
          refsToDelete.push(ref);
        }
      }

      await deleteDocumentsInChunks(db, refsToDelete);
    } catch (cleanupErr) {
      console.error(`Error cleaning up phone_index / user_tokens for ${userId}:`, cleanupErr);
    }

    // Best-effort cleanup for user's notifications
    try {
      const notifSnap = await db.collection("notifications").where("userId", "==", userId).get();
      if (!notifSnap.empty) {
        await deleteDocumentsInChunks(db, notifSnap.docs.map((d) => d.ref));
      }
    } catch (notifErr) {
      console.error(`Error cleaning up notifications for ${userId}:`, notifErr);
    }

    // Best-effort cleanup for user's direct_chats and messages
    try {
      const chatRef = db.collection("direct_chats").doc(userId);
      const msgsSnap = await chatRef.collection("messages").get();
      const chatDeletes = msgsSnap.docs.map((d) => d.ref);
      chatDeletes.push(chatRef);
      await deleteDocumentsInChunks(db, chatDeletes);
    } catch (chatErr) {
      console.error(`Error cleaning up direct_chats for ${userId}:`, chatErr);
    }

    // Best-effort cleanup for user's Storage files
    try {
      const bucket = admin.storage().bucket();
      await bucket.deleteFiles({ prefix: `documents/${userId}/` });
      await bucket.deleteFiles({ prefix: `tasks/${userId}/` });
      await bucket.deleteFiles({ prefix: `contracts/${userId}/` });
      await bucket.deleteFiles({ prefix: `chats/${userId}/` });
    } catch (storageErr) {
      console.error(`Error cleaning up storage files for ${userId}:`, storageErr);
    }

    return null;
  });

exports.createTechnician = functions.https.onCall(async (data, context) => {
  // Check if the user making the request is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  // 🛡️ Security Check: Ensure caller is a real (non-demo) admin
  const db = admin.firestore();
  const callerDoc = await db.collection('users').doc(context.auth.uid).get();
  if (isDemoIdentity({ token: context.auth.token, data: callerDoc.data() })) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Demo accounts cannot create technician accounts.'
    );
  }

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

  const trimmedName = String(name).trim();
  const normalizedEmail = String(email).trim().toLowerCase();
  const passwordStr = String(password);
  const trimmedPhone = phone ? String(phone).trim() : '';
  const trimmedProfession = profession ? String(profession).trim() : '';

  if (trimmedName.length === 0 || trimmedName.length > 150) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Name must be between 1 and 150 characters.'
    );
  }

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(normalizedEmail) || normalizedEmail.length > 254 || normalizedEmail.startsWith('demo.')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Please provide a valid non-demo email address.'
    );
  }

  if (passwordStr.length < 6 || passwordStr.length > 128) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Password must be between 6 and 128 characters.'
    );
  }

  if (trimmedPhone.length > 30 || trimmedProfession.length > 100) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Phone or profession exceeds maximum length.'
    );
  }

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
      password: passwordStr,
      displayName: trimmedName,
    });

    // Set role custom claim for fast Storage & Firestore rule checks
    await admin.auth().setCustomUserClaims(userRecord.uid, { role: 'technician' });

    // Save the user data in Firestore
    await db.collection('users').doc(userRecord.uid).set({
      name: trimmedName,
      email: normalizedEmail,
      phone: trimmedPhone,
      profession: trimmedProfession,
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
    if (error.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'An account with this email already exists.');
    }
    if (error.code === 'auth/invalid-email' || error.code === 'auth/weak-password') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid email or weak password.');
    }
    throw new functions.https.HttpsError('internal', 'Failed to create technician account.');
  }
});

// Trigger on new notification document
exports.sendPushNotification = functions.firestore
  .document("notifications/{docId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    const userId = notification.userId;
    const senderId = notification.senderId;
    const title = notification.title || "Property Management";
    const message = notification.message || "";
    const relatedTaskId = notification.relatedTaskId || "";

    // 🛡️ Strict Isolation: Never send real FCM push notifications for Demo events
    if (notification.isDemo === true) {
      console.log('Skipping push notification for demo event.');
      return null;
    }

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
      const recipientDoc = await db.collection('users').doc(userId).get();
      if (!recipientDoc.exists) {
        console.log(`User ${userId} not found.`);
        return null;
      }

      const recipientData = recipientDoc.data() || {};
      if (isDemoIdentity({ data: recipientData })) {
        console.log(`Skipping push notification for demo recipient ${userId}.`);
        return null;
      }

      if (senderId) {
        const senderDoc = await db.collection('users').doc(senderId).get();
        if (senderDoc.exists && isDemoIdentity({ data: senderDoc.data() || {} })) {
          console.log(`Skipping push notification triggered by demo sender ${senderId}.`);
          return null;
        }
      }

      // Retrieve fcmToken from isolated user_tokens collection first, fallback to users/{userId}
      let fcmToken = null;
      const tokenDoc = await db.collection('user_tokens').doc(userId).get();
      if (tokenDoc.exists && tokenDoc.data()?.fcmToken) {
        fcmToken = tokenDoc.data().fcmToken;
      } else {
        fcmToken = recipientData.fcmToken || null;
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

// Compute technician rating server-side when a task receives a rating for the first time
exports.onTaskRated = functions.firestore
  .document("tasks/{taskId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data() || {};
    const after = change.after.data() || {};

    const hadRating = before.rating !== undefined && before.rating !== null;
    const rating = after.rating;
    if (hadRating || typeof rating !== "number" || rating < 1 || rating > 5) {
      return null;
    }

    const technicianId = after.technicianId;
    if (!technicianId || typeof technicianId !== "string") {
      return null;
    }

    const db = admin.firestore();
    const techRef = db.collection("users").doc(technicianId);

    try {
      await db.runTransaction(async (transaction) => {
        const techDoc = await transaction.get(techRef);
        if (!techDoc.exists) return;

        const techData = techDoc.data() || {};
        if (techData.role !== "technician") return;
        if ((techData.isDemo === true) !== (after.isDemo === true)) return;

        const currentAvg = typeof techData.averageRating === "number" ? techData.averageRating : 0;
        const currentTotal = typeof techData.totalRatings === "number" ? techData.totalRatings : 0;

        const newTotal = currentTotal + 1;
        const newAvg = Math.round((((currentAvg * currentTotal) + rating) / newTotal) * 100) / 100;

        transaction.update(techRef, {
          averageRating: newAvg,
          totalRatings: newTotal,
        });
      });
    } catch (err) {
      console.error(`Error updating rating for technician ${technicianId} on task ${context.params.taskId}:`, err);
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

    if (typeof newToken !== "string" || newToken.trim().length === 0 || newToken.length > 512) {
      console.warn(`Ignoring invalid FCM token format for user ${userId}.`);
      await change.after.ref.update({
        fcmToken: admin.firestore.FieldValue.delete(),
      }).catch(() => {});
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

// Secure server-side account deletion with Demo guard, opt-out tombstone, and full cleanup
exports.deleteMyAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Authentication is required to delete your account.'
    );
  }

  const uid = context.auth.uid;
  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  const userDoc = await userRef.get();
  const userData = userDoc.exists ? (userDoc.data() || {}) : {};

  if (isDemoIdentity({ token: context.auth.token, data: userData })) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Demo Mode Restriction: Account deletion is disabled for shared demo accounts.'
    );
  }

  const authTime = context.auth.token?.auth_time || 0;
  const nowSec = Math.floor(Date.now() / 1000);
  if (nowSec - authTime > 600) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'requires-recent-login'
    );
  }

  const normalizedEmail = String(userData.email || context.auth.token?.email || '').trim().toLowerCase();
  const phoneVariants = getPhoneVariants(userData.phone);

  // Record opt-out tombstone so sync_service/sync.js will not re-create this deleted account
  await db.collection('deleted_accounts').doc(uid).set({
    uid,
    email: normalizedEmail || null,
    phones: phoneVariants,
    deletedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  // Clean up user_tokens and phone_index
  try {
    const refsToDelete = [db.collection('user_tokens').doc(uid)];
    const byUidSnap = await db.collection('phone_index').where('uid', '==', uid).get();
    byUidSnap.forEach((doc) => refsToDelete.push(doc.ref));

    for (const variant of phoneVariants) {
      const ref = db.collection('phone_index').doc(variant);
      const snapDoc = await ref.get();
      if (
        snapDoc.exists &&
        (snapDoc.data().uid === uid ||
          (normalizedEmail && snapDoc.data().email === normalizedEmail))
      ) {
        refsToDelete.push(ref);
      }
    }
    await deleteDocumentsInChunks(db, refsToDelete);
  } catch (err) {
    console.error(`Error cleaning up phone_index / user_tokens during deleteMyAccount(${uid}):`, err);
  }

  // Clean up notifications
  try {
    const notifSnap = await db.collection('notifications').where('userId', '==', uid).get();
    if (!notifSnap.empty) {
      await deleteDocumentsInChunks(db, notifSnap.docs.map((d) => d.ref));
    }
  } catch (err) {
    console.error(`Error cleaning up notifications during deleteMyAccount(${uid}):`, err);
  }

  // Clean up direct_chats
  try {
    const chatRef = db.collection('direct_chats').doc(uid);
    const msgsSnap = await chatRef.collection('messages').get();
    const chatDeletes = msgsSnap.docs.map((d) => d.ref);
    chatDeletes.push(chatRef);
    await deleteDocumentsInChunks(db, chatDeletes);
  } catch (err) {
    console.error(`Error cleaning up direct_chats during deleteMyAccount(${uid}):`, err);
  }

  // Clean up Storage files
  try {
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({ prefix: `documents/${uid}/` });
    await bucket.deleteFiles({ prefix: `tasks/${uid}/` });
    await bucket.deleteFiles({ prefix: `contracts/${uid}/` });
    await bucket.deleteFiles({ prefix: `chats/${uid}/` });
  } catch (err) {
    console.error(`Error cleaning up storage during deleteMyAccount(${uid}):`, err);
  }

  // Delete Firestore user doc
  if (userDoc.exists) {
    await userRef.delete();
  }

  // Delete Firebase Auth user
  try {
    await admin.auth().deleteUser(uid);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') {
      throw new functions.https.HttpsError('internal', 'Failed to complete account deletion.');
    }
  }

  return { success: true };
});

// Server-side phone+password authentication (prevents leaking emails / UIDs via unauthenticated phone_index queries)
exports.signInWithPhonePassword = functions.https.onCall(async (data) => {
  const { phone, password } = data || {};
  if (typeof phone !== 'string' || typeof password !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number and password are required.');
  }

  const trimmedPhone = phone.trim();
  const trimmedPassword = password.trim();
  if (!trimmedPhone || trimmedPhone.length > 30 || !trimmedPassword || trimmedPassword.length > 128) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number or password format.');
  }

  const db = admin.firestore();
  const { fullPhone, variants } = sanitizeUaePhoneForAuth(trimmedPhone);

  let resolvedEmail = null;
  for (const variant of variants) {
    if (!variant) continue;
    const snap = await db.collection('phone_index').doc(variant).get();
    if (snap.exists && snap.data()?.email) {
      resolvedEmail = String(snap.data().email).trim().toLowerCase();
      break;
    }
  }

  if (!resolvedEmail && fullPhone) {
    resolvedEmail = `${fullPhone}@elitelivingre.ae`;
  }

  if (!resolvedEmail) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Incorrect credentials. Please check your phone number and password.'
    );
  }

  const passwordCandidates = [trimmedPassword];
  const cleanDigits = trimmedPassword.replace(/\D/g, '');
  if (cleanDigits.startsWith('05') && cleanDigits.length === 10) {
    passwordCandidates.push('971' + cleanDigits.substring(1));
  } else if (cleanDigits.startsWith('9715') && cleanDigits.length === 12) {
    passwordCandidates.push('0' + cleanDigits.substring(3));
  }

  const apiKey = getFirebaseWebApiKey();
  const endpoint = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`;

  let verifiedLocalId = null;
  let matchedPassword = null;

  for (const candidate of passwordCandidates) {
    const res = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        email: resolvedEmail,
        password: candidate,
        returnSecureToken: true,
      }),
    });
    const body = await res.json();
    if (res.ok && body.localId) {
      verifiedLocalId = body.localId;
      matchedPassword = candidate;
      break;
    }
    const errMsg = String(body?.error?.message || '');
    if (errMsg.includes('TOO_MANY_ATTEMPTS_TRY_LATER')) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'Too many failed login attempts. Please try again later.'
      );
    }
  }

  if (!verifiedLocalId) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Incorrect credentials. Please check your phone number and password.'
    );
  }

  try {
    const customToken = await admin.auth().createCustomToken(verifiedLocalId);
    return { customToken };
  } catch (tokenErr) {
    console.warn('createCustomToken failed (likely missing IAM signBlob); returning verified credential fallback:', tokenErr.message);
    return {
      verifiedEmail: resolvedEmail,
      verifiedPassword: matchedPassword,
    };
  }
});

// Non-enumerating password reset supporting email or UAE phone number
exports.requestPasswordReset = functions.https.onCall(async (data) => {
  const { identifier } = data || {};
  if (typeof identifier !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'Email or phone number is required.');
  }

  const trimmed = identifier.trim();
  if (!trimmed || trimmed.length > 254) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid email or phone number.');
  }

  const db = admin.firestore();
  let targetEmail = null;

  if (trimmed.includes('@')) {
    targetEmail = trimmed.toLowerCase();
  } else {
    const { variants } = sanitizeUaePhoneForAuth(trimmed);
    for (const variant of variants) {
      if (!variant) continue;
      const snap = await db.collection('phone_index').doc(variant).get();
      if (snap.exists && snap.data()?.email) {
        targetEmail = String(snap.data().email).trim().toLowerCase();
        break;
      }
    }
  }

  // Only send reset links to real registered email addresses (skip synthetic @elitelivingre.ae and demo.* accounts)
  if (
    targetEmail &&
    !targetEmail.startsWith('demo.') &&
    !targetEmail.endsWith('@elitelivingre.ae')
  ) {
    try {
      const apiKey = getFirebaseWebApiKey();
      const endpoint = `https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=${encodeURIComponent(apiKey)}`;
      await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          requestType: 'PASSWORD_RESET',
          email: targetEmail,
        }),
      });
    } catch (err) {
      console.error('Error requesting password reset:', err);
    }
  }

  return { success: true };
});
