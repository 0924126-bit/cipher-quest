import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'decoder_controller.dart';
import 'widgets/atmosphere.dart';
import 'widgets/cipher_machine.dart';
import 'widgets/overlays.dart';
import 'widgets/skill_check_widget.dart';

/// Full-screen decoder page. Sized for PC displays but works on mobile.
///
/// Interaction:
///  - Hold mouse / touch on the machine  => decode
///  - SPACE key or tap during skill check => QTE hit
class DecoderPage extends StatefulWidget {
  final String machineId;
  const DecoderPage({super.key, required this.machineId});

  @override
  State<DecoderPage> createState() => _DecoderPageState();
}

class _DecoderPageState extends State<DecoderPage> {
  late final DecoderController _ctrl;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = DecoderController(widget.machineId);
    _ctrl.connect();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onKey(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.space) {
      _ctrl.hitSkillCheck();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.decoder(),
      child: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          backgroundColor: AppColors.bg,
          body: AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              switch (_ctrl.phase) {
                case DecoderPhase.connecting:
                  return const _MessageView(
                    icon: Icons.sync,
                    title: '接続中...',
                    subtitle: '荘園のサーバーに接続しています',
                    spin: true,
                  );
                case DecoderPhase.locked:
                  return const _MessageView(
                    icon: Icons.lock,
                    title: 'この暗号機は使用中です',
                    subtitle: '他の画面でこの暗号機が開かれています。\n1台の暗号機は同時に1画面しか開けません。',
                  );
                case DecoderPhase.notFound:
                  return const _MessageView(
                    icon: Icons.help_outline,
                    title: '暗号機が見つかりません',
                    subtitle: 'この暗号機は撤去されたか、URLが間違っています。',
                  );
                case DecoderPhase.deleted:
                  return const _MessageView(
                    icon: Icons.delete_outline,
                    title: '暗号機が撤去されました',
                    subtitle: '運営によりこの暗号機は撤去されました。',
                  );
                case DecoderPhase.ready:
                  return _buildGame(context);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGame(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final machineSize = (size.shortestSide * 0.62).clamp(280.0, 560.0);

    return GestureDetector(
      // tap anywhere = skill check hit (when active)
      onTapDown: (_) {
        if (_ctrl.skill != null) _ctrl.hitSkillCheck();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          AtmosphereBackground(intense: _ctrl.holding),

          // ---- header ----
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _ctrl.machine?.name ?? '',
                      style: TextStyle(
                        fontSize: 30,
                        letterSpacing: 8,
                        fontWeight: FontWeight.w600,
                        color: AppColors.bone,
                        shadows: [
                          Shadow(
                            color: AppColors.cyan.withValues(alpha: 0.5),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CIPHER MACHINE',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 6,
                        color: AppColors.boneDim.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ---- machine (hold target) ----
          Center(
            child: Listener(
              onPointerDown: (_) {
                if (_ctrl.skill != null) {
                  _ctrl.hitSkillCheck();
                } else {
                  _ctrl.startHold();
                }
              },
              onPointerUp: (_) => _ctrl.endHold(),
              onPointerCancel: (_) => _ctrl.endHold(),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedScale(
                  scale: _ctrl.holding ? 1.03 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  child: SizedBox(
                    width: machineSize,
                    height: machineSize,
                    child: CipherMachine(
                      progress: _ctrl.progress,
                      holding: _ctrl.holding,
                      completed: _ctrl.completed,
                      sparkActive: _ctrl.sparkActive,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ---- progress % ----
          IgnorePointer(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_ctrl.progress.floor()}',
                    style: TextStyle(
                      fontSize: machineSize * 0.16,
                      fontWeight: FontWeight.bold,
                      height: 1,
                      color: _ctrl.completed
                          ? AppColors.amber
                          : Colors.white.withValues(alpha: 0.92),
                      shadows: [
                        Shadow(
                          color: (_ctrl.completed
                                  ? AppColors.amber
                                  : AppColors.cyan)
                              .withValues(alpha: 0.7),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: machineSize * 0.045,
                      color: AppColors.boneDim,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---- skill check ----
          if (_ctrl.skill != null && !_ctrl.skill!.resolved)
            Align(
              alignment: const Alignment(0, -0.55),
              child: SkillCheckWidget(skill: _ctrl.skill!),
            ),

          // ---- footer hint ----
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: AnimatedOpacity(
                  opacity: _ctrl.completed ? 0 : 1,
                  duration: const Duration(milliseconds: 400),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_ctrl.sparkActive)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text(
                            '⚡ 火花ブースト発動中！解読速度アップ ⚡',
                            style: TextStyle(
                              color: AppColors.violet,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      Text(
                        _ctrl.holding
                            ? '解読中... 針が白いゾーンに入ったら SPACE / タップ！'
                            : '暗号機を長押しして解読せよ',
                        style: TextStyle(
                          color: AppColors.bone.withValues(alpha: 0.75),
                          fontSize: 15,
                          letterSpacing: 3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _StatsRow(ctrl: _ctrl),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ---- perfect flash ----
          if (_ctrl.perfectFlash)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Align(
                  alignment: Alignment(0, -0.3),
                  child: Text(
                    'PERFECT!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                ),
              ),
            ),

          // ---- shock overlay ----
          if (_ctrl.shockActive) const ShockOverlay(),

          // ---- completed overlay ----
          if (_ctrl.completed)
            CompletedOverlay(machineName: _ctrl.machine?.name ?? ''),
        ],
      ),
    );
  }
}

/// Bottom stats: combo / success / miss.
class _StatsRow extends StatelessWidget {
  final DecoderController ctrl;
  const _StatsRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color c) => TextStyle(
          color: c.withValues(alpha: 0.85),
          fontSize: 12,
          letterSpacing: 1.5,
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('COMBO ${ctrl.comboSuccess}', style: style(AppColors.cyan)),
        const SizedBox(width: 18),
        Text('成功 ${ctrl.skillSuccessCount}', style: style(AppColors.amber)),
        const SizedBox(width: 18),
        Text('失敗 ${ctrl.skillMissCount}', style: style(AppColors.blood)),
      ],
    );
  }
}

/// Simple centered message screen for lock / error states.
class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool spin;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.spin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const AtmosphereBackground(),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              spin
                  ? const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: AppColors.cyan,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Icon(icon,
                      size: 64,
                      color: AppColors.blood.withValues(alpha: 0.9)),
              const SizedBox(height: 28),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  color: AppColors.bone,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: AppColors.boneDim.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
