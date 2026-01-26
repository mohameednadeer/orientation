import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../models/user_model.dart';

class GoogleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  /// Get current Firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign in with Google
  /// Returns AppUser on success, throws exception on failure
  Future<AppUser> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;

      // Create a new credential
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = 
          await _firebaseAuth.signInWithCredential(credential);

      final User? user = userCredential.user;

      if (user == null) {
        throw Exception('Failed to sign in with Google');
      }

      // Return AppUser model
      return AppUser(
        id: user.uid,
        email: user.email ?? '',
      );
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw Exception('Google sign-in failed: ${e.toString()}');
    }
  }

  /// Sign out from Google and Firebase
  Future<void> signOut() async {
    try {
      // Sign out from Google
      await _googleSignIn.signOut();
      // Sign out from Firebase
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Sign out failed: ${e.toString()}');
    }
  }

  /// Check if user is currently signed in
  bool isSignedIn() {
    return currentUser != null;
  }

  /// Get current user as AppUser
  AppUser? getCurrentAppUser() {
    final user = currentUser;
    if (user == null) return null;

    return AppUser(
      id: user.uid,
      email: user.email ?? '',
    );
  }

  /// Disconnect Google account (revoke access)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
      await _firebaseAuth.signOut();
    } catch (e) {
      throw Exception('Disconnect failed: ${e.toString()}');
    }
  }

  /// Handle Firebase Auth exceptions
  Exception _handleFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return Exception(
          'An account already exists with the same email address but different sign-in credentials.',
        );
      case 'invalid-credential':
        return Exception('The credential is malformed or has expired.');
      case 'operation-not-allowed':
        return Exception(
          'Google sign-in is not enabled. Please contact support.',
        );
      case 'user-disabled':
        return Exception(
          'This user account has been disabled.',
        );
      case 'user-not-found':
        return Exception('No user found with this email.');
      case 'wrong-password':
        return Exception('Wrong password provided.');
      case 'invalid-verification-code':
        return Exception('The verification code is invalid.');
      case 'invalid-verification-id':
        return Exception('The verification ID is invalid.');
      default:
        return Exception(e.message ?? 'An unknown error occurred.');
    }
  }
}

