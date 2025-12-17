import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_mode_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final sb = Supabase.instance.client;

  bool loading = true;

  String displayName = "Kullanıcı";
  String email = "-";
  int dailyTargetMl = 2000;

  // Rozet vitrini (kazanılanlar)
  List<_UserBadge> earnedBadges = [];

  String get userId => sb.auth.currentUser!.id;

  // Rozet meta sözlüğü (profil vitrini için)
  // Not: Ana rozet sayfanla aynı key’leri kullan.
  final Map<String, _BadgeMeta> meta = const {
    'daily_goal_completed': _BadgeMeta(
      title: "Günlük Su Ustası",
      desc: "Günlük hedefi ilk kez tamamladın.",
      emoji: "💧",
    ),
    'streak_7_days': _BadgeMeta(
      title: "7 Günlük Seri",
      desc: "7 gün üst üste hedefi tuttur.",
      emoji: "🔥",
    ),
    'habit_7_days': _BadgeMeta(
      title: "Disiplin",
      desc: "7 gün alışkanlık tamamla.",
      emoji: "✅",
    ),
    'night_owl': _BadgeMeta(
      title: "Gece Baykuşu",
      desc: "02:00 sonrası su iç.",
      emoji: "🦉",
    ),
    'early_bird': _BadgeMeta(
      title: "Erken Kuş",
      desc: "06:00’dan önce su iç.",
      emoji: "🐦",
    ),
    'one_shot_1000': _BadgeMeta(
      title: "Tek Yudum Canavar",
      desc: "Tek seferde 1000 ml.",
      emoji: "🧃",
    ),
    'undo_master': _BadgeMeta(
      title: "Döktüm Gitti",
      desc: "Undo ile son kaydı sil.",
      emoji: "😅",
    ),
    'litre_5k': _BadgeMeta(
      title: "5 Litre Efsanesi",
      desc: "Bir günde 5000 ml.",
      emoji: "🦈",
    ),
  };

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => loading = true);
    try {
      await _loadProfile();
      await _loadBadges();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = sb.auth.currentUser;
      email = user?.email ?? "-";

      final row = await sb
          .from('profiles')
          .select('display_name, daily_target_ml')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) {
        await sb.from('profiles').upsert({'user_id': userId}, onConflict: 'user_id');
        displayName = user?.email?.split('@').first ?? "Kullanıcı";
        dailyTargetMl = 2000;
      } else {
        displayName = (row['display_name'] as String?)?.trim().isNotEmpty == true
            ? (row['display_name'] as String)
            : (user?.email?.split('@').first ?? "Kullanıcı");
        dailyTargetMl = (row['daily_target_ml'] as int?) ?? 2000;
      }
    } catch (e) {
      _snack("Profil yüklenemedi: $e");
    }
  }

  Future<void> _loadBadges() async {
    try {
      final data = await sb
          .from('user_badges')
          .select('badge_key, earned_at')
          .eq('user_id', userId)
          .order('earned_at', ascending: false)
          .limit(12);

      earnedBadges = (data as List).map((e) {
        return _UserBadge(
          badgeKey: e['badge_key'] as String,
          earnedAt: DateTime.parse(e['earned_at'] as String).toLocal(),
        );
      }).toList();
    } catch (e) {
      // Rozet yoksa/erişim yoksa UI çökmeyecek.
      earnedBadges = [];
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
      _snack("Günlük hedef güncellendi ✅");
    } catch (e) {
      _snack("Hedef güncellenemedi: $e");
    }
  }

  Future<void> _editName() async {
    final ctrl = TextEditingController(text: displayName);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ad / Görünen İsim"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: "Örn: Yasin",
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          FilledButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );

    if (name == null) return;

    try {
      await sb.from('profiles').upsert(
        {'user_id': userId, 'display_name': name},
        onConflict: 'user_id',
      );
      setState(() => displayName = name.isEmpty ? displayName : name);
      _snack("İsim güncellendi ✅");
    } catch (e) {
      _snack("İsim güncellenemedi: $e");
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
    final themeMode = ref.watch(themeModeProvider);

    final initials = (displayName.trim().isNotEmpty ? displayName.trim()[0] : "U").toUpperCase();

    // Son kazanılan rozet (varsa)
    final last = earnedBadges.isNotEmpty ? earnedBadges.first : null;
    final lastMeta = last == null ? null : meta[last.badgeKey];

    return Scaffold(
      appBar: AppBar(title: const Text("Profil"), centerTitle: true),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Üst Profil Kartı
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: theme.colorScheme.primaryContainer,
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          color: Colors.black.withOpacity(0.08),
                        )
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: theme.colorScheme.onPrimaryContainer.withOpacity(.10),
                            child: Text(
                              initials,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onPrimaryContainer.withOpacity(.75),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    SizedBox(
                                      height: 40,
                                      child: FilledButton.icon(
                                        onPressed: () => context.push('/dashboard'),
                                        icon: const Icon(Icons.analytics_outlined),
                                        label: const Text("Dashboard"),
                                      ),
                                    ),
                                    SizedBox(
                                      height: 40,
                                      child: OutlinedButton.icon(
                                        onPressed: _editName,
                                        icon: const Icon(Icons.edit),
                                        label: const Text("Düzenle"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Rozet vitrini
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.emoji_events_outlined),
                              const SizedBox(width: 8),
                              Text(
                                "Rozet Vitrini",
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: theme.colorScheme.surface,
                                  border: Border.all(color: theme.colorScheme.outlineVariant),
                                ),
                                child: Text(
                                  "${earnedBadges.length} kazanıldı",
                                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          if (last != null && lastMeta != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: theme.colorScheme.outlineVariant),
                                color: theme.colorScheme.surface,
                              ),
                              child: Row(
                                children: [
                                  _StickerCircle(
                                    emoji: lastMeta.emoji,
                                    filled: true,
                                    big: true,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Son rozet: ${lastMeta.title}",
                                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          lastMeta.desc,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurface.withOpacity(.75),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Text(
                              "Henüz rozet kazanmadın. Hedefi tamamlayınca ilk rozet düşer 🙂",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(.7),
                              ),
                            ),

                          const SizedBox(height: 12),

                          if (earnedBadges.isNotEmpty)
                            SizedBox(
                              height: 86,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: earnedBadges.length.clamp(0, 10),
                                separatorBuilder: (_, __) => const SizedBox(width: 10),
                                itemBuilder: (context, i) {
                                  final b = earnedBadges[i];
                                  final m = meta[b.badgeKey];
                                  final title = m?.title ?? b.badgeKey;
                                  final emoji = m?.emoji ?? "🏆";
                                  return _StickerCard(
                                    emoji: emoji,
                                    title: title,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Ayarlar kartı
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.flag_outlined),
                          title: const Text("Günlük Hedef (ml)"),
                          subtitle: Text("$dailyTargetMl ml"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _editTarget,
                        ),
                        const Divider(height: 0),
                        ListTile(
                          leading: const Icon(Icons.palette_outlined),
                          title: const Text("Tema"),
                          subtitle: Text(
                            themeMode == ThemeMode.system
                                ? "Sistem"
                                : themeMode == ThemeMode.dark
                                    ? "Koyu"
                                    : "Açık",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            final selected = await showModalBottomSheet<ThemeMode>(
                              context: context,
                              showDragHandle: true,
                              builder: (context) => _ThemeSheet(current: themeMode),
                            );
                            if (selected != null) {
                              ref.read(themeModeProvider.notifier).setMode(selected);
                              _snack("Tema güncellendi ✅");
                            }
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Çıkış
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await sb.auth.signOut();
                        if (context.mounted) context.go('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text("Çıkış Yap"),
                    ),
                  ),

                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }
}

class _ThemeSheet extends StatelessWidget {
  final ThemeMode current;

  const _ThemeSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Tema Seç",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 10),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            title: const Text("Sistem"),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            title: const Text("Koyu"),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
            title: const Text("Açık"),
          ),
        ],
      ),
    );
  }
}

class _UserBadge {
  final String badgeKey;
  final DateTime earnedAt;

  const _UserBadge({
    required this.badgeKey,
    required this.earnedAt,
  });
}

class _BadgeMeta {
  final String title;
  final String desc;
  final String emoji;

  const _BadgeMeta({
    required this.title,
    required this.desc,
    required this.emoji,
  });
}

class _StickerCard extends StatelessWidget {
  final String emoji;
  final String title;

  const _StickerCard({
    required this.emoji,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          )
        ],
      ),
      child: Row(
        children: [
          _StickerCircle(emoji: emoji, filled: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickerCircle extends StatelessWidget {
  final String emoji;
  final bool filled;
  final bool big;

  const _StickerCircle({
    required this.emoji,
    required this.filled,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = big ? 52.0 : 42.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? theme.colorScheme.primaryContainer : theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: TextStyle(fontSize: big ? 22 : 18),
      ),
    );
  }
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
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
