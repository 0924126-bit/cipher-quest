import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../services/api_service.dart';

/// Public reviews page (/kutikomi).
///
/// Read-only list of visitor reviews. No authentication required —
/// anyone with the URL can view. Posting is only possible from the
/// ticket page after finishing a game. Staff can disable reviews from
/// the dashboard, in which case this page shows a closed notice.
class KutikomiPage extends StatefulWidget {
  const KutikomiPage({super.key});

  @override
  State<KutikomiPage> createState() => _KutikomiPageState();
}

class _KutikomiPageState extends State<KutikomiPage> {
  static const _accent = Color(0xFF1A73E8);
  static const _ink = Color(0xFF202124);
  static const _sub = Color(0xFF5F6368);
  static const _line = Color(0xFFDADCE0);
  static const _star = Color(0xFFFBBC04);

  List<Review> _reviews = const [];
  bool _enabled = true;
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final (enabled, reviews) = await ApiService.instance.listReviews();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _reviews = reviews;
        _loaded = true;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loaded = true;
        _error = '読み込みに失敗しました';
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
          'Identity E  口コミ',
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: const IconThemeData(color: _sub),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (!_loaded) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.2, color: _accent),
        ),
      );
    }
    if (_error != null) {
      return _notice(Icons.wifi_off_rounded, _error!, retry: true);
    }
    if (!_enabled) {
      return _notice(Icons.rate_review_outlined, '口コミは現在公開されていません');
    }
    if (_reviews.isEmpty) {
      return _notice(Icons.star_border_rounded, 'まだ口コミはありません');
    }

    final avg = _reviews.map((r) => r.stars).reduce((a, b) => a + b) /
        _reviews.length;

    return RefreshIndicator(
      color: _accent,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        avg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w400,
                          color: _ink,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _starRow(avg.round(), size: 20),
                          const SizedBox(height: 2),
                          Text(
                            '${_reviews.length}件の口コミ',
                            style:
                                const TextStyle(fontSize: 12.5, color: _sub),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: _line, height: 1),
                  for (final r in _reviews) _reviewTile(r),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notice(IconData icon, String text, {bool retry = false}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: _line),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(fontSize: 14, color: _sub)),
          if (retry) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: _load,
              child: const Text('再読み込み',
                  style: TextStyle(color: _accent, fontSize: 13)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _starRow(int n, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= n ? Icons.star : Icons.star_border,
              color: _star, size: size),
      ],
    );
  }

  Widget _reviewTile(Review r) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.at);
    final date = '${dt.month}/${dt.day}';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line, width: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _starRow(r.stars),
              const SizedBox(width: 10),
              Text(date, style: const TextStyle(fontSize: 11.5, color: _sub)),
            ],
          ),
          if (r.text.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              r.text,
              style:
                  const TextStyle(fontSize: 13.5, color: _ink, height: 1.55),
            ),
          ],
        ],
      ),
    );
  }
}
