import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _user;
  String? _userName;
  DateTime? _accountCreatedAt;

  bool get isAuthenticated => _user != null;
  String? get token => null; // Firebase token auto-manage করে
  String? get userName => _userName;
  String? get userEmail => _user?.email;
  DateTime? get accountCreatedAt => _accountCreatedAt;
  String? get userId => _user?.uid;

  // Auth headers এর বদলে Firebase userId ব্যবহার হবে
  String? get currentUserId => _user?.uid;

  AuthService() {
    // Firebase auth state listener - auto login/logout handle করে
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        await _loadUserProfile(user.uid);
      } else {
        _userName = null;
        _accountCreatedAt = null;
      }
      notifyListeners();
    });
  }

  Future<void> _loadUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        _userName = data['name'] ?? _user?.email?.split('@').first;
        final createdAt = data['created_at'];
        if (createdAt != null) {
          _accountCreatedAt = (createdAt as Timestamp).toDate();
        }
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('Login error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> loginWithMessage(
      String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      if (_user != null) {
        await _loadUserProfile(_user!.uid);
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': 'Login failed'};
    } on FirebaseAuthException catch (e) {
      String message = 'Login failed';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Wrong password. Please try again.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      } else if (e.code == 'user-disabled') {
        message = 'This account has been disabled.';
      } else if (e.code == 'too-many-requests') {
        message = 'Too many attempts. Try again later.';
      }
      return {'success': false, 'message': message};
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;

      if (_user != null) {
        // Display name set করো
        await _user!.updateDisplayName(name);

        // Firestore এ user profile save করো
        final now = DateTime.now();
        await _db.collection('users').doc(_user!.uid).set({
          'name': name,
          'email': email,
          'created_at': Timestamp.fromDate(now),
        });

        _userName = name;
        _accountCreatedAt = now;
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint('Signup error: ${e.code} - ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Signup error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> signupWithMessage(
      String name, String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;

      if (_user != null) {
        await _user!.updateDisplayName(name);
        final now = DateTime.now();
        await _db.collection('users').doc(_user!.uid).set({
          'name': name,
          'email': email,
          'created_at': Timestamp.fromDate(now),
        });

        _userName = name;
        _accountCreatedAt = now;
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': 'Signup failed'};
    } on FirebaseAuthException catch (e) {
      String message = 'Signup failed';
      if (e.code == 'email-already-in-use') {
        message = 'An account already exists with this email.';
      } else if (e.code == 'weak-password') {
        message = 'Password is too weak. Use at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      return {'success': false, 'message': message};
    }
  }

  Future<bool> updateName(String newName) async {
    try {
      if (_user == null) return false;

      await _user!.updateDisplayName(newName);
      await _db.collection('users').doc(_user!.uid).update({'name': newName});

      _userName = newName;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Update name error: $e');
      return false;
    }
  }

  void updateNameLocally(String newName) {
    _userName = newName;
    notifyListeners();
  }

  Future<Map<String, dynamic>> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Password reset email sent. Check your inbox.',
      };
    } on FirebaseAuthException catch (e) {
      String message = 'Something went wrong.';
      if (e.code == 'user-not-found') {
        message = 'No account found with this email.';
      } else if (e.code == 'invalid-email') {
        message = 'Invalid email address.';
      }
      return {'success': false, 'message': message};
    }
  }

  Future<void> setAccountCreatedAtFromTransactions(DateTime oldest) async {
    if (_accountCreatedAt == null || oldest.isBefore(_accountCreatedAt!)) {
      _accountCreatedAt = oldest;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    _userName = null;
    _accountCreatedAt = null;
    notifyListeners();
  }
}
