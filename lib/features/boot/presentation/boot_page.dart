import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/notification_service.dart';

class BootPage extends StatefulWidget {
  const BootPage({super.key});

  @override
  State<BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<BootPage> {
  @override
  void initState() {
    super.initState();

    // Bildirim altyapısı test (tek seferlik)
    NotificationService.instance.showNow(
      title: "Su Takip",
      body: "Bildirim altyapısı hazır ✅",
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = Supabase.instance.client.auth.currentSession;
if (session != null) {
  context.go('/dashboard?intro=1');

} else {
  context.go('/login');
}

    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
