import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../utils/format.dart';
import '../widgets/ant_art.dart';
import '../widgets/common.dart';
import 'auth/auth_scaffold.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    if (user == null) return const Scaffold();
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Hesap ve ayarlar')),
      body: PageBody(children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              const AntLogo(size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                  Text(user.email),
                  Text('Üyelik: ${fmtDate(user.createdAt)}', style: tt.bodySmall),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil bilgileri'),
              subtitle: const Text('Ad soyad ve e-posta'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.password),
              title: const Text('Şifre değiştir'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Çıkış yap'),
              onTap: () async {
                final nav = Navigator.of(context);
                await context.read<AuthService>().logout();
                nav.popUntil((r) => r.isFirst);
              },
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: Text('Hesabı sil',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            subtitle: const Text('Hesabın ve tüm verilerin kalıcı olarak silinir'),
            onTap: () => _deleteAccount(context),
          ),
        ),
        const SizedBox(height: 24),
        Text('Veriler bu cihazda saklanır.',
            textAlign: TextAlign.center, style: tt.bodySmall),
      ]),
    );
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final ctl = TextEditingController();
    final auth = context.read<AuthService>();
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı sil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text(
              'Tüm mülk, kiracı ve gelir/gider kayıtların kalıcı olarak silinecek. Onaylamak için şifreni gir.'),
          const SizedBox(height: 12),
          PasswordField(controller: ctl),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kalıcı olarak sil'),
          ),
        ],
      ),
    );
    if (ok != true) {
      ctl.dispose();
      return;
    }
    try {
      await auth.deleteAccount(ctl.text);
      nav.popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      if (context.mounted) showSnack(context, e.message, error: true);
    } finally {
      ctl.dispose();
    }
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _new2 = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _new2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context
          .read<AuthService>()
          .changePassword(currentPassword: _current.text, newPassword: _new.text);
      if (!mounted) return;
      showSnack(context, 'Şifren güncellendi');
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: FormPage(title: 'Şifre değiştir', children: [
          PasswordField(
            controller: _current,
            label: 'Mevcut şifre',
            validator: (v) => (v ?? '').isEmpty ? 'Mevcut şifre gerekli' : null,
          ),
          PasswordField(
            controller: _new,
            label: 'Yeni şifre',
            validator: AuthService.validatePassword,
          ),
          PasswordField(
            controller: _new2,
            label: 'Yeni şifre (tekrar)',
            validator: (v) => v != _new.text ? 'Şifreler eşleşmiyor' : null,
            onSubmitted: (_) => _save(),
          ),
          FilledButton(
              onPressed: _busy ? null : _save, child: const Text('Şifreyi güncelle')),
        ]),
      );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _user = context.read<AuthService>().currentUser!;
  late final _name = TextEditingController(text: _user.name);
  late final _email = TextEditingController(text: _user.email);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AuthService>().updateProfile(name: _name.text, email: _email.text);
      if (!mounted) return;
      showSnack(context, 'Profil güncellendi');
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
        key: _form,
        child: FormPage(title: 'Profil bilgileri', children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Ad soyad'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Ad soyad gerekli' : null,
          ),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-posta'),
            validator: AuthService.validateEmail,
          ),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Kaydet')),
        ]),
      );
}
