import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  AuthService._();

  static final instance = AuthService._();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const _signedInKey = 'signed_in';

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await _rememberSignedIn();
    return result;
  }

  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final credential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    final result = await _auth.signInWithCredential(credential);
    await _rememberSignedIn();
    return result;
  }

  Future<UserCredential> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    await _rememberSignedIn();
    return result;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _rememberSignedIn();
    return result;
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _rememberSignedIn();
    return result;
  }

  Future<bool> hasRememberedSession() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_signedInKey) ?? false;
  }

  Future<void> _rememberSignedIn() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_signedInKey, true);
  }

  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    } catch (_) {}
    try {
      await _auth.signOut();
    } finally {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_signedInKey, false);
    }
  }
}
