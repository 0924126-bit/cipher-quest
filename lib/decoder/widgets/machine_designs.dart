import 'package:flutter/material.dart';

/// Structural type of the cipher machine.
///
/// Unlike the old presets (same silhouette, different colors), each style
/// is drawn by a completely different CustomPainter with its own shape,
/// mechanics and animation.
enum MachineStyle {
  /// Antique typewriter on a wooden crate - the Identity V reference look.
  typewriter,

  /// Enigma-style rotor cipher box: open lid, 3 rotors, lamp board, plugs.
  rotor,

  /// Telegraph station: morse key, spark coils and punched paper tape.
  telegraph,

  /// Steampunk gear engine: meshing gears, pressure gauge, steam pipes.
  gearwork,

  /// Astronomical clock cabinet: swinging pendulum and star-chart dial.
  horologe,
}

/// Visual design definition for one machine style.
///
/// [style] decides the painter (the whole silhouette); the color fields
/// are that painter's material palette.
///
/// Keep the keys in sync with server/store.py VALID_DESIGNS.
class MachineDesign {
  /// Stable key stored on the server (e.g. "classic").
  final String key;

  /// Which painter draws this machine.
  final MachineStyle style;

  /// Japanese display name for the dashboard.
  final String label;

  /// Short description shown in the design picker.
  final String description;

  // ---- generic palette (interpreted by each painter) ----
  /// Main body / chassis color.
  final Color base;

  /// Darker shade (shadowed faces).
  final Color baseDark;

  /// Lighter shade (top highlights).
  final Color baseLight;

  /// Metal trim / dial / mechanical accent.
  final Color accent;

  /// Darker accent (recesses in the metalwork).
  final Color accentDark;

  /// Paper / tape sheet color.
  final Color paper;

  /// Ink on the paper (typed cipher, progress marks).
  final Color ink;

  /// Indicator lamp while decoding.
  final Color lampActive;

  /// Indicator lamp when completed.
  final Color lampDone;

  /// Wooden stand / crate / desk color.
  final Color wood;

  /// Dark wood edges / braces.
  final Color woodDark;

  const MachineDesign({
    required this.key,
    required this.style,
    required this.label,
    required this.description,
    required this.base,
    required this.baseDark,
    required this.baseLight,
    required this.accent,
    required this.accentDark,
    required this.paper,
    required this.ink,
    required this.lampActive,
    required this.lampDone,
    required this.wood,
    required this.woodDark,
  });
}

/// The 5 selectable machines. Order defines display order in the picker.
const List<MachineDesign> kMachineDesigns = [
  // 1. Reference image look: black iron typewriter on a dark oak crate.
  MachineDesign(
    key: 'classic',
    style: MachineStyle.typewriter,
    label: 'タイプライター',
    description: '黒鉄のアンティークタイプライター。定番の暗号機。',
    base: Color(0xFF35322E),
    baseDark: Color(0xFF211F1C),
    baseLight: Color(0xFF4C4842),
    accent: Color(0xFF8A8378),
    accentDark: Color(0xFF171614),
    paper: Color(0xFFE8E2D0),
    ink: Color(0xFF3A3630),
    lampActive: Color(0xFFD9A441),
    lampDone: Color(0xFF7FB069),
    wood: Color(0xFF4A3C2E),
    woodDark: Color(0xFF32281D),
  ),

  // 2. Enigma-style rotor box: navy steel in a walnut case, brass rotors.
  MachineDesign(
    key: 'rotor',
    style: MachineStyle.rotor,
    label: 'ローターマシン',
    description: '3連ローターが回る、エニグマ式の回転暗号機。',
    base: Color(0xFF2E3440),
    baseDark: Color(0xFF1C2129),
    baseLight: Color(0xFF434C5E),
    accent: Color(0xFFC8A35A),
    accentDark: Color(0xFF6E5526),
    paper: Color(0xFFEDE7D4),
    ink: Color(0xFF2C3542),
    lampActive: Color(0xFFE8C05C),
    lampDone: Color(0xFF8DBB74),
    wood: Color(0xFF5C4630),
    woodDark: Color(0xFF3E2F1F),
  ),

  // 3. Telegraph station: warm walnut desk, brass key, copper coils.
  MachineDesign(
    key: 'telegraph',
    style: MachineStyle.telegraph,
    label: '電信機',
    description: 'モールス電鍵と紙テープ。火花散る旧式電信機。',
    base: Color(0xFF4E3A28),
    baseDark: Color(0xFF332518),
    baseLight: Color(0xFF6B503A),
    accent: Color(0xFFB98A4A),
    accentDark: Color(0xFF5E4726),
    paper: Color(0xFFF0EAD8),
    ink: Color(0xFF4A3222),
    lampActive: Color(0xFFE0B054),
    lampDone: Color(0xFF86A65C),
    wood: Color(0xFF6B4B33),
    woodDark: Color(0xFF4A3220),
  ),

  // 4. Steampunk gear engine: bronze gears in an iron frame, steam pipes.
  MachineDesign(
    key: 'gearwork',
    style: MachineStyle.gearwork,
    label: '歯車機関',
    description: '巨大な歯車が噛み合う蒸気仕掛けの解読機関。',
    base: Color(0xFF3A3633),
    baseDark: Color(0xFF242220),
    baseLight: Color(0xFF524D48),
    accent: Color(0xFFA87838),
    accentDark: Color(0xFF6B4A20),
    paper: Color(0xFFEAE2CC),
    ink: Color(0xFF5A4630),
    lampActive: Color(0xFFE8A03C),
    lampDone: Color(0xFF9CBC6E),
    wood: Color(0xFF443528),
    woodDark: Color(0xFF2E2318),
  ),

  // 5. Astronomical clock: ebony cabinet, gold star dial, pale pendulum.
  MachineDesign(
    key: 'horologe',
    style: MachineStyle.horologe,
    label: '天文時計',
    description: '振り子が時を刻む、星図盤付きの天文時計。',
    base: Color(0xFF2B2430),
    baseDark: Color(0xFF191521),
    baseLight: Color(0xFF3F3548),
    accent: Color(0xFFC9B458),
    accentDark: Color(0xFF6E6230),
    paper: Color(0xFFEDEDE4),
    ink: Color(0xFF3E3850),
    lampActive: Color(0xFFB8A8E0),
    lampDone: Color(0xFF9CB894),
    wood: Color(0xFF3A2E3E),
    woodDark: Color(0xFF261E2A),
  ),
];

/// Legacy keys from the old color-swap presets -> new structural designs.
/// Machines created before the redesign keep working without data loss.
const Map<String, String> kLegacyDesignKeys = {
  'mahogany': 'rotor',
  'military': 'telegraph',
  'brass': 'gearwork',
  'noir': 'horologe',
};

/// Look up a design by key; legacy keys are migrated, unknown keys fall
/// back to the first design (classic typewriter).
MachineDesign machineDesignByKey(String key) {
  final resolved = kLegacyDesignKeys[key] ?? key;
  for (final d in kMachineDesigns) {
    if (d.key == resolved) return d;
  }
  return kMachineDesigns.first;
}
