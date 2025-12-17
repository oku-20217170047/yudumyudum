import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text;

    if (email.isEmpty || pass.isEmpty) {
      _snack("E-posta ve şifre gir.");
      return;
    }

    setState(() => loading = true);
    try {
      final sb = Supabase.instance.client;

      final res = await sb.auth.signInWithPassword(email: email, password: pass);

      if (res.user == null) {
        _snack("Giriş başarısız.");
        return;
      }

      // profil upsert (yoksa oluştur)
      await sb.from('profiles').upsert(
        {'user_id': res.user!.id},
        onConflict: 'user_id',
      );

      if (mounted) context.go('/app');
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack("Hata: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Su Takip",
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Supabase ile gerçek giriş/kayıt aktif.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(.75),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 26),

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: "E-posta",
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: passCtrl,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: "Şifre",
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 48,
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: loading ? null : _login,
                              icon: loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login),
                              label: Text(loading ? "Giriş yapılıyor..." : "Giriş Yap"),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text("Hesabın yok mu? Kayıt ol"),
                          ),
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
    );
  }
}
