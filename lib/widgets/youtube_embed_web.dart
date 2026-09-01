import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final Set<String> _registered = {};

/// YouTube埋め込み（Web実装）。iframeをHtmlElementViewで表示する。
/// Shorts等の縦動画を想定し、呼び出し側でアスペクト比を管理する。
Widget buildYoutubeEmbedImpl(String videoId) {
  final viewType = 'yt-embed-$videoId';
  if (!_registered.contains(viewType)) {
    _registered.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final iframe = web.HTMLIFrameElement()
        ..src = 'https://www.youtube.com/embed/$videoId'
            '?rel=0&modestbranding=1&playsinline=1'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'accelerometer; autoplay; clipboard-write; '
            'encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true;
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}
