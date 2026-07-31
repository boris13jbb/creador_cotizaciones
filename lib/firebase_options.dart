// File generated for CotiApp SaaS (Firebase project: cotiapp-saas-jb).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        return linux;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCUDV0h0L3i2WRox6fSEbz8c_qnQqoSLY8',
    appId: '1:1003726618863:web:182419bdfb708f74a39b1a',
    messagingSenderId: '1003726618863',
    projectId: 'cotiapp-saas-jb',
    authDomain: 'cotiapp-saas-jb.firebaseapp.com',
    storageBucket: 'cotiapp-saas-jb.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCUDV0h0L3i2WRox6fSEbz8c_qnQqoSLY8',
    appId: '1:1003726618863:android:36b529d5b69a617ba39b1a',
    messagingSenderId: '1003726618863',
    projectId: 'cotiapp-saas-jb',
    storageBucket: 'cotiapp-saas-jb.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCUDV0h0L3i2WRox6fSEbz8c_qnQqoSLY8',
    appId: '1:1003726618863:web:182419bdfb708f74a39b1a',
    messagingSenderId: '1003726618863',
    projectId: 'cotiapp-saas-jb',
    storageBucket: 'cotiapp-saas-jb.firebasestorage.app',
    iosBundleId: 'com.example.creadorCotizaciones',
  );

  static const FirebaseOptions macos = ios;

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCUDV0h0L3i2WRox6fSEbz8c_qnQqoSLY8',
    appId: '1:1003726618863:web:1ef81a4f51577756a39b1a',
    messagingSenderId: '1003726618863',
    projectId: 'cotiapp-saas-jb',
    authDomain: 'cotiapp-saas-jb.firebaseapp.com',
    storageBucket: 'cotiapp-saas-jb.firebasestorage.app',
  );

  static const FirebaseOptions linux = windows;
}
