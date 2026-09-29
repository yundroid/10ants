import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ten_ants/models/models.dart';
import 'package:ten_ants/services/auth_service.dart';
import 'package:ten_ants/services/data_store.dart';
import 'package:ten_ants/services/password_hasher.dart';

void main() {
  late Database db;
  late AuthService auth;
  late DataStore store;
  var dbCounter = 0;

  setUp(() async {
    db = await databaseFactoryMemory.openDatabase('test-${dbCounter++}.db');
    auth = AuthService(db, hasher: PasswordHasher(iterations: 10));
    store = DataStore(db, auth, clock: () => DateTime(2026, 9, 10));
  });

  tearDown(() async {
    await store.idle;
    store.dispose();
    await db.close();
  });

  group('PasswordHasher', () {
    test('doğru şifreyi doğrular, yanlışı reddeder, her seferinde farklı tuz', () {
      final h = PasswordHasher(iterations: 50);
      final a = h.hash('gizli123');
      final b = h.hash('gizli123');
      expect(a, isNot(b));
      expect(h.verify('gizli123', a), isTrue);
      expect(h.verify('gizli124', a), isFalse);
      expect(h.verify('gizli123', 'bozuk'), isFalse);
    });
  });

  group('AuthService', () {
    test('kayıt, çıkış, giriş', () async {
      await auth.register(name: 'Ayşe Yılmaz', email: 'Ayse@Example.com', password: 'karinca1');
      expect(auth.currentUser!.email, 'ayse@example.com');
      await auth.logout();
      expect(auth.isLoggedIn, isFalse);
      await auth.login('AYSE@example.com ', 'karinca1');
      expect(auth.currentUser!.name, 'Ayşe Yılmaz');
    });

    test('aynı e-posta ile ikinci kayıt engellenir', () async {
      await auth.register(name: 'A', email: 'a@b.com', password: 'karinca1');
      await auth.logout();
      expect(
        () => auth.register(name: 'B', email: 'A@B.com', password: 'karinca1'),
        throwsA(isA<AuthException>()),
      );
    });

    test('zayıf şifre ve yanlış giriş reddedilir', () async {
      expect(() => auth.register(name: 'A', email: 'a@b.com', password: '123'),
          throwsA(isA<AuthException>()));
      expect(() => auth.register(name: 'A', email: 'a@b.com', password: 'abcdefg'),
          throwsA(isA<AuthException>()));
      await auth.register(name: 'A', email: 'a@b.com', password: 'karinca1');
      await auth.logout();
      expect(() => auth.login('a@b.com', 'yanlis11'), throwsA(isA<AuthException>()));
      expect(() => auth.login('yok@b.com', 'karinca1'), throwsA(isA<AuthException>()));
    });

    test('şifre değiştirme', () async {
      await auth.register(name: 'A', email: 'a@b.com', password: 'karinca1');
      expect(
        () => auth.changePassword(currentPassword: 'yanlis11', newPassword: 'yeniSifre2'),
        throwsA(isA<AuthException>()),
      );
      await auth.changePassword(currentPassword: 'karinca1', newPassword: 'yeniSifre2');
      await auth.logout();
      expect(() => auth.login('a@b.com', 'karinca1'), throwsA(isA<AuthException>()));
      await auth.login('a@b.com', 'yeniSifre2');
      expect(auth.isLoggedIn, isTrue);
    });

    test('beni hatırla oturumu geri yükler', () async {
      await auth.register(name: 'A', email: 'a@b.com', password: 'karinca1');
      final auth2 = AuthService(db, hasher: PasswordHasher(iterations: 10));
      await auth2.restoreSession();
      expect(auth2.currentUser?.email, 'a@b.com');

      await auth.logout();
      await auth.login('a@b.com', 'karinca1', remember: false);
      final auth3 = AuthService(db, hasher: PasswordHasher(iterations: 10));
      await auth3.restoreSession();
      expect(auth3.isLoggedIn, isFalse);
    });
  });

  group('DataStore', () {
    Future<(Property, Tenant)> seed() async {
      await auth.register(name: 'A', email: 'a@b.com', password: 'karinca1');
      await store.reload();
      final p = await store.saveProperty(Property(userId: store.userId, name: 'Moda 3+1'));
      final t = await store.saveTenant(Tenant(
        userId: store.userId,
        propertyId: p.id!,
        name: 'Mehmet',
        rentAmount: 15000,
        dueDay: 5,
        leaseStart: DateTime(2026, 7, 1),
      ));
      return (p, t);
    }

    test('ödeme sonrası borç azalır, mülk geliri artar', () async {
      final (p, t) = await seed();
      // 10 Eylül: Temmuz, Ağustos, Eylül vadeleri (5'i) geçti.
      expect(store.overdue.length, 3);
      expect(store.debtOf(t), 45000);

      await store.recordRentPayment(tenant: t, period: '2026-07', amount: 15000);
      await store.recordRentPayment(tenant: t, period: '2026-08', amount: 5000);
      expect(store.debtOf(t), 25000);
      expect(store.txnsOfProperty(p.id!).length, 2);
    });

    test('kullanıcılar birbirinin verisini göremez', () async {
      final (p, _) = await seed();
      await auth.logout();
      expect(store.properties, isEmpty);

      await auth.register(name: 'B', email: 'b@b.com', password: 'karinca1');
      await store.reload();
      expect(store.properties, isEmpty);
      expect(store.tenants, isEmpty);
      // Başkasının mülküne erişim reddedilir.
      expect(() => store.deleteProperty(p.id!), throwsStateError);
      expect(
        () => store.saveTenant(Tenant(
          userId: store.userId,
          propertyId: p.id!,
          name: 'X',
          rentAmount: 1,
          leaseStart: DateTime(2026),
        )),
        throwsStateError,
      );
    });

    test('mülk silinince kiracıları ve hareketleri de silinir', () async {
      final (p, t) = await seed();
      await store.recordRentPayment(tenant: t, period: '2026-07', amount: 15000);
      await store.saveTxn(Txn(
        userId: store.userId,
        propertyId: p.id,
        type: TxType.expense,
        category: 'Aidat',
        amount: 800,
        date: DateTime(2026, 8, 1),
      ));
      await store.deleteProperty(p.id!);
      expect(store.properties, isEmpty);
      expect(store.tenants, isEmpty);
      expect(store.transactions, isEmpty);
    });

    test('kiracı silinince ödemeleri gelir olarak kalır', () async {
      final (_, t) = await seed();
      await store.recordRentPayment(tenant: t, period: '2026-07', amount: 15000);
      await store.deleteTenant(t.id!);
      expect(store.tenants, isEmpty);
      expect(store.transactions.single.tenantId, isNull);
      expect(store.transactions.single.amount, 15000);
    });

    test('pasife alınan kiracının takibi bugünde durur', () async {
      final (_, t) = await seed();
      final saved = await store.saveTenant(t.copyWith(active: false));
      expect(saved.leaseEnd, DateTime(2026, 9, 10));
      expect(store.activeTenants, isEmpty);
    });

    test('hesap silinince tüm veriler silinir', () async {
      await seed();
      await auth.deleteAccount('karinca1');
      expect(auth.isLoggedIn, isFalse);
      await auth.register(name: 'A', email: 'a@b.com', password: 'karinca1');
      await store.reload();
      expect(store.properties, isEmpty);
    });

    test('örnek veriler: gecikme ve kazanç hesaplanır', () async {
      await auth.register(name: 'A', email: 'a@b.com', password: 'karinca1');
      await store.idle;
      await store.seedDemoData();
      expect(store.properties.length, 4);
      expect(store.properties.where(store.isVacant).length, 1);
      final mehmet = store.tenants.firstWhere((t) => t.name == 'Mehmet Kaya');
      final ayse = store.tenants.firstWhere((t) => t.name == 'Ayşe Demir');
      // Bugün 10 Eylül: Mehmet Ağustos'u ödemedi (Eylül vadesi bugün, henüz gecikmedi).
      expect(store.debtOf(mehmet), 18500);
      expect(store.debtOf(ayse), 0);
      expect(store.overdue, isNotEmpty);
    });

    test('geçersiz veri reddedilir', () async {
      final (p, _) = await seed();
      expect(
        () => store.saveTenant(Tenant(
          userId: store.userId,
          propertyId: p.id!,
          name: 'X',
          rentAmount: 0,
          leaseStart: DateTime(2026),
        )),
        throwsArgumentError,
      );
      expect(
        () => store.saveTxn(Txn(
          userId: store.userId,
          type: TxType.expense,
          category: 'Aidat',
          amount: -5,
          date: DateTime(2026),
        )),
        throwsArgumentError,
      );
    });
  });
}
