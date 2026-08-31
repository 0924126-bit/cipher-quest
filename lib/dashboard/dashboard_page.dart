import 'package:flutter/material.dart';

import '../models/machine.dart';
import '../theme/app_theme.dart';
import 'dashboard_controller.dart';
import 'game_panel.dart';
import 'widgets/dialogs.dart';
import 'widgets/machine_card.dart';
import 'widgets/quick_actions_panel.dart';
import 'widgets/role_panel.dart';
import 'widgets/sound_panel.dart';
import 'widgets/ticket_panel.dart';

/// 運営ダッシュボード。
///
/// 白基調の日本の業務システム風UI。
/// 最上部にクイック操作(全体リセット/警報再許可)を配置。
/// 上部固定バーからセクションへワンタップで移動できる導線:
///   概況 / 暗号機 / ロール / サウンド / ゲーム
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final DashboardController _ctrl;
  final _scroll = ScrollController();

  // section anchors
  final _keyStats = GlobalKey();
  final _keyMachines = GlobalKey();
  final _keyRoles = GlobalKey();
  final _keySounds = GlobalKey();
  final _keyTickets = GlobalKey();
  final _keyGame = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ctrl = DashboardController()..init();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
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
            return Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 16, 20, 48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ---- notice banners ----
                              if (!_ctrl.curseSoundArmed)
                                _SoundArmBanner(
                                    onArm: () => _ctrl.armCurseSound()),
                              if (_ctrl.curseEvents.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _CurseBanner(ev: _ctrl.curseEvents.first),
                              ],
                              if (_ctrl.allCompleted &&
                                  _ctrl.machines.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                const _AllCompletedBanner(),
                              ],

                              // ---- 0. クイック操作(よく使うボタン) ----
                              const SizedBox(height: 10),
                              QuickActionsPanel(ctrl: _ctrl),

                              // ---- 1. 概況 ----
                              _section(
                                key: _keyStats,
                                title: '概況',
                                sub: '暗号機の稼働と全体の進み具合',
                                child: _StatsHeader(ctrl: _ctrl),
                              ),

                              // ---- 2. 暗号機 ----
                              _section(
                                key: _keyMachines,
                                title: '暗号機',
                                sub: 'QRコードを設置端末で読み取ると解読ページが開きます',
                                action: ElevatedButton.icon(
                                  onPressed: _addMachine,
                                  icon: const Icon(Icons.add, size: 17),
                                  label: const Text('暗号機を追加'),
                                ),
                                child: _machinesArea(),
                              ),

                              // ---- 3. ロール ----
                              _section(
                                key: _keyRoles,
                                title: 'ロールページ',
                                sub: 'チェイサーの警報・呪術師の呪い・ハンター通知端末の設定',
                                child: RolePanel(ctrl: _ctrl),
                              ),

                              // ---- 4. サウンド ----
                              _section(
                                key: _keySounds,
                                title: 'サウンド',
                                sub: '解読音・完了音などのmp3を差し替えられます',
                                child: SoundPanel(ctrl: _ctrl),
                              ),

                              // ---- 5. 整理券 ----
                              _section(
                                key: _keyTickets,
                                title: '整理券',
                                sub: 'オンライン整理券の発行・呼出・チャット・設定（紙券も登録可）',
                                child: TicketPanel(ctrl: _ctrl),
                              ),

                              // ---- 5. ゲーム ----
                              _section(
                                key: _keyGame,
                                title: '3Dゲーム',
                                sub: '追加コンテンツの管理',
                                child: const GamePanel(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- top bar with section nav ----------
  Widget _topBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.dashLine)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // brand
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/images/identity_e_logo.png',
                  width: 30,
                  height: 30,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Identity E',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '運営管理',
                style:
                    TextStyle(fontSize: 12, color: AppColors.dashGrey),
              ),
              const SizedBox(width: 24),
              // section nav (scrollable on narrow screens)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _navItem('概況', () => _jumpTo(_keyStats)),
                      _navItem('暗号機', () => _jumpTo(_keyMachines)),
                      _navItem('ロール', () => _jumpTo(_keyRoles)),
                      _navItem('サウンド', () => _jumpTo(_keySounds)),
                      _navItem('整理券', () => _jumpTo(_keyTickets)),
                      _navItem('ゲーム', () => _jumpTo(_keyGame)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _ConnBadge(connected: _ctrl.connected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppColors.dashInk,
          ),
        ),
      ),
    );
  }

  // ---------- section scaffold ----------
  Widget _section({
    required GlobalKey key,
    required String title,
    required String sub,
    Widget? action,
    required Widget child,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.dashGrey),
                  ),
                ),
              ),
              if (action != null) action,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ---------- machines area ----------
  Widget _machinesArea() {
    if (_ctrl.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.dashBlue, strokeWidth: 2.5),
        ),
      );
    }
    if (_ctrl.machines.isEmpty) {
      return _EmptyState(onAdd: _addMachine);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w > 1150
            ? 4
            : w > 830
                ? 3
                : w > 550
                    ? 2
                    : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            mainAxisExtent: 240,
          ),
          itemCount: _ctrl.machines.length,
          itemBuilder: (context, i) {
            final m = _ctrl.machines[i];
            return MachineCard(
              key: ValueKey(m.id),
              machine: m,
              onQr: () => _showQr(m),
              onEdit: () => _editMachine(m),
              onReset: () => _ctrl.resetMachine(m.id),
              onDelete: () => _deleteMachine(m),
              onOpen: () => _openMachine(m),
              onSpeedNudge: (d) => _ctrl.nudgeSpeed(m.id, d),
              onSpeedReset: () => _ctrl.resetSpeed(m.id),
            );
          },
        );
      },
    );
  }
}

/// ---------- 通知音の有効化バナー ----------
class _SoundArmBanner extends StatelessWidget {
  final VoidCallback onArm;
  const _SoundArmBanner({required this.onArm});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onArm,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFEAD9A8)),
          ),
          child: const Row(
            children: [
              Icon(Icons.volume_up,
                  size: 18, color: AppColors.dashAmber),
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
        color: const Color(0xFFF7F0FC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCC8EF)),
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

/// ---------- 概況 ----------
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
                color: AppColors.dashBlue,
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
              style: TextStyle(
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
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dashBlue,
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
              valueColor: const AlwaysStoppedAnimation(AppColors.dashBlue),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF6EE),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFB9E0C6)),
        ),
        child: const Row(
          children: [
            Icon(Icons.celebration, color: AppColors.dashGreen, size: 22),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                '全ての暗号機の解読が完了！ ゲートが開通しました',
                style: TextStyle(
                  color: AppColors.dashGreen,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.dashSurfaceHi,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.memory,
                    size: 36, color: AppColors.dashGrey),
              ),
              const SizedBox(height: 18),
              const Text(
                'まだ暗号機がありません',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                '暗号機を追加して、QRコードを会場の端末で読み取りましょう',
                style: TextStyle(fontSize: 13, color: AppColors.dashGrey),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('最初の暗号機を追加'),
              ),
            ],
          ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 7),
          Text(
            connected ? '接続中' : '再接続中…',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
