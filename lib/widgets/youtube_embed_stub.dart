import 'package:flutter/widgets.dart';

/// 非WebプラットフォームではYouTube埋め込みは表示しない。
Widget buildYoutubeEmbedImpl(String videoId) => const SizedBox.shrink();
