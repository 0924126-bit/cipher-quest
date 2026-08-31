import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/url_open.dart'
    if (dart.library.js_interop) '../services/url_open_web.dart';

/// Staff tool: paste a YouTube URL and get an mp4 download link.
/// Behind the site password gate (/ytdl). The worker proxies the
/// request to public cobalt instances with a YouTube-only allowlist.
class YtdlPage extends StatefulWidget {
  const YtdlPage({super.key});

  @override
  State<YtdlPage> createState() => _YtdlPageState();
}

class _YtdlPageState extends State<YtdlPage> {
  static const _accent = Color(0xFF1A73E8);
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);

  final _urlCtrl = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _resultUrl;
  String? _resultName;

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _resultUrl = null;
      _resultName = null;
    });
    try {
      final data = await ApiService.instance.resolveYoutube(url);
      if (!mounted) return;
      final dl = data['url'] as String?;
      if (dl == null || dl.isEmpty) {
        setState(() {
          _busy = false;
          _error = (data['detail'] as String?) ?? '変換に失敗しました';
        });
        return;
      }
      setState(() {
        _busy = false;
        _resultUrl = dl;
        _resultName = (data['filename'] as String?) ?? 'video.mp4';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = '変換に失敗しました。URLを確認するか、時間をおいて再試行してください。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        title: const Text(
          'YouTube → mp4',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: _sub),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'YouTubeのURLを貼り付けると、mp4のダウンロードリンクを取得します。',
                  style: TextStyle(fontSize: 13, color: _sub, height: 1.6),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _urlCtrl,
                  enabled: !_busy,
                  onSubmitted: (_) => _resolve(),
                  style: const TextStyle(fontSize: 14, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'https://www.youtube.com/watch?v=...',
                    hintStyle: const TextStyle(fontSize: 13.5, color: _sub),
                    prefixIcon: const Icon(Icons.link_rounded,
                        color: _sub, size: 20),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _line),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _accent, width: 1.4),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _line),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _busy ? null : _resolve,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('mp4リンクを取得',
                            style: TextStyle(fontSize: 14)),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style:
                        const TextStyle(fontSize: 12.5, color: Color(0xFFD93025)),
                  ),
                  const SizedBox(height: 10),
                  // 自動変換が全滅している時の手動フォールバック
                  OutlinedButton.icon(
                    onPressed: () {
                      final u = Uri.encodeComponent(_urlCtrl.text.trim());
                      openUrl('https://cobalt.tools/?u=$u');
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text(
                      'cobalt.tools で手動変換（新しいタブ）',
                      style: TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accent,
                      side: const BorderSide(color: _line),
                    ),
                  ),
                ],
                if (_resultUrl != null) ...[
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: _line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.movie_outlined,
                                color: _accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _resultName ?? 'video.mp4',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    color: _ink,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: _resultUrl!));
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('リンクをコピーしました')),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('コピー',
                                    style: TextStyle(fontSize: 13)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _accent,
                                  side: const BorderSide(color: _line),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: () => openUrl(_resultUrl!),
                                icon: const Icon(Icons.download_rounded,
                                    size: 16),
                                label: const Text('開く / 保存',
                                    style: TextStyle(fontSize: 13)),
                                style: FilledButton.styleFrom(
                                    backgroundColor: _accent),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'リンクは一時的なものです。すぐに保存してください。',
                          style: TextStyle(fontSize: 11.5, color: _sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
