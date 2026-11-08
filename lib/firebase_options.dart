// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'core/config/app_environment.dart';

/// Default [FirebaseOptions] that automatically switches between
/// Dev (`binshafar-properties-dev`) and Prod (`building-app1`) based on [AppEnvironment].
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (AppEnvironment.isDev) {
      return DevFirebaseOptions.currentPlatform;
    }
    return ProdFirebaseOptions.currentPlatform;
  }
}

/// Firebase options for Development environment (`binshafar-properties-dev`)
class DevFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyABj5AnKJnMNOc-T6DL9hCDoiD0Y86BvCU',
    appId: '1:1043008395281:web:aa4b4b5f824ce0745bf9b0',
    messagingSenderId: '1043008395281',
    projectId: 'binshafar-properties-dev',
    authDomain: 'binshafar-properties-dev.firebaseapp.com',
    storageBucket: 'binshafar-properties-dev.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDdnSGL_k_dz7wYaA-EzW4118hbLBDPVAQ',
    appId: '1:1043008395281:android:017093746668fb645bf9b0',
    messagingSenderId: '1043008395281',
    projectId: 'binshafar-properties-dev',
    storageBucket: 'binshafar-properties-dev.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBEjjGySAnlkxcGOxHwSOJMLzaQwTajEeI',
    appId: '1:1043008395281:ios:f573d3dd745e916f5bf9b0',
    messagingSenderId: '1043008395281',
    projectId: 'binshafar-properties-dev',
    storageBucket: 'binshafar-properties-dev.firebasestorage.app',
    iosBundleId: 'com.eliteliving.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBEjjGySAnlkxcGOxHwSOJMLzaQwTajEeI',
    appId: '1:1043008395281:ios:f573d3dd745e916f5bf9b0',
    messagingSenderId: '1043008395281',
    projectId: 'binshafar-properties-dev',
    storageBucket: 'binshafar-properties-dev.firebasestorage.app',
    iosBundleId: 'com.eliteliving.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyABj5AnKJnMNOc-T6DL9hCDoiD0Y86BvCU',
    appId: '1:1043008395281:web:aa4b4b5f824ce0745bf9b0',
    messagingSenderId: '1043008395281',
    projectId: 'binshafar-properties-dev',
    authDomain: 'binshafar-properties-dev.firebaseapp.com',
    storageBucket: 'binshafar-properties-dev.firebasestorage.app',
  );
}

/// Firebase options for Production environment (`building-app1`)
class ProdFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDnomqKd15sF6Z_MosqCiaKlcS674on6Bs',
    appId: '1:14052857715:web:2933f7e7e85ccf8ae25706',
    messagingSenderId: '14052857715',
    projectId: 'building-app1',
    authDomain: 'building-app1.firebaseapp.com',
    storageBucket: 'building-app1.firebasestorage.app',
    measurementId: 'G-2DPQV3ENBB',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAdD2-9EZxMDmm3XaajJx5_KPB9UZ7QpBo',
    appId: '1:14052857715:android:119637e717d1013ee25706',
    messagingSenderId: '14052857715',
    projectId: 'building-app1',
    storageBucket: 'building-app1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB2Jn1uGtF4gtUSpVy0XbhG8HapdLW_lRQ',
    appId: '1:14052857715:ios:84b1b32718d453cbe25706',
    messagingSenderId: '14052857715',
    projectId: 'building-app1',
    storageBucket: 'building-app1.firebasestorage.app',
    iosBundleId: 'com.eliteliving.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB2Jn1uGtF4gtUSpVy0XbhG8HapdLW_lRQ',
    appId: '1:14052857715:ios:84b1b32718d453cbe25706',
    messagingSenderId: '14052857715',
    projectId: 'building-app1',
    storageBucket: 'building-app1.firebasestorage.app',
    iosBundleId: 'com.eliteliving.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDnomqKd15sF6Z_MosqCiaKlcS674on6Bs',
    appId: '1:14052857715:web:fa55af99d9918c48e25706',
    messagingSenderId: '14052857715',
    projectId: 'building-app1',
    authDomain: 'building-app1.firebaseapp.com',
    storageBucket: 'building-app1.firebasestorage.app',
    measurementId: 'G-L0KWYND3FF',
  );
}
