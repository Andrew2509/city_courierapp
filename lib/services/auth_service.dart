import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:city_courierapp/services/token_store.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Memeriksa apakah pengguna saat ini telah login (memiliki sesi aktif)
  static Future<bool> isLoggedIn() async {
    return await TokenStore.isLoggedIn();
  }

  static Future<String?> getGoogleIdToken() async {
    try {
      // Sign out from previous session to force account picker if needed
      await _googleSignIn.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('Google Sign-In: User cancelled the flow');
        return null;
      }

      // Obtain the auth details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential for Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Return the ID Token to be sent to the backend
      return await userCredential.user?.getIdToken();
    } catch (e) {
      print('Error at AuthService.getGoogleIdToken: $e');
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error at AuthService.signOut: $e');
    }
  }
}
