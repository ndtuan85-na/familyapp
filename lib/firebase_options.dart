import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Public client configuration for the Firebase web app.
/// Firestore rules and Authentication enforce access; these identifiers are
/// not server credentials and must never be used in place of security rules.
abstract final class DefaultFirebaseOptions {
  static const web = FirebaseOptions(
    apiKey: 'AIzaSyCa5EExqy7VTjkK-lbDCWsgmrFLWM0I7ZQ',
    appId: '1:883813247132:web:2c9b454e3557da6d8ea559',
    messagingSenderId: '883813247132',
    projectId: 'seafood-38304',
    authDomain: 'seafood-38304.firebaseapp.com',
    storageBucket: 'seafood-38304.firebasestorage.app',
  );
}
