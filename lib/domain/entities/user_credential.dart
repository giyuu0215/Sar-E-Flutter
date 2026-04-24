/// Domain entity – user_credentials table.
class UserCredential {
  const UserCredential({
    required this.userId,
    required this.pinHash,
    required this.role,
    this.biometricEnabled = false,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.lastLoginAt,
    this.storeName = 'My Store',
  });

  final String userId;
  final String pinHash;
  final String role; // 'owner' | 'cashier'
  final bool biometricEnabled;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final DateTime? lastLoginAt;
  final String storeName;

  bool get isLocked =>
      lockedUntil != null && lockedUntil!.isAfter(DateTime.now());

  UserCredential copyWith({
    String? pinHash,
    String? role,
    bool? biometricEnabled,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLock = false,
    DateTime? lastLoginAt,
    String? storeName,
  }) {
    return UserCredential(
      userId: userId,
      pinHash: pinHash ?? this.pinHash,
      role: role ?? this.role,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLock ? null : (lockedUntil ?? this.lockedUntil),
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      storeName: storeName ?? this.storeName,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'user_id': userId,
        'pin_hash': pinHash,
        'role': role,
        'biometric_enabled': biometricEnabled ? 1 : 0,
        'failed_attempts': failedAttempts,
        'locked_until': lockedUntil?.toIso8601String(),
        'last_login_at': lastLoginAt?.toIso8601String(),
        'store_name': storeName,
      };

  factory UserCredential.fromMap(Map<String, dynamic> m) => UserCredential(
        userId: m['user_id'] as String,
        pinHash: m['pin_hash'] as String,
        role: m['role'] as String,
        biometricEnabled: (m['biometric_enabled'] as int?) == 1,
        failedAttempts: (m['failed_attempts'] as int?) ?? 0,
        lockedUntil: m['locked_until'] != null
            ? DateTime.parse(m['locked_until'] as String)
            : null,
        lastLoginAt: m['last_login_at'] != null
            ? DateTime.parse(m['last_login_at'] as String)
            : null,
        storeName: (m['store_name'] as String?) ?? 'My Store',
      );
}
