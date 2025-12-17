import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/notification_service.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final sb = Supabase.instance.client;

  bool loading = true;
  List<_Habit> habits = [];

  String get userId => sb.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadHabits();
  }

  // JWT expired olursa 1 kez refresh edip aynı işlemi tekrarlar
  Future<T> _withJwtRetry<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      final isJwtExpired =
          e.code == 'PGRST303' || e.message.toLowerCase().contains('jwt expired');

      if (isJwtExpired) {
        await sb.auth.refreshSession();
        return await action();
      }
      rethrow;
    }
  }

  Future<void> _loadHabits() async {
    setState(() => loading = true);
    try {
      final data = await _withJwtRetry(() async {
        return await sb
            .from('habits')
            .select(
                'id, title, interval_minutes, reminders_enabled, is_active, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
      });

      habits = (data as List).map((e) {
        return _Habit(
          id: (e['id'] as num).toInt(),
          title: e['title'] as String,
          intervalMinutes: (e['interval_minutes'] as num).toInt(),
          remindersEnabled: e['reminders_enabled'] as bool,
          isActive: e['is_active'] as bool,
        );
      }).toList();
    } catch (e) {
      _snack("Listeleme hata: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _createHabit() async {
    final res = await showDialog<_HabitDraft>(
      context: context,
      builder: (context) => const _HabitDialog(),
    );
    if (res == null) return;

    try {
      final inserted = await _withJwtRetry(() async {
        return await sb
            .from('habits')
            .insert({
              'user_id': userId,
              'title': res.title,
              'interval_minutes': res.intervalMinutes,
              'reminders_enabled': res.remindersEnabled,
              'is_active': true,
            })
            .select('id, title, interval_minutes, reminders_enabled, is_active')
            .single();
      });

      _snack("Alışkanlık eklendi ✅");

      final habitId = (inserted['id'] as num).toInt();
      final title = inserted['title'] as String;
      final interval = (inserted['interval_minutes'] as num).toInt();
      final remindersEnabled = inserted['reminders_enabled'] as bool;
      final isActive = inserted['is_active'] as bool;

      if (isActive && remindersEnabled) {
        await NotificationService.instance.scheduleOnceAfterMinutes(
          id: habitId,
          minutes: interval,
          title: "Hatırlatma",
          body: title,
        );
      }

      await _loadHabits();
    } catch (e) {
      _snack("Ekleme hata: $e");
    }
  }

  Future<void> _editHabit(_Habit h) async {
    final res = await showDialog<_HabitDraft>(
      context: context,
      builder: (context) => _HabitDialog(
        initialTitle: h.title,
        initialInterval: h.intervalMinutes,
        initialReminders: h.remindersEnabled,
      ),
    );
    if (res == null) return;

    try {
      await _withJwtRetry(() async {
        return await sb
            .from('habits')
            .update({
              'title': res.title,
              'interval_minutes': res.intervalMinutes,
              'reminders_enabled': res.remindersEnabled,
            })
            .eq('id', h.id)
            .eq('user_id', userId);
      });

      await NotificationService.instance.cancel(h.id);

      final willSchedule = res.remindersEnabled && h.isActive;
      if (willSchedule) {
        await NotificationService.instance.scheduleOnceAfterMinutes(
          id: h.id,
          minutes: res.intervalMinutes,
          title: "Hatırlatma",
          body: res.title,
        );
      }

      _snack("Güncellendi ✅");
      await _loadHabits();
    } catch (e) {
      _snack("Güncelleme hata: $e");
    }
  }

  Future<void> _deleteHabit(_Habit h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Silinsin mi?"),
        content: Text("“${h.title}” alışkanlığı silinecek."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("İptal")),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Sil")),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _withJwtRetry(() async {
        return await sb
            .from('habits')
            .delete()
            .eq('id', h.id)
            .eq('user_id', userId);
      });

      await NotificationService.instance.cancel(h.id);

      _snack("Silindi ✅");
      await _loadHabits();
    } catch (e) {
      _snack("Silme hata: $e");
    }
  }

  Future<void> _toggleActive(_Habit h, bool v) async {
    try {
      await _withJwtRetry(() async {
        return await sb
            .from('habits')
            .update({'is_active': v})
            .eq('id', h.id)
            .eq('user_id', userId);
      });

      if (!v) {
        await NotificationService.instance.cancel(h.id);
      } else {
        if (h.remindersEnabled) {
          await NotificationService.instance.scheduleOnceAfterMinutes(
            id: h.id,
            minutes: h.intervalMinutes,
            title: "Hatırlatma",
            body: h.title,
          );
        }
      }

      await _loadHabits();
    } catch (e) {
      _snack("Güncelleme hata: $e");
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
    return Scaffold(
      appBar: AppBar(title: const Text("Alışkanlıklar"), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createHabit,
        icon: const Icon(Icons.add),
        label: const Text("Yeni"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHabits,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (habits.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(
                          child: Text("Henüz alışkanlık yok. + ile ekle.")),
                    ),
                  for (final h in habits)
                    Card(
                      child: ListTile(
                        leading: Icon(h.remindersEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off),
                        title: Text(h.title,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(
                            "${h.intervalMinutes} dk • ${h.isActive ? "Aktif" : "Pasif"}"),
                        trailing: Switch(
                          value: h.isActive,
                          onChanged: (v) => _toggleActive(h, v),
                        ),
                        onTap: () => _editHabit(h),
                        onLongPress: () => _deleteHabit(h),
                      ),
                    ),
                  const SizedBox(height: 90),
                  const Text(
                    "İpucu: Düzenlemek için dokun, silmek için uzun bas.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

class _Habit {
  final int id;
  final String title;
  final int intervalMinutes;
  final bool remindersEnabled;
  final bool isActive;

  const _Habit({
    required this.id,
    required this.title,
    required this.intervalMinutes,
    required this.remindersEnabled,
    required this.isActive,
  });
}

class _HabitDraft {
  final String title;
  final int intervalMinutes;
  final bool remindersEnabled;

  const _HabitDraft({
    required this.title,
    required this.intervalMinutes,
    required this.remindersEnabled,
  });
}

class _HabitDialog extends StatefulWidget {
  final String? initialTitle;
  final int? initialInterval;
  final bool? initialReminders;

  const _HabitDialog({
    this.initialTitle,
    this.initialInterval,
    this.initialReminders,
  });

  @override
  State<_HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<_HabitDialog> {
  late final TextEditingController titleCtrl;
  late final TextEditingController intervalCtrl;
  bool reminders = true;

  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.initialTitle ?? "");
    intervalCtrl = TextEditingController(
        text: (widget.initialInterval ?? 120).toString());
    reminders = widget.initialReminders ?? true;
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    intervalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.initialTitle == null ? "Yeni Alışkanlık" : "Alışkanlığı Düzenle"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleCtrl,
            decoration: const InputDecoration(
              labelText: "Başlık",
              hintText: "Örn: 40 dakikada bir su iç",
              prefixIcon: Icon(Icons.check_circle_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: intervalCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Tetikleme Süresi (dk)",
              hintText: "Örn: 60",
              prefixIcon: Icon(Icons.timer_outlined),
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: reminders,
            onChanged: (v) => setState(() => reminders = v),
            title: const Text("Bildirim/Hatırlatma açık"),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal")),
        FilledButton(
          onPressed: () {
            final title = titleCtrl.text.trim();
            final interval = int.tryParse(intervalCtrl.text.trim());

            if (title.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Başlık zorunlu."),
                    behavior: SnackBarBehavior.floating),
              );
              return;
            }
            if (interval == null || interval <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Süre zorunlu ve > 0 olmalı."),
                    behavior: SnackBarBehavior.floating),
              );
              return;
            }

            Navigator.pop(
              context,
              _HabitDraft(
                title: title,
                intervalMinutes: interval,
                remindersEnabled: reminders,
              ),
            );
          },
          child: const Text("Kaydet"),
        ),
      ],
    );
  }
}
