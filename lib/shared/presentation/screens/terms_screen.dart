import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// An Equb's terms on a full page, laid out to be read.
///
/// Opened before joining with [requireAcceptance]: the member has to scroll
/// to the end, tick that they have read and accept the terms, and press
/// Accept and Join. Opened from an Equb they already belong to, it is a
/// reader with a close button.
class TermsScreen extends StatefulWidget {
  final String? terms;
  final String? subtitle;
  final bool requireAcceptance;

  const TermsScreen({
    super.key,
    required this.terms,
    this.subtitle,
    this.requireAcceptance = false,
  });

  /// Shows the terms full screen. True only when the member ticked the box
  /// and pressed Accept and Join.
  static Future<bool> open(
    BuildContext context, {
    required String? terms,
    String? subtitle,
    bool requireAcceptance = false,
  }) async {
    final accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => TermsScreen(
          terms: terms,
          subtitle: subtitle,
          requireAcceptance: requireAcceptance,
        ),
      ),
    );
    return accepted ?? false;
  }

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController _scroll = ScrollController();

  /// How far through the terms the member has scrolled, 0 to 1.
  double _progress = 0;

  /// Set once the end has been reached, and never unset: scrolling back up
  /// to re-read a clause does not take the tick box away again.
  bool _reachedEnd = false;

  bool _agreed = false;

  String get _text => widget.terms?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_measure);
    // Terms short enough to fit on the screen are read without scrolling.
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _scroll.removeListener(_measure);
    _scroll.dispose();
    super.dispose();
  }

  void _measure() {
    if (!mounted || !_scroll.hasClients) return;

    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final max = position.maxScrollExtent;
    final progress = max <= 0 ? 1.0 : (position.pixels / max).clamp(0.0, 1.0);
    final atEnd = max <= 0 || position.pixels >= max - 40;

    if (progress != _progress || (atEnd && !_reachedEnd)) {
      setState(() {
        _progress = progress;
        if (atEnd) _reachedEnd = true;
      });
    }
  }

  void _close(bool accepted) => Navigator.of(context).pop(accepted);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? const Color(0xFFE9E6DF) : NiyaPalette.ink;
    final text = _text;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: isDark ? NiyaPalette.navyDeep : const Color(0xFFF1ECDF),
        body: Column(
          children: [
            _Header(
              subtitle: widget.subtitle,
              progress: text.isEmpty ? 1 : _progress,
              onClose: () => _close(false),
            ),
            Expanded(
              child: text.isEmpty
                  ? _NoTerms(color: ink)
                  : NotificationListener<ScrollMetricsNotification>(
                      // The page can change length after it first lays out —
                      // a font arriving, a rotation — without any scroll.
                      onNotification: (_) {
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _measure(),
                        );
                        return false;
                      },
                      child: Scrollbar(
                        controller: _scroll,
                        child: SingleChildScrollView(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(14.w, 16.h, 14.w, 28.h),
                          child: _Paper(
                            isDark: isDark,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TermsContentView(text: text, color: ink),
                                SizedBox(height: 22.h),
                                _EndMark(color: ink),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            if (widget.requireAcceptance)
              _AcceptBar(
                isDark: isDark,
                unlocked: _reachedEnd || text.isEmpty,
                agreed: _agreed,
                onAgree: (value) => setState(() => _agreed = value),
                onCancel: () => _close(false),
                onAccept: _agreed ? () => _close(true) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String? subtitle;
  final double progress;
  final VoidCallback onClose;

  const _Header({
    required this.subtitle,
    required this.progress,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return NiyaNightBackdrop(
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 4.h, 14.w, 12.h),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: MaterialLocalizations.of(context).closeButtonLabel,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onClose,
                        child: Container(
                          margin: EdgeInsets.all(6.r),
                          padding: EdgeInsets.all(7.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.10),
                            border: Border.all(
                              color: NiyaPalette.gold.withValues(alpha: 0.7),
                            ),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'terms_and_conditions'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (subtitle != null && subtitle!.trim().isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 2.h),
                            child: Text(
                              subtitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: NiyaPalette.goldLight,
                                fontSize: 12.5.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  NiyaStarBadge(
                    size: 40.r,
                    child: Icon(
                      Icons.gavel_rounded,
                      size: 17.r,
                      color: NiyaPalette.maroon,
                    ),
                  ),
                ],
              ),
            ),
            // How far through the terms the member is.
            Container(
              height: 3,
              color: Colors.white.withValues(alpha: 0.10),
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: progress.clamp(0.0, 1.0),
                child: Container(color: NiyaPalette.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Paper extends StatelessWidget {
  final bool isDark;
  final Widget child;

  const _Paper({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 22.h, 18.w, 22.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B33) : NiyaPalette.paper,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: NiyaPalette.gold.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EndMark extends StatelessWidget {
  final Color color;

  const _EndMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: NiyaGoldRule()),
        SizedBox(width: 8.w),
        NiyaSparkle(size: 10.r),
        SizedBox(width: 8.w),
        Text(
          'terms_end'.tr,
          style: TextStyle(
            color: color.withValues(alpha: 0.6),
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: 8.w),
        NiyaSparkle(size: 10.r),
        SizedBox(width: 8.w),
        const Expanded(child: NiyaGoldRule(leadsRight: false)),
      ],
    );
  }
}

class _NoTerms extends StatelessWidget {
  final Color color;

  const _NoTerms({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_rounded,
              size: 56.sp,
              color: NiyaPalette.gold.withValues(alpha: 0.7),
            ),
            SizedBox(height: 12.h),
            Text(
              'no_terms_available'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptBar extends StatelessWidget {
  final bool isDark;
  final bool unlocked;
  final bool agreed;
  final ValueChanged<bool> onAgree;
  final VoidCallback onCancel;
  final VoidCallback? onAccept;

  const _AcceptBar({
    required this.isDark,
    required this.unlocked,
    required this.agreed,
    required this.onAgree,
    required this.onCancel,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final ink = isDark ? Colors.white : NiyaPalette.ink;
    final accent = isDark ? NiyaPalette.goldLight : NiyaPalette.maroon;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? NiyaPalette.navy : Colors.white,
        border: Border(
          top: BorderSide(color: NiyaPalette.gold.withValues(alpha: 0.45)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 8.h, 16.w, 12.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!unlocked)
                Padding(
                  padding: EdgeInsets.only(bottom: 4.h, left: 6.w),
                  child: Row(
                    children: [
                      Icon(
                        Icons.keyboard_double_arrow_down_rounded,
                        size: 16.sp,
                        color: accent,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          'terms_scroll_hint'.tr,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap: unlocked ? () => onAgree(!agreed) : null,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 2.h),
                  child: Row(
                    children: [
                      Checkbox(
                        value: agreed,
                        onChanged: unlocked
                            ? (value) => onAgree(value ?? false)
                            : null,
                        activeColor: NiyaPalette.maroon,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: unlocked
                              ? accent
                              : ink.withValues(alpha: 0.3),
                          width: 1.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5.r),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'terms_agree'.tr,
                          style: TextStyle(
                            color: ink.withValues(alpha: unlocked ? 1 : 0.45),
                            fontSize: 13.5.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(
                        minimumSize: Size.fromHeight(46.h),
                        foregroundColor: ink.withValues(alpha: 0.75),
                        side: BorderSide(color: ink.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        'cancel'.tr,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    flex: 3,
                    child: NiyaGoldButton(
                      label: 'accept_and_join'.tr,
                      icon: Icons.verified_rounded,
                      height: 46.h,
                      onPressed: onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Terms text, laid out for reading.
///
/// The terms are plain text typed by an admin. This recognises the shapes
/// they are written in — a title, "Article 1:" headings, numbered clauses
/// ("1.1 …"), lettered points ("ሀ. …", "a) …") and bullets — and gives each
/// its own style. A clause that opens with its own name ("Sharia
/// compliance:- …") has the name in bold. Anything else is a paragraph.
class TermsContentView extends StatelessWidget {
  final String text;
  final Color color;

  const TermsContentView({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? NiyaPalette.goldLight : NiyaPalette.maroon;
    final body = TextStyle(
      color: color,
      fontSize: 14.5.sp,
      height: 1.7,
      fontWeight: FontWeight.w400,
    );

    final blocks = _TermsBlock.parse(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks) _build(block, body, accent),
      ],
    );
  }

  Widget _build(_TermsBlock block, TextStyle body, Color accent) {
    switch (block.kind) {
      case _Kind.title:
        return Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Column(
            children: [
              Text(
                block.text,
                textAlign: TextAlign.center,
                style: body.copyWith(
                  color: accent,
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w900,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  const Expanded(child: NiyaGoldRule()),
                  SizedBox(width: 6.w),
                  NiyaSparkle(size: 9.r),
                  SizedBox(width: 6.w),
                  const Expanded(child: NiyaGoldRule(leadsRight: false)),
                ],
              ),
            ],
          ),
        );

      case _Kind.heading:
        return Padding(
          padding: EdgeInsets.only(top: 16.h, bottom: 6.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 20.h,
                margin: EdgeInsets.only(top: 2.h, right: 10.w),
                decoration: BoxDecoration(
                  gradient: NiyaPalette.goldSheen,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Expanded(
                child: Text(
                  block.text,
                  style: body.copyWith(
                    color: accent,
                    fontSize: 15.5.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );

      case _Kind.clause:
        return Padding(
          padding: EdgeInsets.only(top: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: EdgeInsets.only(top: 3.h, right: 8.w),
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  block.marker ?? '',
                  style: body.copyWith(
                    color: accent,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
              ),
              Expanded(child: _rich(block.text, body)),
            ],
          ),
        );

      case _Kind.item:
        return Padding(
          padding: EdgeInsets.only(top: 6.h, left: 12.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26.w,
                child: Text(
                  '${block.marker}.',
                  style: body.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(child: _rich(block.text, body)),
            ],
          ),
        );

      case _Kind.bullet:
        return Padding(
          padding: EdgeInsets.only(top: 6.h, left: 12.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 9.h, right: 10.w),
                child: NiyaSparkle(size: 7.r),
              ),
              Expanded(child: _rich(block.text, body)),
            ],
          ),
        );

      case _Kind.paragraph:
        return Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: _rich(block.text, body),
        );

      case _Kind.gap:
        return SizedBox(height: 6.h);
    }
  }

  /// [text] with its opening name in bold when it has one: everything up to
  /// "፡-", "፦" or ":-" near the start of the line.
  static Widget _rich(String text, TextStyle body) {
    final split = _TermsBlock.leadEnd(text);
    if (split == null) return Text(text, style: body);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text.substring(0, split),
            style: body.copyWith(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: text.substring(split)),
        ],
      ),
      style: body,
    );
  }
}

enum _Kind { title, heading, clause, item, bullet, paragraph, gap }

class _TermsBlock {
  final _Kind kind;
  final String text;
  final String? marker;

  const _TermsBlock(this.kind, this.text, [this.marker]);

  /// Words a heading starts with, in the app's three languages.
  static const _headingWords = [
    'አንቀጽ',
    'አንቀፅ',
    'ክፍል',
    'ምዕራፍ',
    'article',
    'section',
    'chapter',
    'kutaa',
    'keeyyata',
    'boqonnaa',
  ];

  /// "1.", "1.1", "2)" and the text after it. A bare number ("3 members
  /// must…") is a sentence, not a clause.
  static final _clause = RegExp(
    r'^(\d{1,3}(?:\.\d{1,3})+\.?|\d{1,3}[.)])\s*(.+)$',
  );

  /// "ሀ." or "a)" and the text after it: one Ethiopic or Latin letter.
  static final _item = RegExp(r'^([ሀ-፿]|[A-Za-z])[.)]\s*(.+)$');

  /// "-", "•" or "*" and the text after it.
  static final _bullet = RegExp(r'^[-•*·▪●]\s*(.+)$');

  static List<_TermsBlock> parse(String raw) {
    final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    final blocks = <_TermsBlock>[];
    var seenText = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();

      if (line.isEmpty) {
        if (blocks.isNotEmpty && blocks.last.kind != _Kind.gap) {
          blocks.add(const _TermsBlock(_Kind.gap, ''));
        }
        continue;
      }

      final isFirst = !seenText;
      seenText = true;

      final clause = _clause.firstMatch(line);
      if (clause != null) {
        blocks.add(_TermsBlock(_Kind.clause, clause.group(2)!, clause.group(1)));
        continue;
      }

      final lower = line.toLowerCase();
      if (_headingWords.any(lower.startsWith) && line.length <= 120) {
        blocks.add(_TermsBlock(_Kind.heading, line));
        continue;
      }

      final item = _item.firstMatch(line);
      if (item != null && !_looksLikeSentence(line)) {
        blocks.add(_TermsBlock(_Kind.item, item.group(2)!, item.group(1)));
        continue;
      }

      final bullet = _bullet.firstMatch(line);
      if (bullet != null) {
        blocks.add(_TermsBlock(_Kind.bullet, bullet.group(1)!));
        continue;
      }

      // A short opening line is the document's title.
      if (isFirst && line.length <= 80) {
        blocks.add(_TermsBlock(_Kind.title, line));
        continue;
      }

      // A short line ending in a colon introduces what follows.
      if (line.length <= 70 &&
          (line.endsWith(':') || line.endsWith('፡') || line.endsWith('፦'))) {
        blocks.add(_TermsBlock(_Kind.heading, line));
        continue;
      }

      blocks.add(_TermsBlock(_Kind.paragraph, line));
    }

    while (blocks.isNotEmpty && blocks.last.kind == _Kind.gap) {
      blocks.removeLast();
    }
    return blocks;
  }

  /// "e.g. …" or "ኢ.ፌ.ዴ.ሪ." start like a lettered point but are not one.
  static bool _looksLikeSentence(String line) => RegExp(
    r'^([\u1200-\u137F]|[A-Za-z])\.([\u1200-\u137F]|[A-Za-z])',
  ).hasMatch(line);

  /// Where a clause's own name ends, if it opens with one.
  static int? leadEnd(String text) {
    const marks = ['፡-', '፦', ':-', '፡ -', ': -'];
    int? start;
    int? end;
    for (final mark in marks) {
      final i = text.indexOf(mark);
      if (i > 0 && i <= 90 && (start == null || i < start)) {
        start = i;
        end = i + mark.length;
      }
    }
    return end;
  }
}
