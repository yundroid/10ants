import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// PBKDF2-HMAC-SHA256 ile şifre hashleme.
///
/// Saklanan biçim: `pbkdf2$<iterasyon>$<tuz(base64)>$<hash(base64)>`
class PasswordHasher {
  PasswordHasher({this.iterations = 20000, Random? random})
      : _random = random ?? Random.secure();

  final int iterations;
  final Random _random;
  static const _keyLength = 32;

  String hash(String password) {
    final salt = Uint8List.fromList(List.generate(16, (_) => _random.nextInt(256)));
    final key = _pbkdf2(utf8.encode(password), salt, iterations);
    return 'pbkdf2\$$iterations\$${base64Encode(salt)}\$${base64Encode(key)}';
  }

  bool verify(String password, String stored) {
    final parts = stored.split('\$');
    if (parts.length != 4 || parts[0] != 'pbkdf2') return false;
    final iter = int.tryParse(parts[1]);
    if (iter == null || iter <= 0) return false;
    final salt = base64Decode(parts[2]);
    final expected = base64Decode(parts[3]);
    final actual = _pbkdf2(utf8.encode(password), salt, iter);
    return _constantTimeEquals(actual, expected);
  }

  static Uint8List _pbkdf2(List<int> password, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, password);
    final out = Uint8List(_keyLength);
    // 32 baytlık anahtar için SHA-256 ile tek blok yeterli.
    final block = [...salt, 0, 0, 0, 1];
    var u = hmac.convert(block).bytes;
    final t = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    out.setAll(0, t);
    return out;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
