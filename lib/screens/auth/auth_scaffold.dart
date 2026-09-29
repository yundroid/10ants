import 'package:flutter/material.dart';

import '../../widgets/ant_art.dart';

/// Giriş/kayıt ekranlarının ortak düzeni: karınca yuvası arka planı üzerinde
/// ortalanmış bir kart.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: AntNestBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    const AntLogo(size: 76),
                    const SizedBox(height: 8),
                    Text('10ants',
                        style: tt.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.primary,
                            letterSpacing: -1)),
                    Text('Yuvanı düzenli tut, kiranı zamanında topla',
                        style: tt.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(title,
                                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(subtitle, style: tt.bodyMedium),
                            const SizedBox(height: 20),
                            child,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Şifre',
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        validator: widget.validator,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onSubmitted,
        autofillHints: widget.autofillHints,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            tooltip: _obscure ? 'Göster' : 'Gizle',
            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      );
}
