importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyDnomqKd15sF6Z_MosqCiaKlcS674on6Bs",
  appId: "1:14052857715:web:2933f7e7e85ccf8ae25706",
  messagingSenderId: "14052857715",
  projectId: "building-app1",
  authDomain: "building-app1.firebaseapp.com",
  storageBucket: "building-app1.firebasestorage.app",
  measurementId: "G-2DPQV3ENBB"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || payload.data?.title || 'Elite Living';
  const notificationOptions = {
    body: payload.notification?.body || payload.data?.body || '',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
