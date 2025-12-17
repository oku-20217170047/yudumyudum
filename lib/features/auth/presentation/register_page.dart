import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

Future<void> _register() async {
  final name = nameCtrl.text.trim();
  final email = emailCtrl.text.trim();
  final pass = passCtrl.text;

  if (email.isEmpty || pass.length < 6) {
    _snack("E-posta gir ve şifre en az 6 karakter olsun.");
    return;
  }

  setState(() => loading = true);
  try {
    final sb = Supabase.instance.client;

    final res = await sb.auth.signUp(email: email, password: pass);

    // Email confirmation AÇIKSA session gelmez -> DB'ye yazma!
    final session = sb.auth.currentSession;
    if (session == null) {
      _snack("Kayıt alındı. Mail doğrulaması gerekiyorsa mailini kontrol et, sonra giriş yap.");
      if (mounted) context.go('/login');
      return;
    }

    // Session varsa artık auth.uid() var, RLS geçer:
    final userId = res.user?.id ?? sb.auth.currentUser!.id;

    await sb.from('profiles').upsert(
      {
        'user_id': userId,
        if (name.isNotEmpty) 'display_name': name,
      },
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
      appBar: AppBar(
        title: const Text("Kayıt Ol"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Yeni hesap oluştur",
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: "Ad (opsiyonel)",
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
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
                          labelText: "Şifre (min 6)",
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: loading ? null : _register,
                          icon: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.check),
                          label: Text(loading ? "Kayıt ediliyor..." : "Kayıt Ol"),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text("Zaten hesabın var mı? Giriş yap"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
