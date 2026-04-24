import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/user_dao.dart';
import '../domain/entities/user_credential.dart';

/// The Web OAuth Client ID from Firebase Console >
/// Authentication > Sign-in method > Google > Web SDK configuration.
const String _kWebClientId =
    '287635090332-ng7qc1miso3kj8uhgf25bkibgmskkt62.apps.googleusercontent.com';

/// Hashes a PIN using SHA-256.
String hashPin(String pin) {
  final List<int> bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}

/// Authentication state.
class AuthState {
  const AuthState({
    this.user,
    this.isFirstRun = false,
    this.errorMessage,
    this.isLoading = false,
    this.storeId,
  });

  final UserCredential? user;
  final bool isFirstRun;
  final String? errorMessage;
  final bool isLoading;
  final String? storeId;

  /// True only when BOTH a local user exists AND a storeId is linked.
  bool get isLoggedIn => user != null && storeId != null;

  AuthState copyWith({
    UserCredential? user,
    bool? isFirstRun,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
    String? storeId,
    bool clearUser = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isFirstRun: isFirstRun ?? this.isFirstRun,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        isLoading: isLoading ?? this.isLoading,
        storeId: storeId ?? this.storeId,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  final UserDao _dao = UserDao();
  static const Uuid _uuid = Uuid();
  bool _googleSignInInitialized = false;
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Future<AuthState> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    final bool hasOwner = await _dao.exists();

    // First run = no owner registered yet OR device never linked to a store.
    if (!hasOwner || storeId == null) {
      return AuthState(isFirstRun: true, storeId: storeId);
    }

    return AuthState(isFirstRun: false, storeId: storeId);
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  /// Authenticate with Google to link device to a store.
  /// Returns the Firebase UID (storeId) on success, or null on failure.
  Future<String?> linkStoreWithGoogle() async {
    state = AsyncData<AuthState>(state.value!.copyWith(isLoading: true, clearError: true));
    try {
      if (!_googleSignInInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: _kWebClientId,
        );
        _googleSignInInitialized = true;
      }
      final GoogleSignInAccount gUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication gAuth = gUser.authentication;
      final GoogleSignInClientAuthorization gAuthz =
          await gUser.authorizationClient.authorizeScopes(<String>['email']);

      final fb_auth.OAuthCredential credential =
          fb_auth.GoogleAuthProvider.credential(
        accessToken: gAuthz.accessToken,
        idToken: gAuth.idToken,
      );

      final fb_auth.UserCredential firebaseUser =
          await fb_auth.FirebaseAuth.instance.signInWithCredential(credential);
      final String storeId = firebaseUser.user!.uid;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('storeId', storeId);

      state = AsyncData<AuthState>(
        state.value!.copyWith(isLoading: false, storeId: storeId),
      );
      return storeId;
    } catch (e) {
      state = AsyncData<AuthState>(state.value!.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-In failed: $e',
      ));
      return null;
    }
  }

  // ─── Registration ──────────────────────────────────────────────────────────

  /// Register the owner PIN + store name. Automatically logs the user in.
  /// Must be called AFTER [linkStoreWithGoogle] has succeeded.
  Future<bool> register(String pin, String storeName) async {
    final AuthState current = state.value!;

    if (current.storeId == null) {
      state = AsyncData<AuthState>(current.copyWith(
        errorMessage: 'Please link your store with Google first.',
      ));
      return false;
    }
    if (pin.length < 4) {
      state = AsyncData<AuthState>(
        current.copyWith(errorMessage: 'PIN must be at least 4 digits'),
      );
      return false;
    }

    final UserCredential user = UserCredential(
      userId: _uuid.v4(),
      pinHash: hashPin(pin),
      role: 'owner',
      storeName: storeName.trim().isEmpty ? 'My Store' : storeName.trim(),
    );
    await _dao.insert(user);

    // Auto-login: mark as logged in immediately after registration.
    state = AsyncData<AuthState>(current.copyWith(
      user: user,
      isFirstRun: false,
    ));
    return true;
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  /// Login with Biometrics.
  Future<bool> loginWithBiometrics() async {
    final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
    final bool canAuthenticate =
        canCheckBiometrics || await _localAuth.isDeviceSupported();

    if (!canAuthenticate) {
      state = AsyncData<AuthState>(state.value!.copyWith(
        errorMessage: 'Biometrics not supported on this device.',
      ));
      return false;
    }

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access Sar-E',
        biometricOnly: true,
      );

      if (didAuthenticate) {
        final List<UserCredential> users = await _dao.getAllUsers();
        final UserCredential? owner =
            users.where((UserCredential u) => u.role == 'owner').firstOrNull;

        if (owner != null) {
          final UserCredential loggedIn = owner.copyWith(
            failedAttempts: 0,
            clearLock: true,
            lastLoginAt: DateTime.now(),
          );
          await _dao.update(loggedIn);
          state = AsyncData<AuthState>(state.value!.copyWith(user: loggedIn));
          return true;
        }
      }
      return false;
    } catch (e) {
      state = AsyncData<AuthState>(
          state.value!.copyWith(errorMessage: 'Biometric auth failed.'));
      return false;
    }
  }

  /// Login with PIN.
  Future<bool> login(String pin) async {
    final AuthState currentState = state.value!;
    state = AsyncData<AuthState>(currentState.copyWith(isLoading: true, clearError: true));

    final String hashed = hashPin(pin);
    final UserCredential? user = await _dao.getUserByPinHash(hashed);

    if (user == null) {
      state = AsyncData<AuthState>(currentState.copyWith(
        errorMessage: 'Invalid PIN.',
        isLoading: false,
      ));
      return false;
    }

    if (user.isLocked) {
      final int remaining =
          user.lockedUntil!.difference(DateTime.now()).inMinutes;
      state = AsyncData<AuthState>(currentState.copyWith(
        isLoading: false,
        errorMessage: 'Account locked. Try again in $remaining min.',
      ));
      return false;
    }

    final UserCredential loggedIn = user.copyWith(
      failedAttempts: 0,
      clearLock: true,
      lastLoginAt: DateTime.now(),
    );
    await _dao.update(loggedIn);
    state = AsyncData<AuthState>(
      currentState.copyWith(user: loggedIn, isLoading: false),
    );
    return true;
  }

  // ─── Session ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    final bool hasOwner = await _dao.exists();
    state = AsyncData<AuthState>(AuthState(
      isFirstRun: !hasOwner || storeId == null,
      storeId: storeId,
    ));
  }

  Future<void> clearStoreLink() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('storeId');
    await fb_auth.FirebaseAuth.instance.signOut();
    if (_googleSignInInitialized) {
      await GoogleSignIn.instance.signOut();
    }
    state = const AsyncData<AuthState>(AuthState(isFirstRun: true));
  }

  Future<void> updateStoreName(String name) async {
    final UserCredential? user = state.value?.user;
    if (user == null) return;
    final UserCredential updated = user.copyWith(storeName: name);
    await _dao.update(updated);
    state = AsyncData<AuthState>(state.value!.copyWith(user: updated));
  }

  Future<void> changePin(String newPin) async {
    final UserCredential? user = state.value?.user;
    if (user == null) return;
    final UserCredential updated = user.copyWith(pinHash: hashPin(newPin));
    await _dao.update(updated);
    state = AsyncData<AuthState>(state.value!.copyWith(user: updated));
  }

  Future<void> addCashier(String pin) async {
    final UserCredential? user = state.value?.user;
    if (user == null || user.role != 'owner') return;

    final UserCredential cashier = UserCredential(
      userId: _uuid.v4(),
      pinHash: hashPin(pin),
      role: 'cashier',
      storeName: user.storeName,
    );
    await _dao.insert(cashier);
  }
}

final AsyncNotifierProvider<AuthNotifier, AuthState> authProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
