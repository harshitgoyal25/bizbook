import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class AuthService extends ChangeNotifier {
  late bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;

  Future<void> checkAuthStatus() async {
    // Check if a user is currently signed in
    User? user = _auth.currentUser;
    _isAuthenticated = user != null;
    notifyListeners();
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;
      notifyListeners();
      return user;
    } catch (e) {
      notifyListeners();

      return null;
    }
  }

  Future<User?> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      User? user = result.user;
      return user;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      _isAuthenticated = false;
      notifyListeners(); // Notify
    } catch (e) {
      return;
    }
  }

  void showToast(BuildContext context, String msg, bool isSuccess) {
    toastification.show(
      context: context,
      type: isSuccess ? ToastificationType.success : ToastificationType.error,
      style: ToastificationStyle.flat,
      alignment: Alignment.bottomCenter,
      autoCloseDuration: const Duration(seconds: 5),
      title: Text(
        msg,
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> sendPasswordResetEmail(
      String email, BuildContext context) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (!context.mounted) return;
      showToast(context, "Password reset email sent", true);
    } catch (e) {}
  }
}
