import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';

import '../data/attachment_storage.dart';
import '../data/stores.dart';
import '../models/models.dart';
import '../utils/format.dart';
import 'auth_service.dart';
import 'rent_calculator.dart';

/// Oturum açmış kullanıcının mülk, kiracı ve gelir/gider kayıtlarını tutar.
///
/// [AuthService]'i dinler: kullanıcı değişince verileri yeniden yükler,
/// çıkış yapılınca temizler. Tüm sorgular kullanıcının kendi kayıtlarıyla
/// sınırlıdır.
class DataStore extends ChangeNotifier {
  DataStore(this._db, this._auth, {DateTime Function()? clock, AttachmentStorage? files})
      : _clock = clock ?? DateTime.now,
        files = files ?? MemoryAttachmentStorage() {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final Database _db;
  final AuthService _auth;
  final DateTime Function() _clock;

  /// Gelir/gider eklerinin (fotoğraf, PDF) saklandığı yer.
  final AttachmentStorage files;

  int? _userId;
  bool _loading = false;
  List<Property> _properties = [];
  List<Tenant> _tenants = [];
  List<Txn> _txns = [];

  bool get loading => _loading;
  int get userId => _uid;
  DateTime get today => dateOnly(_clock());
  List<Property> get properties => List.unmodifiable(_properties);
  List<Tenant> get tenants => List.unmodifiable(_tenants);
  List<Tenant> get activeTenants => _tenants.where((t) => t.active).toList();

  /// Hareketler, en yeni tarih önce.
  List<Txn> get transactions => List.unmodifiable(_txns);

  Property? propertyById(int? id) =>
      id == null ? null : _properties.where((p) => p.id == id).firstOrNull;
  Tenant? tenantById(int? id) =>
      id == null ? null : _tenants.where((t) => t.id == id).firstOrNull;

  List<Tenant> tenantsOf(int propertyId) =>
      _tenants.where((t) => t.propertyId == propertyId).toList();
  List<Txn> txnsOfProperty(int propertyId) =>
      _txns.where((t) => t.propertyId == propertyId).toList();
  List<Txn> txnsOfTenant(int tenantId) =>
      _txns.where((t) => t.tenantId == tenantId).toList();

  bool isVacant(Property p) => !_tenants.any((t) => t.propertyId == p.id && t.active);

  List<RentPeriod> ledgerOf(Tenant t) => RentCalculator.ledger(t, _txns, today);
  List<RentPeriod> get overdue => RentCalculator.overdue(_tenants, _txns, today);
  List<RentPeriod> get upcomingThisMonth =>
      RentCalculator.upcomingThisMonth(_tenants, _txns, today);
  double debtOf(Tenant t) => RentCalculator.totalDebt(
      ledgerOf(t).where((p) => p.status == RentStatus.overdue));

  void _onAuthChanged() {
    final id = _auth.currentUser?.id;
    if (id == _userId) return;
    _userId = id;
    if (id == null) {
      _loading = false;
      _properties = [];
      _tenants = [];
      _txns = [];
      notifyListeners();
    } else {
      _pending = reload();
    }
  }

  Future<void>? _pending;

  /// Kullanıcı değişince arka planda başlayan yüklemenin bitmesini bekler.
  Future<void> get idle => _pending ?? Future.value();

  int get _uid {
    final id = _userId;
    if (id == null) throw StateError('Oturum açık değil');
    return id;
  }

  Future<void> reload() async {
    final uid = _userId;
    if (uid == null) return;
    _loading = true;
    notifyListeners();
    Finder mine(List<SortOrder> sort) =>
        Finder(filter: Filter.equals('userId', uid), sortOrders: sort);
    final props = await Stores.properties.find(_db, finder: mine([SortOrder('name')]));
    final tens = await Stores.tenants.find(_db, finder: mine([SortOrder('name')]));
    final txs = await Stores.transactions.find(_db,
        finder: mine([SortOrder('date', false), SortOrder(Field.key, false)]));
    // Yükleme sürerken kullanıcı değiştiyse sonuçları at; yeni kullanıcının
    // yüklemesi zaten başlatıldı.
    if (uid != _userId) return;
    _properties = [for (final r in props) Property.fromMap(r.key, r.value)];
    _tenants = [for (final r in tens) Tenant.fromMap(r.key, r.value)];
    _txns = [for (final r in txs) Txn.fromMap(r.key, r.value)];
    _loading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------- Mülkler

  Future<Property> saveProperty(Property p) async {
    _assertOwned(p.userId);
    if (p.name.trim().isEmpty) throw ArgumentError('Mülk adı gerekli');
    Property saved;
    if (p.id == null) {
      final id = await Stores.properties.add(_db, p.toMap());
      saved = p.copyWith(id: id);
    } else {
      await _requireOwned(Stores.properties, p.id!);
      await Stores.properties.record(p.id!).put(_db, p.toMap());
      saved = p;
    }
    await reload();
    return saved;
  }

  /// Mülkü, kiracılarını ve mülke ait tüm hareketleri siler.
  Future<void> deleteProperty(int id) async {
    await _requireOwned(Stores.properties, id);
    final orphaned = await _db.transaction((txn) async {
      final tenantIds = (await Stores.tenants.findKeys(txn,
              finder: Finder(filter: Filter.equals('propertyId', id))))
          .toList();
      final finder = Finder(
          filter: Filter.or([
        Filter.equals('propertyId', id),
        if (tenantIds.isNotEmpty) Filter.inList('tenantId', tenantIds),
      ]));
      final ids = attachmentIdsOf(await Stores.transactions.find(txn, finder: finder));
      await Stores.transactions.delete(txn, finder: finder);
      await Stores.tenants.records(tenantIds).delete(txn);
      await Stores.properties.record(id).delete(txn);
      return ids;
    });
    await files.deleteAll(orphaned);
    await reload();
  }

  // --------------------------------------------------------------- Kiracılar

  Future<Tenant> saveTenant(Tenant t) async {
    _assertOwned(t.userId);
    if (t.name.trim().isEmpty) throw ArgumentError('Kiracı adı gerekli');
    if (t.rentAmount <= 0) throw ArgumentError('Kira tutarı sıfırdan büyük olmalı');
    if (t.dueDay < 1 || t.dueDay > 31) throw ArgumentError('Ödeme günü 1-31 arası olmalı');
    if (t.leaseEnd != null && t.leaseEnd!.isBefore(t.leaseStart)) {
      throw ArgumentError('Sözleşme bitişi başlangıçtan önce olamaz');
    }
    await _requireOwned(Stores.properties, t.propertyId);
    // Pasife alınan kiracının borç takibi bugünde dursun.
    if (!t.active && t.leaseEnd == null) t = t.copyWith(leaseEnd: today);

    Tenant saved;
    if (t.id == null) {
      final id = await Stores.tenants.add(_db, t.toMap());
      saved = t.copyWith(id: id);
    } else {
      await _requireOwned(Stores.tenants, t.id!);
      await _db.transaction((txn) async {
        await Stores.tenants.record(t.id!).put(txn, t.toMap());
        // Kiracı başka mülke taşındıysa kira kayıtları da taşınsın.
        await Stores.transactions.update(txn, {'propertyId': t.propertyId},
            finder: Finder(filter: Filter.equals('tenantId', t.id)));
      });
      saved = t;
    }
    await reload();
    return saved;
  }

  /// Kiracıyı siler. Ödeme kayıtları gelir olarak kalır, kiracı bağı kopar.
  Future<void> deleteTenant(int id) async {
    await _requireOwned(Stores.tenants, id);
    await _db.transaction((txn) async {
      await Stores.transactions.update(txn, {'tenantId': null},
          finder: Finder(filter: Filter.equals('tenantId', id)));
      await Stores.tenants.record(id).delete(txn);
    });
    await reload();
  }

  // -------------------------------------------------------------- Hareketler

  /// Hareketi kaydeder. [newFiles], [Txn.attachments] içindeki yeni eklerin
  /// baytlarıdır (ek kimliği → bayt). Kayıttan çıkarılan eklerin dosyaları
  /// silinir.
  Future<Txn> saveTxn(Txn t, {Map<String, Uint8List> newFiles = const {}}) async {
    _assertOwned(t.userId);
    if (t.amount <= 0) throw ArgumentError('Tutar sıfırdan büyük olmalı');
    if (t.attachments.length > Attachment.maxPerTxn) {
      throw ArgumentError('Bir kayda en fazla ${Attachment.maxPerTxn} belge eklenebilir');
    }
    for (final a in t.attachments) {
      if (a.size > Attachment.maxBytes) throw ArgumentError('"${a.name}" 10 MB\'tan büyük');
    }
    if (t.propertyId != null) await _requireOwned(Stores.properties, t.propertyId!);
    if (t.tenantId != null) await _requireOwned(Stores.tenants, t.tenantId!);

    for (final e in newFiles.entries) {
      await files.write(e.key, e.value);
    }
    Txn saved;
    var removed = <String>[];
    if (t.id == null) {
      final id = await Stores.transactions.add(_db, t.toMap());
      saved = t.copyWith(id: id);
    } else {
      final old = await _requireOwned(Stores.transactions, t.id!);
      final keep = {for (final a in t.attachments) a.id};
      removed = [
        for (final a in Txn.fromMap(t.id!, old).attachments)
          if (!keep.contains(a.id)) a.id,
      ];
      await Stores.transactions.record(t.id!).put(_db, t.toMap());
      saved = t;
    }
    await files.deleteAll(removed);
    await reload();
    return saved;
  }

  Future<Uint8List?> readAttachment(Attachment a) => files.read(a.id);

  static List<String> attachmentIdsOf(
          Iterable<RecordSnapshot<int, Map<String, Object?>>> records) =>
      [
        for (final r in records)
          for (final a in Txn.fromMap(r.key, r.value).attachments) a.id,
      ];

  /// Kiracı için kira tahsilatı kaydeder.
  Future<Txn> recordRentPayment({
    required Tenant tenant,
    required String period,
    required double amount,
    DateTime? date,
    String description = '',
    List<Attachment> attachments = const [],
    Map<String, Uint8List> newFiles = const {},
  }) =>
      saveTxn(Txn(
        userId: _uid,
        propertyId: tenant.propertyId,
        tenantId: tenant.id,
        type: TxType.income,
        category: TxCategories.rent,
        amount: amount,
        date: date ?? today,
        period: period,
        description: description,
        attachments: attachments,
      ), newFiles: newFiles);

  Future<void> deleteTxn(int id) async {
    final rec = await _requireOwned(Stores.transactions, id);
    await Stores.transactions.record(id).delete(_db);
    await files.deleteAll(Txn.fromMap(id, rec).attachments.map((a) => a.id));
    await reload();
  }

  /// Uygulamayı denemek için örnek mülk, kiracı ve hareketler ekler.
  Future<void> seedDemoData() async {
    final uid = _uid;
    final now = today;
    DateTime monthsAgo(int m, [int day = 1]) => DateTime(now.year, now.month - m, day);

    await _db.transaction((txn) async {
      Future<int> prop(String name, PropertyType type, String address) => Stores.properties
          .add(txn, Property(userId: uid, name: name, type: type, address: address).toMap());
      Future<Tenant> tenant(Tenant t) async =>
          t.copyWith(id: await Stores.tenants.add(txn, t.toMap()));
      Future<void> tx(Txn t) => Stores.transactions.add(txn, t.toMap());

      final moda = await prop('Moda 3+1', PropertyType.daire, 'Caferağa Mah., Kadıköy / İstanbul');
      final bahce = await prop('Bahçeli Müstakil', PropertyType.mustakil, 'Urla / İzmir');
      final dukkan = await prop('Çarşı Dükkanı', PropertyType.dukkan, 'Kızılay, Çankaya / Ankara');
      await prop('Kalamış 1+1', PropertyType.daire, 'Fenerbahçe, Kadıköy / İstanbul');

      final ayse = await tenant(Tenant(
          userId: uid, propertyId: moda, name: 'Ayşe Demir', phone: '0532 000 00 01',
          rentAmount: 22000, dueDay: 5, leaseStart: monthsAgo(8), deposit: 44000));
      final mehmet = await tenant(Tenant(
          userId: uid, propertyId: bahce, name: 'Mehmet Kaya', phone: '0533 000 00 02',
          rentAmount: 18500, dueDay: 10, leaseStart: monthsAgo(6), deposit: 37000));
      final firin = await tenant(Tenant(
          userId: uid, propertyId: dukkan, name: 'Lezzet Fırını (Hasan Öz)',
          phone: '0312 000 00 03', rentAmount: 30000, dueDay: 1, leaseStart: monthsAgo(10)));

      // Ayşe her ay düzenli öder. Mehmet son iki ayı ödemedi. Fırın bu ay
      // kısmi ödedi.
      Future<void> rent(Tenant t, int ago, {double? amount, int day = 3}) => tx(Txn(
          userId: uid, propertyId: t.propertyId, tenantId: t.id, type: TxType.income,
          category: TxCategories.rent, amount: amount ?? t.rentAmount,
          date: monthsAgo(ago, day), period: periodKey(monthsAgo(ago))));
      for (var m = 8; m >= 0; m--) {
        if (m == 0 && now.day < 5) break;
        await rent(ayse, m, day: 4);
      }
      for (var m = 6; m >= 2; m--) {
        await rent(mehmet, m, day: 9);
      }
      for (var m = 10; m >= 1; m--) {
        await rent(firin, m, day: 1);
      }
      await rent(firin, 0, amount: 15000, day: 1);

      Future<void> expense(int? property, String cat, double amount, int ago, [String d = '']) =>
          tx(Txn(userId: uid, propertyId: property, type: TxType.expense, category: cat,
              amount: amount, date: monthsAgo(ago, 15), description: d));
      for (var m = 5; m >= 0; m--) {
        await expense(moda, 'Aidat', 1800, m);
      }
      await expense(moda, 'Tamir & Bakım', 6500, 3, 'Kombi bakımı');
      await expense(bahce, 'Emlak Vergisi', 4200, 4);
      await expense(bahce, 'Tamir & Bakım', 12500, 1, 'Çatı onarımı');
      await expense(dukkan, 'DASK & Sigorta', 3100, 2);
      await expense(null, 'Fatura', 950, 1, 'Muhasebeci');
    });
    await reload();
  }

  // ---------------------------------------------------------------- Yardımcı

  void _assertOwned(int userId) {
    if (userId != _uid) throw StateError('Bu kayıt size ait değil');
  }

  Future<Map<String, Object?>> _requireOwned(
      StoreRef<int, Map<String, Object?>> store, int id) async {
    final rec = await store.record(id).get(_db);
    if (rec == null || rec['userId'] != _uid) {
      throw StateError('Kayıt bulunamadı');
    }
    return rec;
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
