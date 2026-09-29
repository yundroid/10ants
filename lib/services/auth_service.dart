import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../data/stores.dart';
import '../models/models.dart';
import 'password_hasher.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Hesap oluşturma, giriş/çıkış, şifre değiştirme ve oturumun hatırlanması.
///
/// Hesaplar cihazdaki veritabanında tutulur; şifreler asla düz metin olarak
/// saklanmaz.
class AuthService extends ChangeNotifier {
  AuthService(this._db, {PasswordHasher? hasher})
      : _hasher = hasher ?? PasswordHasher();

  final Database _db;
  final PasswordHasher _hasher;

  static const minPasswordLength = 6;
  static const _sessionKey = 'sessionUserId';

  AppUser? _user;
  AppUser? get currentUser => _user;
  bool get isLoggedIn => _user != null;

  /// Uygulama açılırken "beni hatırla" ile kaydedilmiş oturumu geri yükler.
  Future<void> restoreSession() async {
    final id = await Stores.meta.record(_sessionKey).get(_db) as int?;
    if (id == null) return;
    final rec = await Stores.users.record(id).get(_db);
    if (rec == null) {
      await Stores.meta.record(_sessionKey).delete(_db);
      return;
    }
    _user = AppUser.fromMap(id, rec);
    notifyListeners();
  }

  static String normalizeEmail(String email) => email.trim().toLowerCase();

  static String? validateEmail(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'E-posta gerekli';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return 'Geçerli bir e-posta girin';
    }
    return null;
  }

  static String? validatePassword(String? v) {
    final s = v ?? '';
    if (s.length < minPasswordLength) {
      return 'Şifre en az $minPasswordLength karakter olmalı';
    }
    if (!RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(s) || !RegExp(r'\d').hasMatch(s)) {
      return 'Şifre en az bir harf ve bir rakam içermeli';
    }
    return null;
  }

  Future<RecordSnapshot<int, Map<String, Object?>>?> _findByEmail(String email) =>
      Stores.users.findFirst(
        _db,
        finder: Finder(filter: Filter.equals('email', normalizeEmail(email))),
      );

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    bool remember = true,
  }) async {
    if (name.trim().isEmpty) throw AuthException('Ad soyad gerekli');
    final emailErr = validateEmail(email);
    if (emailErr != null) throw AuthException(emailErr);
    final passErr = validatePassword(password);
    if (passErr != null) throw AuthException(passErr);

    return _db.transaction((txn) async {
      final existing = await Stores.users.findFirst(
        txn,
        finder: Finder(filter: Filter.equals('email', normalizeEmail(email))),
      );
      if (existing != null) {
        throw AuthException('Bu e-posta ile kayıtlı bir hesap zaten var');
      }
      final data = {
        'name': name.trim(),
        'email': normalizeEmail(email),
        'passwordHash': _hasher.hash(password),
        'createdAt': DateTime.now().toIso8601String(),
      };
      final id = await Stores.users.add(txn, data);
      return AppUser.fromMap(id, data);
    }).then((user) async {
      await _setSession(user, remember);
      return user;
    });
  }

  Future<AppUser> login(String email, String password, {bool remember = true}) async {
    final rec = await _findByEmail(email);
    if (rec == null) {
      // Kullanıcı yoksa da hash hesaplayarak yanıt süresini eşitle.
      _hasher.verify(password, _dummyHash);
      throw AuthException('E-posta veya şifre hatalı');
    }
    if (!_hasher.verify(password, rec.value['passwordHash'] as String)) {
      throw AuthException('E-posta veya şifre hatalı');
    }
    final user = AppUser.fromMap(rec.key, rec.value);
    await _setSession(user, remember);
    return user;
  }

  late final String _dummyHash = _hasher.hash('dummy-password-0');

  Future<void> _setSession(AppUser user, bool remember) async {
    _user = user;
    if (remember) {
      await Stores.meta.record(_sessionKey).put(_db, user.id);
    } else {
      await Stores.meta.record(_sessionKey).delete(_db);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null;
    await Stores.meta.record(_sessionKey).delete(_db);
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _requireUser();
    if (!_hasher.verify(currentPassword, user.passwordHash)) {
      throw AuthException('Mevcut şifre hatalı');
    }
    final err = validatePassword(newPassword);
    if (err != null) throw AuthException(err);
    if (currentPassword == newPassword) {
      throw AuthException('Yeni şifre mevcut şifreden farklı olmalı');
    }
    final updated = user.copyWith(passwordHash: _hasher.hash(newPassword));
    await Stores.users.record(user.id).put(_db, updated.toMap());
    _user = updated;
    notifyListeners();
  }

  Future<void> updateProfile({required String name, required String email}) async {
    final user = _requireUser();
    if (name.trim().isEmpty) throw AuthException('Ad soyad gerekli');
    final emailErr = validateEmail(email);
    if (emailErr != null) throw AuthException(emailErr);
    final other = await _findByEmail(email);
    if (other != null && other.key != user.id) {
      throw AuthException('Bu e-posta başka bir hesapta kullanılıyor');
    }
    final updated = user.copyWith(name: name.trim(), email: normalizeEmail(email));
    await Stores.users.record(user.id).put(_db, updated.toMap());
    _user = updated;
    notifyListeners();
  }

  /// Hesabı ve hesaba ait tüm mülk, kiracı ve hareket kayıtlarını siler.
  Future<void> deleteAccount(String password) async {
    final user = _requireUser();
    if (!_hasher.verify(password, user.passwordHash)) {
      throw AuthException('Şifre hatalı');
    }
    final byUser = Finder(filter: Filter.equals('userId', user.id));
    await _db.transaction((txn) async {
      await Stores.transactions.delete(txn, finder: byUser);
      await Stores.tenants.delete(txn, finder: byUser);
      await Stores.properties.delete(txn, finder: byUser);
      await Stores.users.record(user.id).delete(txn);
    });
    await logout();
  }

  AppUser _requireUser() {
    final u = _user;
    if (u == null) throw AuthException('Oturum açık değil');
    return u;
  }
}
