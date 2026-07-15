import 'package:flutter/material.dart';

import 'machine_designs.dart';
import 'machines/gearwork_painter.dart';
import 'machines/horologe_painter.dart';
import 'machines/painter_common.dart';
import 'machines/rotor_painter.dart';
import 'machines/telegraph_painter.dart';
import 'machines/typewriter_painter.dart';

/// The cipher machine widget.
///
/// Each [MachineDesign.style] maps to a completely different CustomPainter
/// (typewriter / rotor box / telegraph / gear engine / astronomical clock),
/// so the 5 designs differ in silhouette and mechanics - not just colors.
///
/// Visual states shared by all painters:
///  - idle      : machine at rest, dim lamp
///  - holding   : machine animates (keys, rotors, sparks, gears, pendulum)
///  - completed : green lamp, machine settles
class CipherMachine extends StatefulWidget {
  /// 0..100
  final double progress;
  final bool holding;
  final bool completed;
  final MachineDesign design;

  const CipherMachine({
    super.key,
    required this.progress,
    required this.holding,
    required this.completed,
    required this.design,
  });

  @override
  State<CipherMachine> createState() => _CipherMachineState();
}

class _CipherMachineState extends State<CipherMachine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    // continuous clock driving all machine animations
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// Pick the painter matching the design's structural style.
  MachinePainter _painterFor(double t) {
    final d = widget.design;
    switch (d.style) {
      case MachineStyle.typewriter:
        return TypewriterPainter(
          progress: widget.progress,
          holding: widget.holding,
          completed: widget.completed,
          design: d,
          t: t,
        );
      case MachineStyle.rotor:
        return RotorPainter(
          progress: widget.progress,
          holding: widget.holding,
          completed: widget.completed,
          design: d,
          t: t,
        );
      case MachineStyle.telegraph:
        return TelegraphPainter(
          progress: widget.progress,
          holding: widget.holding,
          completed: widget.completed,
          design: d,
          t: t,
        );
      case MachineStyle.gearwork:
        return GearworkPainter(
          progress: widget.progress,
          holding: widget.holding,
          completed: widget.completed,
          design: d,
          t: t,
        );
      case MachineStyle.horologe:
        return HorologePainter(
          progress: widget.progress,
          holding: widget.holding,
          completed: widget.completed,
          design: d,
          t: t,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return CustomPaint(painter: _painterFor(_anim.value));
      },
    );
  }
}
