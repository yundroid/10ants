/// Uygulamanın veri modelleri.
///
/// Tüm tarihler veritabanında `yyyy-MM-dd`, kira dönemleri `yyyy-MM`
/// biçiminde metin olarak tutulur.
library;

import '../utils/format.dart';

class AppUser {
  final int id;
  final String name;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  factory AppUser.fromMap(int id, Map<String, Object?> m) => AppUser(
        id: id,
        name: m['name'] as String,
        email: m['email'] as String,
        passwordHash: m['passwordHash'] as String,
        createdAt: DateTime.parse(m['createdAt'] as String),
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'createdAt': createdAt.toIso8601String(),
      };

  AppUser copyWith({String? name, String? email, String? passwordHash}) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        createdAt: createdAt,
      );
}

enum PropertyType {
  daire('Daire'),
  mustakil('Müstakil Ev'),
  villa('Villa'),
  dukkan('Dükkan'),
  ofis('Ofis'),
  arsa('Arsa'),
  diger('Diğer');

  const PropertyType(this.label);
  final String label;

  static PropertyType parse(String? s) =>
      PropertyType.values.firstWhere((e) => e.name == s, orElse: () => diger);
}

class Property {
  final int? id;
  final int userId;
  final String name;
  final String address;
  final PropertyType type;
  final String notes;

  const Property({
    this.id,
    required this.userId,
    required this.name,
    this.address = '',
    this.type = PropertyType.daire,
    this.notes = '',
  });

  factory Property.fromMap(int id, Map<String, Object?> m) => Property(
        id: id,
        userId: m['userId'] as int,
        name: m['name'] as String,
        address: (m['address'] as String?) ?? '',
        type: PropertyType.parse(m['type'] as String?),
        notes: (m['notes'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        'userId': userId,
        'name': name,
        'address': address,
        'type': type.name,
        'notes': notes,
      };

  Property copyWith({int? id}) => Property(
        id: id ?? this.id,
        userId: userId,
        name: name,
        address: address,
        type: type,
        notes: notes,
      );
}

class Tenant {
  final int? id;
  final int userId;
  final int propertyId;
  final String name;
  final String phone;
  final String email;
  final double rentAmount;

  /// Kiranın her ay ödenmesi gereken gün (1-31). Ay daha kısaysa ayın son
  /// günü kullanılır.
  final int dueDay;
  final DateTime leaseStart;
  final DateTime? leaseEnd;
  final double deposit;
  final String notes;
  final bool active;

  const Tenant({
    this.id,
    required this.userId,
    required this.propertyId,
    required this.name,
    this.phone = '',
    this.email = '',
    required this.rentAmount,
    this.dueDay = 1,
    required this.leaseStart,
    this.leaseEnd,
    this.deposit = 0,
    this.notes = '',
    this.active = true,
  });

  factory Tenant.fromMap(int id, Map<String, Object?> m) => Tenant(
        id: id,
        userId: m['userId'] as int,
        propertyId: m['propertyId'] as int,
        name: m['name'] as String,
        phone: (m['phone'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        rentAmount: (m['rentAmount'] as num).toDouble(),
        dueDay: m['dueDay'] as int,
        leaseStart: parseDate(m['leaseStart'] as String),
        leaseEnd: m['leaseEnd'] == null ? null : parseDate(m['leaseEnd'] as String),
        deposit: ((m['deposit'] as num?) ?? 0).toDouble(),
        notes: (m['notes'] as String?) ?? '',
        active: (m['active'] as bool?) ?? true,
      );

  Map<String, Object?> toMap() => {
        'userId': userId,
        'propertyId': propertyId,
        'name': name,
        'phone': phone,
        'email': email,
        'rentAmount': rentAmount,
        'dueDay': dueDay,
        'leaseStart': dateKey(leaseStart),
        'leaseEnd': leaseEnd == null ? null : dateKey(leaseEnd!),
        'deposit': deposit,
        'notes': notes,
        'active': active,
      };

  Tenant copyWith({int? id, bool? active, DateTime? leaseEnd}) => Tenant(
        id: id ?? this.id,
        userId: userId,
        propertyId: propertyId,
        name: name,
        phone: phone,
        email: email,
        rentAmount: rentAmount,
        dueDay: dueDay,
        leaseStart: leaseStart,
        leaseEnd: leaseEnd ?? this.leaseEnd,
        deposit: deposit,
        notes: notes,
        active: active ?? this.active,
      );
}

enum TxType { income, expense }

class TxCategories {
  static const rent = 'Kira';
  static const income = [rent, 'Depozito', 'Aidat Tahsilatı', 'Diğer Gelir'];
  static const expense = [
    'Tamir & Bakım',
    'Aidat',
    'Emlak Vergisi',
    'DASK & Sigorta',
    'Fatura',
    'Kredi Taksiti',
    'Emlakçı Komisyonu',
    'Tadilat',
    'Diğer Gider',
  ];

  static List<String> of(TxType t) => t == TxType.income ? income : expense;
}

/// Bir gelir/gider kaydına eklenmiş belge (fiş, fatura, dekont fotoğrafı
/// veya PDF). Dosyanın kendisi [AttachmentStorage]'da [id] ile tutulur.
class Attachment {
  const Attachment({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.size,
  });

  final String id;
  final String name;
  final String mimeType;
  final int size;

  bool get isImage => mimeType.startsWith('image/');
  bool get isPdf => mimeType == 'application/pdf';

  factory Attachment.fromMap(Map<String, Object?> m) => Attachment(
        id: m['id'] as String,
        name: m['name'] as String,
        mimeType: m['mimeType'] as String,
        size: m['size'] as int,
      );

  Map<String, Object?> toMap() => {'id': id, 'name': name, 'mimeType': mimeType, 'size': size};

  static const maxBytes = 10 * 1024 * 1024;
  static const maxPerTxn = 5;
  static const allowedExtensions = ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'];

  /// Uzantıya göre MIME türü; desteklenmeyen türde `null`.
  static String? mimeFor(String fileName) {
    final dot = fileName.lastIndexOf('.');
    final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'pdf' => 'application/pdf',
      _ => null,
    };
  }
}

/// Gelir veya gider kaydı. Kira ödemeleri `category == 'Kira'`, bir
/// [tenantId] ve ilgili [period] (`yyyy-MM`) ile tutulur.
class Txn {
  final int? id;
  final int userId;
  final int? propertyId;
  final int? tenantId;
  final TxType type;
  final String category;
  final double amount;
  final DateTime date;
  final String? period;
  final String description;

  const Txn({
    this.id,
    required this.userId,
    this.propertyId,
    this.tenantId,
    required this.type,
    required this.category,
    required this.amount,
    required this.date,
    this.period,
    this.description = '',
    this.attachments = const [],
  });

  final List<Attachment> attachments;

  bool get isRentPayment =>
      type == TxType.income && category == TxCategories.rent && tenantId != null;

  factory Txn.fromMap(int id, Map<String, Object?> m) => Txn(
        id: id,
        userId: m['userId'] as int,
        propertyId: m['propertyId'] as int?,
        tenantId: m['tenantId'] as int?,
        type: m['type'] == 'expense' ? TxType.expense : TxType.income,
        category: m['category'] as String,
        amount: (m['amount'] as num).toDouble(),
        date: parseDate(m['date'] as String),
        period: m['period'] as String?,
        description: (m['description'] as String?) ?? '',
        attachments: [
          for (final a in (m['attachments'] as List?) ?? const [])
            Attachment.fromMap((a as Map).cast<String, Object?>()),
        ],
      );

  Map<String, Object?> toMap() => {
        'userId': userId,
        'propertyId': propertyId,
        'tenantId': tenantId,
        'type': type.name,
        'category': category,
        'amount': amount,
        'date': dateKey(date),
        'period': period,
        'description': description,
        'attachments': [for (final a in attachments) a.toMap()],
      };

  Txn copyWith({int? id}) => Txn(
        id: id ?? this.id,
        userId: userId,
        propertyId: propertyId,
        tenantId: tenantId,
        type: type,
        category: category,
        amount: amount,
        date: date,
        period: period,
        description: description,
        attachments: attachments,
      );
}
