import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });

  final UserCredential? user;
  final bool isFirstRun;
  final String? errorMessage;
  final bool isLoading;

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    UserCredential? user,
    bool? isFirstRun,
    String? errorMessage,
    bool clearError = false,
    bool? isLoading,
  }) =>
      AuthState(
        user: user ?? this.user,
        isFirstRun: isFirstRun ?? this.isFirstRun,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        isLoading: isLoading ?? this.isLoading,
      );
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  final UserDao _dao = UserDao();
  static const Uuid _uuid = Uuid();

  @override
  Future<AuthState> build() async {
    final bool hasOwner = await _dao.exists();
    return AuthState(isFirstRun: !hasOwner);
  }

  /// Register the owner on first run.
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
    state = AsyncData<AuthState>(AuthState(user: user));
    return true;
  }

  /// Login with PIN.
  Future<bool> login(String pin) async {
    state = const AsyncData<AuthState>(AuthState(isLoading: true));

    final String hashed = hashPin(pin);
    final UserCredential? user = await _dao.getUserByPinHash(hashed);
    
    if (user == null) {
      state = const AsyncData<AuthState>(
          AuthState(isFirstRun: false, errorMessage: 'Invalid PIN.'));
      return false;
    }

    if (user.isLocked) {
      final int remaining =
          user.lockedUntil!.difference(DateTime.now()).inMinutes;
      state = AsyncData<AuthState>(AuthState(
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
    state = AsyncData<AuthState>(AuthState(user: loggedIn));
    return true;
  }

  Future<void> logout() async {
    final bool hasOwner = await _dao.exists();
    state = AsyncData<AuthState>(AuthState(isFirstRun: !hasOwner));
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
