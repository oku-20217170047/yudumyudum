import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final sb = Supabase.instance.client;

  bool loading = true;

  int goalMl = 2000;

  // son 7 gün toplamları (bugün dahil)
List<DateTime> days = const [];
List<int> totals = const [];


  int todayTotal = 0;
  int streak = 0;

  String get userId => sb.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
  final intro = GoRouterState.of(context).uri.queryParameters['intro'] == '1';
  if (intro) {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) context.go('/app');
    });
  }
});

    _load();
  }

  DateTime _dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final now = DateTime.now();
      final today = _dayStart(now);
      final start = today.subtract(const Duration(days: 6));

      // 1) hedef (profiles)
final profile = await sb
    .from('profiles')
    .select('daily_target_ml')
    .eq('user_id', userId)
    .maybeSingle();

goalMl = (profile?['daily_target_ml'] as num?)?.toInt() ?? 2000;



      // 2) son 7 gün su logları
      final rows = await sb
          .from('water_logs')
          .select('amount_ml, created_at')
          .eq('user_id', userId)
          .gte('created_at', start.toIso8601String());

      final Map<DateTime, int> sumByDay = {};
      for (final r in (rows as List)) {
        final createdAt = DateTime.parse(r['created_at'] as String).toLocal();
        final dayKey = _dayStart(createdAt);
        final amount = (r['amount_ml'] as num).toInt();
        sumByDay[dayKey] = (sumByDay[dayKey] ?? 0) + amount;
      }

      days = List.generate(7, (i) => start.add(Duration(days: i)));
      totals = days.map((d) => sumByDay[d] ?? 0).toList();

      todayTotal = totals.last;

      // streak: bugünden geriye doğru hedefi tutturan gün sayısı
      int s = 0;
      for (int i = totals.length - 1; i >= 0; i--) {
        if (totals[i] >= goalMl) {
          s++;
        } else {
          break;
        }
      }
      streak = s;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dashboard hata: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _dowShort(DateTime d) {
    // basit TR kısaltma
    const names = ['Paz', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cts'];
    return names[d.weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
if (days.length != 7 || totals.length != 7) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Dashboard"),
      centerTitle: true,
      actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    ),
    body: const Center(child: CircularProgressIndicator()),
  );
}


    final percent = goalMl <= 0 ? 0.0 : (todayTotal / goalMl).clamp(0.0, 1.0);
    final remaining = (goalMl - todayTotal).clamp(0, 999999);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Bugün kartı
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Bugün",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "$todayTotal ml / $goalMl ml",
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: percent),
                          const SizedBox(height: 8),
                          Text("Kalan: $remaining ml"),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Streak kartı
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.local_fire_department),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "Streak: $streak gün",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 7 gün grafiği
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        height: 260,
                        child: BarChart(
                          BarChartData(
                            maxY: (totals.reduce((a, b) => a > b ? a : b).toDouble() * 1.2)
                                .clamp(500.0, 999999.0),
                            gridData: const FlGridData(show: true),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx < 0 || idx > 6) return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(_dowShort(days[idx])),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: List.generate(7, (i) {
                              return BarChartGroupData(
                                x: i,
                                barRods: [
                                  BarChartRodData(
                                    toY: totals[i].toDouble(),
                                    width: 18,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}
