import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WaterPage extends StatefulWidget {
  const WaterPage({super.key});

  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  final sb = Supabase.instance.client;

  int dailyTargetMl = 2000;
  int consumedMl = 0;

  bool loading = true;

  final List<_WaterLog> logs = [];

  String get userId => sb.auth.currentUser!.id;

  double get progress =>
      dailyTargetMl == 0 ? 0 : (consumedMl / dailyTargetMl).clamp(0, 1);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      await _loadProfileTarget();
      await _loadTodayLogs();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadProfileTarget() async {
    final row = await sb
        .from('profiles')
        .select('daily_target_ml')
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) {
      await sb.from('profiles').upsert(
        {'user_id': userId},
        onConflict: 'user_id',
      );
      dailyTargetMl = 2000;
      return;
    }

    dailyTargetMl = (row['daily_target_ml'] as int?) ?? 2000;
  }

  Future<void> _loadTodayLogs() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final startIso = startOfDay.toIso8601String();

    final data = await sb
        .from('water_logs')
        .select('id, amount_ml, created_at')
        .eq('user_id', userId)
        .gte('created_at', startIso)
        .order('created_at', ascending: false);

    logs
      ..clear()
      ..addAll((data as List).map((e) {
        final dt = DateTime.parse(e['created_at'] as String).toLocal();
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return _WaterLog(
          id: (e['id'] as num).toInt(),
          time: "$hh:$mm",
          amountMl: (e['amount_ml'] as num).toInt(),
          createdAt: dt,
        );
      }));

    consumedMl = logs.fold<int>(0, (sum, x) => sum + x.amountMl);

    if (mounted) setState(() {});
  }

  Future<void> _addWater(int ml) async {
    if (ml <= 0) return;

    try {
      await sb.from('water_logs').insert({
        'user_id': userId,
        'amount_ml': ml,
      });

      await _loadTodayLogs();

      // ✅ Rozet kontrolleri (tek yerden)
      await _checkAndAwardBadges(
        addedMl: ml,
        at: DateTime.now(),
      );

      _snack("+$ml ml eklendi ✅");
    } catch (e) {
      _snack("Hata: $e");
    }
  }

  Future<void> _undoLast() async {
    if (logs.isEmpty) {
      _snack("Geri alınacak kayıt yok.");
      return;
    }

    try {
      final last = logs.first; // en yeni kayıt
      await sb
          .from('water_logs')
          .delete()
          .eq('id', last.id)
          .eq('user_id', userId);

      await _loadTodayLogs();

      // ✅ “Döktüm Gitti” rozetini 1 kere yaz
      await _awardBadgeOnce('oops_spill');

      _snack("Son kayıt geri alındı ✅");
    } catch (e) {
      _snack("Undo hata: $e");
    }
  }

  /// ✅ Tek sefer yaz (unique constraint olmasa bile çoğaltmaz)
  Future<void> _awardBadgeOnce(String badgeKey) async {
    try {
      final exists = await sb
          .from('user_badges')
          .select('id')
          .eq('user_id', userId)
          .eq('badge_key', badgeKey)
          .maybeSingle();

      if (exists != null) return;

      await sb.from('user_badges').insert({
        'user_id': userId,
        'badge_key': badgeKey,
      });
    } catch (_) {
      // Sessiz geç: rozet yazılamasa bile app kırılmasın
    }
  }

  /// ✅ Su ekleyince rozet kontrolü
  Future<void> _checkAndAwardBadges({
    required int addedMl,
    required DateTime at,
  }) async {
    // 1) Günlük hedef ilk kez tamamlandı
    if (consumedMl >= dailyTargetMl) {
      await _awardBadgeOnce('daily_goal_completed');
    }

    // 2) 5 Litre Efsanesi (aynı gün 5000ml+)
    if (consumedMl >= 5000) {
      await _awardBadgeOnce('legend_5000');
    }

    // 3) Tek Yudum Canavar (tek seferde 1000ml+)
    if (addedMl >= 1000) {
      await _awardBadgeOnce('big_gulp');
    }

    // 4) Gece Baykuşu: 02:00 - 04:59 arası
    if (at.hour >= 2 && at.hour < 5) {
      await _awardBadgeOnce('night_owl');
    }

    // 5) Erken Kuş: 05:00 - 05:59 arası
    if (at.hour >= 5 && at.hour < 6) {
      await _awardBadgeOnce('early_bird');
    }

    // 6) 7 Günlük Seri
    await _check7DayStreak();
  }

  /// ✅ Son 7 günün her gününde hedef tamamlandı mı?
  Future<void> _check7DayStreak() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final startIso = start.toIso8601String();

    final data = await sb
        .from('water_logs')
        .select('amount_ml, created_at')
        .eq('user_id', userId)
        .gte('created_at', startIso);

    final Map<String, int> totalsByDay = {};
    for (final e in (data as List)) {
      final dt = DateTime.parse(e['created_at'] as String).toLocal();
      final key =
          "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
      final ml = (e['amount_ml'] as num).toInt();
      totalsByDay[key] = (totalsByDay[key] ?? 0) + ml;
    }

    bool ok = true;
    for (int i = 0; i < 7; i++) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));
      final key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final total = totalsByDay[key] ?? 0;

      if (total < dailyTargetMl) {
        ok = false;
        break;
      }
    }

    if (ok) {
      await _awardBadgeOnce('streak_7_days');
    }
  }

  void _snack(String t) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openAddWaterSheet() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _AddWaterSheet(),
    );

    if (selected != null) {
      await _addWater(selected);
    }
  }

  Future<void> _editTarget() async {
    final newTarget = await _askDailyTarget(context, dailyTargetMl);
    if (newTarget == null || newTarget <= 0) return;

    try {
      await sb.from('profiles').upsert(
        {'user_id': userId, 'daily_target_ml': newTarget},
        onConflict: 'user_id',
      );

      setState(() => dailyTargetMl = newTarget);
      _snack("Hedef güncellendi: $newTarget ml");

      await _loadTodayLogs();
    } catch (e) {
      _snack("Hedef hata: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Su Takibi"),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Son kaydı geri al",
            onPressed: _undoLast,
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: "Hedefi Düzenle",
            onPressed: _editTarget,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddWaterSheet,
        icon: const Icon(Icons.add),
        label: const Text("Su Ekle"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Bugünkü Hedef",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                    color: theme.colorScheme.outlineVariant),
                              ),
                              child: Text(
                                "${(progress * 100).round()}%",
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "$consumedMl / $dailyTargetMl ml",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            Text(
                              "${(dailyTargetMl - consumedMl).clamp(0, dailyTargetMl)} ml kaldı",
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(.7),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _addWater(250),
                                icon: const Icon(Icons.bolt),
                                label: const Text("+250"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _addWater(500),
                                icon: const Icon(Icons.bolt),
                                label: const Text("+500"),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _openAddWaterSheet,
                                icon: const Icon(Icons.add),
                                label: const Text("Seç"),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bugün Kayıtlar",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (logs.isEmpty)
                          Text(
                            "Henüz kayıt yok. + butonundan su ekle.",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withOpacity(.7),
                            ),
                          ),
                        for (final log in logs) _LogTile(log: log),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
    );
  }
}

class _AddWaterSheet extends StatelessWidget {
  const _AddWaterSheet();

  @override
  Widget build(BuildContext context) {
    final customCtrl = TextEditingController();

    Widget pill(int ml) {
      return SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context, ml),
          child: Text("$ml ml"),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 6),
          const Text(
            "Su miktarı seç",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              pill(150),
              pill(200),
              pill(250),
              pill(300),
              pill(400),
              pill(500),
              pill(750),
              pill(1000),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: customCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Özel miktar (ml)",
              prefixIcon: Icon(Icons.edit),
              hintText: "Örn: 350",
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () {
                final ml = int.tryParse(customCtrl.text.trim());
                if (ml == null || ml <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Geçerli bir ml değeri gir."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, ml);
              },
              icon: const Icon(Icons.check),
              label: const Text("Ekle"),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  final _WaterLog log;

  const _LogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.water_drop),
      title: Text("${log.amountMl} ml"),
      subtitle: Text(log.time),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _WaterLog {
  final int id;
  final String time;
  final int amountMl;
  final DateTime createdAt;

  const _WaterLog({
    required this.id,
    required this.time,
    required this.amountMl,
    required this.createdAt,
  });
}

Future<int?> _askDailyTarget(BuildContext context, int current) async {
  final ctrl = TextEditingController(text: current.toString());
  return showDialog<int>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text("Günlük Hedef (ml)"),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: "Örn: 2000",
            prefixIcon: Icon(Icons.flag_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v == null || v <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Geçerli bir hedef gir."),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(context, v);
            },
            child: const Text("Kaydet"),
          ),
        ],
      );
    },
  );
}
