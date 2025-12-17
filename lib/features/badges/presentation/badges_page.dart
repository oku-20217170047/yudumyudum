import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  final sb = Supabase.instance.client;

  bool loading = true;

  // DB'den gelen kazanılan rozetler (badge_key)
  Set<String> unlocked = {};
  final Map<String, DateTime> earnedAtByKey = {};

  String get userId => sb.auth.currentUser!.id;

  // ✅ Rozet kataloğu (komik + sticker gibi)
  // badge_key -> user_badges.badge_key ile aynı olmalı
  final List<_BadgeDef> catalog = const [
    _BadgeDef(
      key: 'daily_goal_completed',
      title: "Günlük Su Ustası",
      desc: "Bir günde hedefi ilk kez tamamladın.",
      emoji: "🏆💧",
      kind: _BadgeKind.gold,
    ),
    _BadgeDef(
      key: 'streak_7_days',
      title: "7 Günlük Seri",
      desc: "7 gün üst üste hedefi tutturdun.",
      emoji: "🔥7️⃣",
      kind: _BadgeKind.purple,
    ),
    _BadgeDef(
      key: 'habit_7_days',
      title: "Disiplin",
      desc: "7 gün alışkanlık tamamla.",
      emoji: "✅🧠",
      kind: _BadgeKind.green,
    ),

    // ekstra rozetler (tetiklerini sonra bağlarız)
    _BadgeDef(
      key: 'night_owl',
      title: "Gece Baykuşu",
      desc: "02:00 sonrası su içtin.",
      emoji: "🦉🌙",
      kind: _BadgeKind.blue,
    ),
    _BadgeDef(
      key: 'early_bird',
      title: "Erken Kuş",
      desc: "06:00’dan önce su içtin.",
      emoji: "🐦🌅",
      kind: _BadgeKind.teal,
    ),
    _BadgeDef(
      key: 'big_gulp',
      title: "Tek Yudum Canavar",
      desc: "Tek seferde 1000ml bastın.",
      emoji: "🧃👹",
      kind: _BadgeKind.red,
    ),
    _BadgeDef(
      key: 'oops_spill',
      title: "Döktüm Gitti",
      desc: "Undo ile son kaydı geri aldın.",
      emoji: "😅🫗",
      kind: _BadgeKind.orange,
    ),
    _BadgeDef(
      key: 'legend_5000',
      title: "5 Litre Efsanesi",
      desc: "Bir günde 5000ml üstüne çıktın.",
      emoji: "🐳💧",
      kind: _BadgeKind.blue,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => loading = true);
    try {
      final data = await sb
          .from('user_badges')
          .select('badge_key, earned_at')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      unlocked = {};
      earnedAtByKey.clear();

      for (final e in (data as List)) {
        final key = (e['badge_key'] as String?)?.trim();
        if (key == null || key.isEmpty) continue;
        unlocked.add(key);

        final earnedAtStr = e['earned_at'] as String?;
        if (earnedAtStr != null) {
          earnedAtByKey[key] = DateTime.parse(earnedAtStr).toLocal();
        }
      }
    } catch (e) {
      _snack("Rozetler alınamadı: $e");
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
    final earned = catalog.where((b) => unlocked.contains(b.key)).toList();
    final locked = catalog.where((b) => !unlocked.contains(b.key)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Rozetler"),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _loadBadges, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadBadges,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(earned: earned.length, total: catalog.length),
                  const SizedBox(height: 12),

                  _SectionTitle(
                    icon: Icons.verified,
                    title: "Kazanılanlar",
                    subtitle: earned.isEmpty
                        ? "Henüz rozet yok. Su iç, rozet yağar 😄"
                        : "${earned.length} rozet açıldı",
                  ),
                  const SizedBox(height: 10),
                  if (earned.isEmpty)
                    const _EmptyHint(text: "İlk hedefini tamamlayınca ilk rozet geliyor 🏆")
                  else
                    _BadgeGrid(
                      items: earned,
                      locked: false,
                      earnedAtByKey: earnedAtByKey,
                    ),

                  const SizedBox(height: 16),

                  _SectionTitle(
                    icon: Icons.lock_outline,
                    title: "Kazanılmayanlar",
                    subtitle: "${locked.length} rozet kilitli",
                  ),
                  const SizedBox(height: 10),
                  _BadgeGrid(
                    items: locked,
                    locked: true,
                    earnedAtByKey: earnedAtByKey,
                  ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final int earned;
  final int total;

  const _HeaderCard({required this.earned, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = total == 0 ? 0.0 : earned / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Rozet Koleksiyonu",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text("$earned / $total açıldı"),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(value: p, minHeight: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(text),
      ),
    );
  }
}

class _BadgeGrid extends StatelessWidget {
  final List<_BadgeDef> items;
  final bool locked;
  final Map<String, DateTime> earnedAtByKey;

  const _BadgeGrid({
    required this.items,
    required this.locked,
    required this.earnedAtByKey,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // ✅ Kartlara biraz daha yükseklik veriyoruz (overflow fix)
        childAspectRatio: 0.90,
      ),
      itemBuilder: (context, i) {
        final b = items[i];
        final colors = b.kind.colors(context);

        final earnedAt = earnedAtByKey[b.key];
        final dateText = earnedAt == null
            ? null
            : "${earnedAt.day.toString().padLeft(2, '0')}.${earnedAt.month.toString().padLeft(2, '0')} "
              "${earnedAt.hour.toString().padLeft(2, '0')}:${earnedAt.minute.toString().padLeft(2, '0')}";

        final sticker = _BadgeSticker(
          title: b.title,
          desc: b.desc,
          emoji: b.emoji,
          bg: colors.$1,
          border: colors.$2,
          earnedAtText: dateText,
        );

        return locked ? Opacity(opacity: 0.45, child: sticker) : sticker;
      },
    );
  }
}

class _BadgeSticker extends StatelessWidget {
  final String title;
  final String desc;
  final String emoji;
  final Color bg;
  final Color border;
  final String? earnedAtText;

  const _BadgeSticker({
    required this.title,
    required this.desc,
    required this.emoji,
    required this.bg,
    required this.border,
    required this.earnedAtText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border.withOpacity(.65)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bg.withOpacity(.30), bg.withOpacity(.08)],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          // ✅ içerik taşmasın
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg.withOpacity(.30),
                    border: Border.all(color: border.withOpacity(.75)),
                  ),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(earnedAtText != null ? "✅" : "🔒"),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            const SizedBox(height: 6),

            // ✅ açıklama alanı esnek olsun
            Expanded(
              child: Text(
                desc,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurface.withOpacity(.70),
                ),
              ),
            ),

            if (earnedAtText != null) ...[
              const SizedBox(height: 6),
              Text(
                earnedAtText!,
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onSurface.withOpacity(.60),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _BadgeKind { gold, purple, blue, green, red, teal, orange }

extension on _BadgeKind {
  (Color, Color) colors(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (this) {
      case _BadgeKind.gold:
        return (cs.tertiary, cs.tertiary);
      case _BadgeKind.purple:
        return (Colors.purpleAccent, Colors.deepPurple);
      case _BadgeKind.blue:
        return (Colors.lightBlueAccent, Colors.blue);
      case _BadgeKind.green:
        return (Colors.lightGreenAccent, Colors.green);
      case _BadgeKind.red:
        return (Colors.redAccent, Colors.red);
      case _BadgeKind.teal:
        return (Colors.tealAccent, Colors.teal);
      case _BadgeKind.orange:
        return (Colors.orangeAccent, Colors.deepOrange);
    }
  }
}

class _BadgeDef {
  final String key;
  final String title;
  final String desc;
  final String emoji;
  final _BadgeKind kind;

  const _BadgeDef({
    required this.key,
    required this.title,
    required this.desc,
    required this.emoji,
    required this.kind,
  });
}
