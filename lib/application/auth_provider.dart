import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/user_dao.dart';
import '../domain/entities/user_credential.dart';

const String _kWebClientId =
    '287635090332-ng7qc1miso3kj8uhgf25bkibgmskkt62.apps.googleusercontent.com';

String hashPin(String pin) {
  final List<int> bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}

class GoogleLinkResult {
  const GoogleLinkResult(
      {required this.storeId, this.existingStoreName, this.cloudPinHash});
  final String storeId;
  final String? existingStoreName;
  final String? cloudPinHash;
  bool get isExistingStore => existingStoreName != null;
}

class AuthState {
  const AuthState({
    this.user,
    this.isFirstRun = false,
    this.errorMessage,
    this.isLoading = false,
    this.storeId,
    this.isOfflineMode = false,
    this.storeNameHint,
  });

  final UserCredential? user;
  final bool isFirstRun;
  final String? errorMessage;
  final bool isLoading;
  final String? storeId;
  final bool isOfflineMode;

  /// Store name loaded from DB even when logged out — used by LoginScreen.
  final String? storeNameHint;

  bool get isLoggedIn => user != null && storeId != null;

  AuthState copyWith({
    UserCredential? user,
    bool? isFirstRun,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
    String? storeId,
    bool? isOfflineMode,
    String? storeNameHint,
    bool clearUser = false,
  }) =>
      AuthState(
        user: clearUser ? null : (user ?? this.user),
        isFirstRun: isFirstRun ?? this.isFirstRun,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        isLoading: isLoading ?? this.isLoading,
        storeId: storeId ?? this.storeId,
        isOfflineMode: isOfflineMode ?? this.isOfflineMode,
        storeNameHint: storeNameHint ?? this.storeNameHint,
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
    final bool isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
    final bool hasOwner = await _dao.exists();

    // Load store name hint from DB even when not logged in
    String? storeNameHint;
    if (hasOwner) {
      final List<UserCredential> users = await _dao.getAllUsers();
      storeNameHint = users
          .where((UserCredential u) => u.role == 'owner')
          .firstOrNull
          ?.storeName;
    }

    if (!hasOwner || storeId == null) {
      return AuthState(
        isFirstRun: true,
        storeId: storeId,
        isOfflineMode: isOfflineMode,
        storeNameHint: storeNameHint,
      );
    }
    return AuthState(
      isFirstRun: false,
      storeId: storeId,
      isOfflineMode: isOfflineMode,
      storeNameHint: storeNameHint,
    );
  }

  // ─── Google Sign-In ────────────────────────────────────────────────────────

  Future<GoogleLinkResult?> linkStoreWithGoogle() async {
    state = AsyncData<AuthState>(
        state.value!.copyWith(isLoading: true, clearError: true));
    try {
      if (!_googleSignInInitialized) {
        await GoogleSignIn.instance.initialize(serverClientId: _kWebClientId);
        _googleSignInInitialized = true;
      }
      final GoogleSignInAccount gUser =
          await GoogleSignIn.instance.authenticate();
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
      await prefs.remove('isOfflineMode');

      String? existingStoreName;
      String? cloudPinHash;
      try {
        final DocumentSnapshot<Map<String, dynamic>> doc =
            await FirebaseFirestore.instance
                .collection('stores')
                .doc(storeId)
                .collection('profile')
                .doc('info')
                .get();
        if (doc.exists) {
          existingStoreName = doc.data()?['storeName'] as String?;
          cloudPinHash = doc.data()?['pinHash'] as String?;
        }
      } catch (_) {}

      state = AsyncData<AuthState>(state.value!.copyWith(
        isLoading: false,
        storeId: storeId,
        isOfflineMode: false,
      ));
      return GoogleLinkResult(
        storeId: storeId,
        existingStoreName: existingStoreName,
        cloudPinHash: cloudPinHash,
      );
    } catch (e) {
      state = AsyncData<AuthState>(state.value!.copyWith(
        isLoading: false,
        errorMessage: 'Google Sign-In failed: $e',
      ));
      return null;
    }
  }

  // ─── Offline Mode ──────────────────────────────────────────────────────────

  Future<bool> continueOffline(String pin, String storeName) async {
    state = AsyncData<AuthState>(
        state.value!.copyWith(isLoading: true, clearError: true));
    final String localStoreId = _uuid.v4();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('storeId', localStoreId);
    await prefs.setBool('isOfflineMode', true);
    state = AsyncData<AuthState>(state.value!.copyWith(
      storeId: localStoreId,
      isOfflineMode: true,
      isLoading: false,
    ));
    return register(pin, storeName);
  }

  // ─── Registration ──────────────────────────────────────────────────────────

  Future<bool> register(String pin, String storeName) async {
    final AuthState current = state.value!;
    if (current.storeId == null) {
      state = AsyncData<AuthState>(
          current.copyWith(errorMessage: 'Please complete sign-in first.'));
      return false;
    }
    if (pin.length < 4) {
      state = AsyncData<AuthState>(
          current.copyWith(errorMessage: 'PIN must be at least 4 digits'));
      return false;
    }
    final String trimmedName =
        storeName.trim().isEmpty ? 'My Store' : storeName.trim();
    final UserCredential user = UserCredential(
      userId: _uuid.v4(),
      pinHash: hashPin(pin),
      role: 'owner',
      storeName: trimmedName,
    );
    await _dao.insert(user);

    // Write to Firestore — fire-and-forget, never blocks registration
    if (!current.isOfflineMode && current.storeId != null) {
      FirebaseFirestore.instance
          .collection('stores')
          .doc(current.storeId)
          .collection('profile')
          .doc('info')
          .set(<String, dynamic>{
        'storeName': trimmedName,
        'pinHash': user.pinHash,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((_) {});
    }

    state = AsyncData<AuthState>(current.copyWith(
      user: user,
      isFirstRun: false,
      storeNameHint: trimmedName,
    ));
    return true;
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

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
        localizedReason: 'Authenticate to access Sar-E',
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
          state.value!.copyWith(errorMessage: 'Biometric auth failed: $e'));
      return false;
    }
  }

  Future<bool> login(String pin) async {
    final AuthState currentState = state.value!;
    state = AsyncData<AuthState>(
        currentState.copyWith(isLoading: true, clearError: true));
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
        currentState.copyWith(user: loggedIn, isLoading: false));
    return true;
  }

  // ─── Session ───────────────────────────────────────────────────────────────

  /// Ends the current PIN session; store data & storeId are preserved.
  /// Returns to LoginScreen.
  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    final bool isOfflineMode = prefs.getBool('isOfflineMode') ?? false;
    final bool hasOwner = await _dao.exists();
    final String? hint = state.value?.storeNameHint;
    state = AsyncData<AuthState>(AuthState(
      isFirstRun: !hasOwner || storeId == null,
      storeId: storeId,
      isOfflineMode: isOfflineMode,
      storeNameHint: hint,
    ));
  }

  /// Full sign-out: removes all local user records + clears storeId.
  /// Returns to SetupScreen. For offline stores, caller must warn user first.
  Future<void> signOut() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('storeId');
    await prefs.remove('isOfflineMode');
    await prefs.remove('paymentQrPath');
    await _dao.deleteAll(); // remove all PIN records so setup screen shows
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {}
    if (_googleSignInInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    state = const AsyncData<AuthState>(AuthState(isFirstRun: true));
  }

  Future<void> updateStoreName(String name) async {
    final UserCredential? user = state.value?.user;
    if (user == null) return;
    final UserCredential updated = user.copyWith(storeName: name);
    await _dao.update(updated);
    state = AsyncData<AuthState>(
        state.value!.copyWith(user: updated, storeNameHint: name));
  }

  Future<void> changePin(String newPin) async {
    final UserCredential? user = state.value?.user;
    if (user == null) return;
    final String newHash = hashPin(newPin);
    final UserCredential updated = user.copyWith(pinHash: newHash);
    await _dao.update(updated);
    state = AsyncData<AuthState>(state.value!.copyWith(user: updated));

    // Sync to Firestore so returning devices pick up the new PIN
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    final bool isOffline = prefs.getBool('isOfflineMode') ?? false;
    if (!isOffline && storeId != null) {
      FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .collection('profile')
          .doc('info')
          .update(<String, dynamic>{'pinHash': newHash}).catchError((_) {});
    }
  }

  /// Retrieve the cloud-stored PIN hash for an existing store.
  /// Returns null if no hash is found (legacy stores).
  Future<String?> getCloudPinHash() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    if (storeId == null) return null;
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('stores')
          .doc(storeId)
          .collection('profile')
          .doc('info')
          .get();
      return doc.data()?['pinHash'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Reset PIN during setup when user forgot their PIN.
  /// Since they're already authenticated via Google, we trust them.
  Future<bool> resetPinFromSetup(String newPin, String storeName) async {
    final AuthState current = state.value!;
    if (current.storeId == null) return false;
    if (newPin.length < 4) return false;

    final String trimmedName =
        storeName.trim().isEmpty ? 'My Store' : storeName.trim();
    final String newHash = hashPin(newPin);
    final UserCredential user = UserCredential(
      userId: _uuid.v4(),
      pinHash: newHash,
      role: 'owner',
      storeName: trimmedName,
    );
    await _dao.insert(user);

    // Update Firestore
    try {
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(current.storeId)
          .collection('profile')
          .doc('info')
          .set(<String, dynamic>{
        'storeName': trimmedName,
        'pinHash': newHash,
      }, SetOptions(merge: true));
    } catch (_) {}

    state = AsyncData<AuthState>(current.copyWith(
      user: user,
      isFirstRun: false,
      storeNameHint: trimmedName,
    ));
    return true;
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
