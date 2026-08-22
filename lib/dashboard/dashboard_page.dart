import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/machine.dart';
import '../theme/app_theme.dart';
import 'dashboard_controller.dart';
import 'game_panel.dart';
import 'widgets/dialogs.dart';
import 'widgets/machine_card.dart';
import 'widgets/role_panel.dart';
import 'widgets/sound_panel.dart';

/// 運営本部ダッシュボード。
///
/// 洞窟の指令室をイメージした暗色UI。上から
///   1. 全体状況 (稼働数・進捗)
///   2. 暗号機の管理
///   3. ロールページ (チェイサー / 呪術師 / ハンター)
///   4. サウンド
///   5. 3Dゲーム
///   6. 記録 (アクティビティ)
/// の順に、当日の運営作業の頻度が高いものから並べている。
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = DashboardController()..init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _addMachine() async {
    final result = await showMachineFormDialog(context);
    if (result == null) return;
    await _ctrl.createMachine(
      result.name,
      result.durationSec,
      design: result.design,
    );
    final created = _ctrl.machines.isEmpty ? null : _ctrl.machines.last;
    if (created != null) {
      await _ctrl.updateMachine(
        created.id,
        skillEnabled: result.skillEnabled,
        skillDifficulty: result.skillDifficulty,
        skillSuccessBonus: result.skillSuccessBonus,
        skillFailPenalty: result.skillFailPenalty,
      );
    }
  }

  Future<void> _editMachine(Machine m) async {
    final result = await showMachineFormDialog(context, existing: m);
    if (result == null) return;
    await _ctrl.updateMachine(
      m.id,
      name: result.name,
      durationSec: result.durationSec,
      design: result.design,
      skillEnabled: result.skillEnabled,
      skillDifficulty: result.skillDifficulty,
      skillSuccessBonus: result.skillSuccessBonus,
      skillFailPenalty: result.skillFailPenalty,
    );
  }

  Future<void> _deleteMachine(Machine m) async {
    final ok = await showDeleteConfirmDialog(context, machine: m);
    if (ok) await _ctrl.deleteMachine(m.id);
  }

  void _showQr(Machine m) {
    showQrDialog(context, machine: m, url: _ctrl.machineUrl(m.id));
  }

  void _openMachine(Machine m) {
    Navigator.of(context).pushNamed('/machine/${m.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dashboard(),
      child: Scaffold(
        backgroundColor: AppColors.dashBg,
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                // ---- 帯ヘッダー ----
                SliverAppBar(
                  pinned: true,
                  toolbarHeight: 60,
                  title: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.dashSurfaceHi,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.dashAmber),
                        ),
                        child: const Icon(Icons.memory,
                            color: AppColors.dashAmber, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Cipher Quest',
                        style: GoogleFonts.shipporiMincho(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.dashLine),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          '運営本部',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.dashGrey,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    _ConnBadge(connected: _ctrl.connected),
                    const SizedBox(width: 16),
                  ],
                ),

                // ---- 通知音の有効化バナー ----
                if (!_ctrl.curseSoundArmed)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _SoundArmBanner(
                          onArm: () => _ctrl.armCurseSound()),
                    ),
                  ),

                // ---- 呪い発動の速報 ----
                if (_ctrl.curseEvents.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _CurseBanner(ev: _ctrl.curseEvents.first),
                    ),
                  ),

                // ---- 1. 全体状況 ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                          label: '全体状況',
                          note: '暗号機の稼働と解読の進み具合',
                        ),
                        const SizedBox(height: 10),
                        _StatsHeader(ctrl: _ctrl),
                      ],
                    ),
                  ),
                ),

                // ---- 全解読完了バナー ----
                if (_ctrl.allCompleted && _ctrl.machines.isNotEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: _AllCompletedBanner(),
                    ),
                  ),

                // ---- 2. 暗号機 ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _SectionHeader(
                      label: '暗号機の管理',
                      note: 'QRを設置端末で読み取ると解読ページが開く',
                      action: OutlinedButton.icon(
                        onPressed: _addMachine,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('追加',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ),
                ),
                if (_ctrl.loading)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.dashAmber, strokeWidth: 2.5),
                      ),
                    ),
                  )
                else if (_ctrl.machines.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: _EmptyState(onAdd: _addMachine),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.crossAxisExtent;
                        final cols = w > 1200
                            ? 4
                            : w > 850
                                ? 3
                                : w > 560
                                    ? 2
                                    : 1;
                        return SliverGrid(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: cols,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: 240,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final m = _ctrl.machines[i];
                              return MachineCard(
                                key: ValueKey(m.id),
                                machine: m,
                                onQr: () => _showQr(m),
                                onEdit: () => _editMachine(m),
                                onReset: () => _ctrl.resetMachine(m.id),
                                onDelete: () => _deleteMachine(m),
                                onOpen: () => _openMachine(m),
                                onSpeedNudge: (d) =>
                                    _ctrl.nudgeSpeed(m.id, d),
                                onSpeedReset: () => _ctrl.resetSpeed(m.id),
                              );
                            },
                            childCount: _ctrl.machines.length,
                          ),
                        );
                      },
                    ),
                  ),

                // ---- 3. ロールページ ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                          label: 'ロールページ',
                          note: 'チェイサーの警報・呪術師の呪い・ハンター端末',
                        ),
                        const SizedBox(height: 10),
                        RolePanel(ctrl: _ctrl),
                      ],
                    ),
                  ),
                ),

                // ---- 4. サウンド ----
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(
                          label: 'サウンド',
                          note: '解読音・完了音などのmp3を差し替えられる',
                        ),
                        const SizedBox(height: 10),
                        SoundPanel(ctrl: _ctrl),
                      ],
                    ),
                  ),
                ),

                // ---- 5. 3Dゲーム ----
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 28, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          label: '3Dゲーム',
                          note: '追加コンテンツの管理',
                        ),
                        SizedBox(height: 10),
                        GamePanel(),
                      ],
                    ),
                  ),
                ),

                // ---- 6. 記録 ----
                if (_ctrl.events.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(
                            label: '記録',
                            note: '接続・解読・スキルチェックなどの履歴',
                          ),
                          const SizedBox(height: 10),
                          _EventFeed(events: _ctrl.events),
                        ],
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                      child: SizedBox(height: 48)),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ---------- セクション見出し (縦ライン+ラベル) ----------
class _SectionHeader extends StatelessWidget {
  final String label;
  final String note;
  final Widget? action;
  const _SectionHeader({
    required this.label,
    required this.note,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.dashAmber,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.shipporiMincho(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.dashGrey),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

/// ---------- 通知音の有効化バナー ----------
class _SoundArmBanner extends StatelessWidget {
  final VoidCallback onArm;
  const _SoundArmBanner({required this.onArm});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onArm,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.dashAmber.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.dashAmber.withValues(alpha: 0.4)),
        ),
        child: const Row(
          children: [
            Icon(Icons.volume_up, size: 18, color: AppColors.dashAmber),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'ここをクリックすると、呪い発動時に通知音が鳴るようになります',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 18, color: AppColors.dashGrey),
          ],
        ),
      ),
    );
  }
}

/// ---------- 呪い発動速報 ----------
class _CurseBanner extends StatelessWidget {
  final dynamic ev; // CurseEvent
  const _CurseBanner({required this.ev});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ev.atMs as int);
    two(int n) => n.toString().padLeft(2, '0');
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dashCurse.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: AppColors.dashCurse.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_fix_high,
              size: 18, color: AppColors.dashCurse),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              ev.message as String,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}',
            style: const TextStyle(
                fontSize: 11.5, color: AppColors.dashGrey),
          ),
        ],
      ),
    );
  }
}

/// ---------- 全体状況 ----------
class _StatsHeader extends StatelessWidget {
  final DashboardController ctrl;
  const _StatsHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 640;
            final stats = [
              _StatItem(
                label: '設置台数',
                value: '${ctrl.machines.length}',
                unit: '台',
                color: AppColors.dashInk,
              ),
              _StatItem(
                label: '稼働中',
                value: '${ctrl.onlineCount}',
                unit: '台',
                color: AppColors.dashGreen,
              ),
              _StatItem(
                label: '解読完了',
                value: '${ctrl.completedCount}',
                unit: '台',
                color: AppColors.dashAmber,
              ),
            ];
            final progress = _OverallProgress(value: ctrl.overallProgress);

            if (narrow) {
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: stats,
                  ),
                  const SizedBox(height: 18),
                  progress,
                ],
              );
            }
            return Row(
              children: [
                ...stats.expand((s) => [s, const SizedBox(width: 44)]),
                Expanded(child: progress),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.dashGrey),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: GoogleFonts.shipporiMincho(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1,
                color: color,
              ),
            ),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                unit,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.dashGrey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverallProgress extends StatelessWidget {
  final double value; // 0..100
  const _OverallProgress({required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '全体進捗',
              style: TextStyle(fontSize: 12, color: AppColors.dashGrey),
            ),
            const Spacer(),
            TweenAnimationBuilder<double>(
              tween: Tween(end: value),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                '${v.toStringAsFixed(1)}%',
                style: GoogleFonts.shipporiMincho(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashAmber,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(end: value / 100),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: v,
              minHeight: 8,
              backgroundColor: AppColors.dashLine,
              valueColor: const AlwaysStoppedAnimation(AppColors.dashAmber),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---------- 全解読完了バナー ----------
class _AllCompletedBanner extends StatelessWidget {
  const _AllCompletedBanner();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (context, v, child) => Transform.scale(
        scale: 0.95 + v * 0.05,
        child: Opacity(opacity: v.clamp(0, 1), child: child),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.dashGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.dashGreen),
        ),
        child: Row(
          children: [
            const Icon(Icons.celebration,
                color: AppColors.dashGreen, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                '全ての暗号機の解読が完了！ ゲートが開通しました',
                style: GoogleFonts.shipporiMincho(
                  color: AppColors.dashGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------- 空状態 ----------
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppColors.dashSurfaceHi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.dashLine),
            ),
            child: const Icon(Icons.memory,
                size: 40, color: AppColors.dashGrey),
          ),
          const SizedBox(height: 20),
          Text(
            'まだ暗号機がありません',
            style: GoogleFonts.shipporiMincho(
                fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '暗号機を追加して、QRコードを会場の端末で読み取りましょう',
            style: TextStyle(fontSize: 13, color: AppColors.dashGrey),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('最初の暗号機を追加'),
          ),
        ],
      ),
    );
  }
}

/// ---------- 記録 ----------
class _EventFeed extends StatelessWidget {
  final List<MachineEvent> events;
  const _EventFeed({required this.events});

  IconData _icon(String type) {
    switch (type) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'connect':
      case 'connected':
        return Icons.link;
      case 'disconnect':
      case 'disconnected':
        return Icons.link_off;
      case 'created':
        return Icons.add_circle_outline;
      case 'deleted':
        return Icons.delete_outline;
      case 'reset':
        return Icons.restart_alt;
      case 'skill_miss':
        return Icons.flash_on;
      case 'skill_success':
        return Icons.bolt;
      case 'speed':
        return Icons.speed;
      case 'sound':
        return Icons.library_music;
      case 'curse':
        return Icons.auto_fix_high;
      default:
        return Icons.info_outline;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'completed':
      case 'skill_success':
        return AppColors.dashGreen;
      case 'connect':
      case 'connected':
      case 'speed':
      case 'sound':
        return AppColors.dashAmber;
      case 'disconnect':
      case 'disconnected':
      case 'skill_miss':
        return AppColors.dashRed;
      case 'deleted':
        return AppColors.dashRed;
      case 'curse':
        return AppColors.dashCurse;
      default:
        return AppColors.dashGrey;
    }
  }

  String _time(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            for (final e in events.take(14))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    Icon(_icon(e.type), size: 16, color: _color(e.type)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.message,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      _time(e.at),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.dashGrey,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------- 接続バッジ ----------
class _ConnBadge extends StatelessWidget {
  final bool connected;
  const _ConnBadge({required this.connected});

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.dashGreen : AppColors.dashRed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 8),
          Text(
            connected ? '接続中' : '再接続中…',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
