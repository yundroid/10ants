import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:ten_ants/main.dart';
import 'package:ten_ants/services/auth_service.dart';
import 'package:ten_ants/services/password_hasher.dart';

void main() {
  setUpAll(() async {
    Intl.defaultLocale = 'tr_TR';
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('kayıt ol → mülk ekle → kiracı ekle → özet ekranı', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final db = await tester.runAsync(() => databaseFactoryMemory.openDatabase('flow.db'));
    final auth = AuthService(db!, hasher: PasswordHasher(iterations: 10));

    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(TenAntsApp(db: db, auth: auth));
    await settle();
    expect(find.text('Yuvaya giriş'), findsOneWidget);

    // Hesap oluştur
    await tester.tap(find.text('Hesap oluştur'));
    await settle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Zeynep Karınca');
    await tester.enterText(fields.at(1), 'zeynep@example.com');
    await tester.enterText(fields.at(2), 'yuva1234');
    await tester.enterText(fields.at(3), 'yuva1234');
    await tester.tap(find.widgetWithText(FilledButton, 'Hesap oluştur'));
    await settle();
    expect(find.textContaining('Merhaba Zeynep'), findsOneWidget);
    expect(find.text('Yuvan henüz boş'), findsOneWidget);

    // Mülk ekle
    await tester.tap(find.widgetWithText(FilledButton, 'Mülk ekle'));
    await settle();
    await tester.tap(find.byType(FloatingActionButton));
    await settle();
    await tester.enterText(find.byType(TextFormField).first, 'Moda 2+1');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await settle();
    expect(find.text('Moda 2+1'), findsOneWidget);
    expect(find.text('Boş'), findsOneWidget);

    // Kiracı ekle (sözleşme bugünden başlar)
    await tester.tap(find.text('Kiracılar'));
    await settle();
    await tester.tap(find.byType(FloatingActionButton));
    await settle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Ad soyad'), 'Ahmet Yılmaz');
    await tester.tap(find.text('Mülk').last);
    await settle();
    await tester.tap(find.text('Moda 2+1').last);
    await settle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Aylık kira'), '12.500');
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await settle();
    expect(find.text('Ahmet Yılmaz'), findsOneWidget);

    // Özet: 1 mülk, 1 aktif kiracı, beklenen kira
    await tester.tap(find.text('Özet'));
    await settle();
    expect(find.text('BEKLENEN KİRA'), findsOneWidget);
    expect(find.textContaining('12.500,00'), findsWidgets);

    // Şifre değiştir ekranına gidilebiliyor
    await tester.tap(find.byTooltip('Hesap ve ayarlar').first);
    await settle();
    expect(find.text('Şifre değiştir'), findsOneWidget);
    await tester.tap(find.text('Çıkış yap'));
    await settle();
    expect(find.text('Yuvaya giriş'), findsOneWidget);
  });
}
