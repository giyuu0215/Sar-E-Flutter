import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/local/daos/user_dao.dart';
import '../domain/entities/user_credential.dart';

const int _maxAttempts = 5;
const Duration _lockDuration = Duration(minutes: 30);

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

  bool get isLoggedIn => user != null && storeId != null;

  AuthState copyWith({
    UserCredential? user,
    bool? isFirstRun,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
    String? storeId,
  }) =>
      AuthState(
        user: user ?? this.user,
        isFirstRun: isFirstRun ?? this.isFirstRun,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        isLoading: isLoading ?? this.isLoading,
        storeId: storeId ?? this.storeId,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  final UserDao _dao = UserDao();
  static const Uuid _uuid = Uuid();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Future<AuthState> build() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    final bool hasOwner = await _dao.exists();
    
    return AuthState(isFirstRun: !hasOwner || storeId == null, storeId: storeId);
  }

  /// Authenticate with Google to link device to a store
  Future<bool> linkStoreWithGoogle() async {
    state = const AsyncData<AuthState>(AuthState(isLoading: true));
    try {
      final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
      if (gUser == null) {
        state = AsyncData<AuthState>(state.value!.copyWith(
          isLoading: false,
          errorMessage: 'Google Sign-In canceled.',
        ));
        return false;
      }

      final GoogleSignInAuthentication gAuth = gUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: gAuth.accessToken,
        idToken: gAuth.idToken,
      );

      final UserCredential firebaseUser = await FirebaseAuth.instance.signInWithCredential(credential);
      final String storeId = firebaseUser.user!.uid;

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('storeId', storeId);

      state = AsyncData<AuthState>(state.value!.copyWith(
        isLoading: false,
        storeId: storeId,
      ));
      return true;
    } catch (e) {
      state = AsyncData<AuthState>(state.value!.copyWith(
        isLoading: false,
        errorMessage: 'Failed to sign in with Google: $e',
      ));
      return false;
    }
  }

  /// Register the owner PIN after Google link.
  Future<bool> register(String pin, String storeName) async {
    if (pin.length < 4) {
      state = AsyncData<AuthState>(
        state.value!.copyWith(
            errorMessage: 'PIN must be at least 4 digits'),
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
    state = AsyncData<AuthState>(state.value!.copyWith(user: user, isFirstRun: false));
    return true;
  }

  /// Login with Biometrics (Local Auth)
  Future<bool> loginWithBiometrics() async {
    final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();

    if (!canAuthenticate) {
      state = AsyncData<AuthState>(state.value!.copyWith(errorMessage: 'Biometrics not supported on this device.'));
      return false;
    }

    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access Sar-E',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (didAuthenticate) {
        // If biometrics succeed, log in the Owner implicitly (or the last user, but for now we assume Owner)
        // Let's find the owner user credential
        final List<UserCredential> users = await _dao.getAllUsers();
        final UserCredential? owner = users.where((u) => u.role == 'owner').firstOrNull;
        
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
      state = AsyncData<AuthState>(state.value!.copyWith(errorMessage: 'Biometric Auth failed.'));
      return false;
    }
  }

  /// Login with PIN.
  Future<bool> login(String pin) async {
    final AuthState currentState = state.value!;
    state = AsyncData<AuthState>(currentState.copyWith(isLoading: true));

    final String hashed = hashPin(pin);
    final UserCredential? user = await _dao.getUserByPinHash(hashed);
    
    if (user == null) {
      state = AsyncData<AuthState>(
          currentState.copyWith(errorMessage: 'Invalid PIN.', isLoading: false));
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

    // Success
    final UserCredential loggedIn = user.copyWith(
      failedAttempts: 0,
      clearLock: true,
      lastLoginAt: DateTime.now(),
    );
    await _dao.update(loggedIn);
    state = AsyncData<AuthState>(currentState.copyWith(user: loggedIn, isLoading: false));
    return true;
  }

  Future<void> logout() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? storeId = prefs.getString('storeId');
    final bool hasOwner = await _dao.exists();
    state = AsyncData<AuthState>(AuthState(isFirstRun: !hasOwner || storeId == null, storeId: storeId));
  }

  Future<void> clearStoreLink() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('storeId');
    await FirebaseAuth.instance.signOut();
    await _googleSignIn.signOut();
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
