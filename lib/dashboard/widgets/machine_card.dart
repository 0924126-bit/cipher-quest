import 'package:flutter/material.dart';

import '../../decoder/widgets/machine_designs.dart';
import '../../models/machine.dart';
import '../../theme/app_theme.dart';
import 'dialogs.dart' show MachineThumbnailPainter;

/// Minimal, Google-style card showing one machine's live status with
/// smooth animated progress.
class MachineCard extends StatelessWidget {
  final Machine machine;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  /// Live decode-speed nudges (+/- percent points) and reset to 100%.
  final void Function(double deltaPercent) onSpeedNudge;
  final VoidCallback onSpeedReset;

  const MachineCard({
    super.key,
    required this.machine,
    required this.onQr,
    required this.onEdit,
    required this.onReset,
    required this.onDelete,
    required this.onOpen,
    required this.onSpeedNudge,
    required this.onSpeedReset,
  });

  Color get _statusColor {
    if (machine.isCompleted) return AppColors.dashGreen;
    if (machine.isDecoding) return AppColors.dashBlue;
    if (machine.status == 'paused') return AppColors.dashAmber;
    return AppColors.dashGrey;
  }

  String get _statusLabel {
    if (machine.isCompleted) return '解読完了';
    if (machine.isDecoding) return '解読中';
    if (machine.status == 'paused') return '一時停止';
    return '待機中';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onQr,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- header row ----
              Row(
                children: [
                  // machine design thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      size: const Size(36, 36),
                      painter: MachineThumbnailPainter(
                        design: machineDesignByKey(machine.design),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ConnectionDot(connected: machine.connected),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      machine.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _MenuButton(
                    onQr: onQr,
                    onEdit: onEdit,
                    onReset: onReset,
                    onDelete: onDelete,
                    onOpen: onOpen,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _StatusChip(color: _statusColor, label: _statusLabel),
                  const SizedBox(width: 8),
                  Text(
                    '解読時間 ${machine.durationSec}秒',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dashGrey,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    machineDesignByKey(machine.design).label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dashGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ---- live speed control ----
              _SpeedControl(
                percent: machine.speedPercent,
                onNudge: onSpeedNudge,
                onReset: onSpeedReset,
              ),
              const SizedBox(height: 10),

              // ---- animated progress ----
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: machine.progress),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '${v.floor()}%',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: _statusColor,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (machine.isCompleted)
                    const Icon(Icons.check_circle,
                        color: AppColors.dashGreen, size: 26),
                ],
              ),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(end: machine.progress / 100),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: v,
                    minHeight: 8,
                    backgroundColor: AppColors.dashLine,
                    valueColor: AlwaysStoppedAnimation(_statusColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline decode-speed control: -10% / percent label / +10% (tap % to reset).
class _SpeedControl extends StatelessWidget {
  final int percent;
  final void Function(double deltaPercent) onNudge;
  final VoidCallback onReset;

  const _SpeedControl({
    required this.percent,
    required this.onNudge,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final abnormal = percent != 100;
    final color = percent > 100
        ? AppColors.dashGreen
        : percent < 100
            ? AppColors.dashRed
            : AppColors.dashGrey;
    return Row(
      children: [
        const Icon(Icons.speed, size: 15, color: AppColors.dashGrey),
        const SizedBox(width: 6),
        const Text(
          '解読速度',
          style: TextStyle(fontSize: 12, color: AppColors.dashGrey),
        ),
        const Spacer(),
        _NudgeButton(
          icon: Icons.remove,
          tooltip: '-10%',
          onTap: () => onNudge(-10),
        ),
        GestureDetector(
          onTap: abnormal ? onReset : null,
          child: Tooltip(
            message: abnormal ? 'タップで100%に戻す' : '標準速度',
            child: Container(
              width: 56,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 3),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: abnormal ? 0.1 : 0.0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
        ),
        _NudgeButton(
          icon: Icons.add,
          tooltip: '+10%',
          onTap: () => onNudge(10),
        ),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _NudgeButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30,
          height: 26,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.dashLine),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: AppColors.dashInk),
        ),
      ),
    );
  }
}

/// Pulsing green dot when online; grey when offline.
class _ConnectionDot extends StatefulWidget {
  final bool connected;
  const _ConnectionDot({required this.connected});

  @override
  State<_ConnectionDot> createState() => _ConnectionDotState();
}

class _ConnectionDotState extends State<_ConnectionDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.connected) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFBDC1C6),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final v = _pulse.value;
        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 14 * (0.5 + v * 0.5),
                height: 14 * (0.5 + v * 0.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.dashGreen.withValues(alpha: 0.35 * (1 - v)),
                ),
              ),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.dashGreen,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _MenuButton({
    required this.onQr,
    required this.onEdit,
    required this.onReset,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: AppColors.dashGrey, size: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      onSelected: (v) {
        switch (v) {
          case 'qr':
            onQr();
          case 'open':
            onOpen();
          case 'edit':
            onEdit();
          case 'reset':
            onReset();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (context) => [
        _item('qr', Icons.qr_code_2, 'QRコード / URL'),
        _item('open', Icons.open_in_new, '解読ページを開く'),
        _item('edit', Icons.tune, '設定を変更'),
        _item('reset', Icons.restart_alt, '進捗をリセット'),
        const PopupMenuDivider(),
        _item('delete', Icons.delete_outline, '暗号機を撤去',
            color: AppColors.dashRed),
      ],
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label,
      {Color? color}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 19, color: color ?? AppColors.dashGrey),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(fontSize: 14, color: color ?? AppColors.dashInk)),
        ],
      ),
    );
  }
}
