import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/data/models/azkar_model.dart';
import 'package:niya_equb/features/member/islamic/presentation/widgets/azkar_scene.dart';
import 'package:share_plus/share_plus.dart';

class AzkarDetailScreen extends StatefulWidget {
  static const String routeName = '/islamic-azkar-detail';

  const AzkarDetailScreen({super.key, required this.category});

  final AzkarCategory category;

  @override
  State<AzkarDetailScreen> createState() => _AzkarDetailScreenState();
}

class _AzkarDetailScreenState extends State<AzkarDetailScreen> {
  late final PageController _pageController;

  /// Recitations done for each step **of the circuit currently in progress**.
  /// Reset at the start of every circuit; finished circuits are remembered by
  /// [_cycle] alone, so the array never has to grow.
  late List<int> _done;

  int _index = 0;

  /// Which circuit is under way, zero-based. Always 0 for the categories that
  /// are simply read once through.
  int _cycle = 0;

  bool _showTransliteration = true;
  bool _advancing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _done = List<int>.filled(widget.category.items.length, 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _total => widget.category.items.length;

  int get _cycles => widget.category.cycles;

  bool get _hasCycles => widget.category.hasCycles;

  /// Steps finished in the circuit currently in progress.
  int get _completedItems {
    var count = 0;
    for (var i = 0; i < _total; i++) {
      if (_done[i] >= widget.category.items[i].repeat) count++;
    }
    return count;
  }

  bool get _cycleComplete => _completedItems == _total;

  /// The whole rite is done only when the last step of the last circuit is.
  /// For an ordinary category [_cycles] is 1 and this is the old behaviour.
  bool get _isComplete => _cycleComplete && _cycle >= _cycles - 1;

  double get _overallProgress {
    final target = widget.category.totalRepeats;
    if (target == 0) return 0;

    // Circuits already behind us count in full; only the current one is
    // counted step by step.
    final banked = _cycle * widget.category.repeatsPerCycle;
    final current = _done.fold<int>(0, (sum, value) => sum + value);

    return ((banked + current) / target).clamp(0.0, 1.0);
  }

  void _tapCounter() {
    final dhikr = widget.category.items[_index];
    if (_done[_index] >= dhikr.repeat) return;

    setState(() => _done[_index]++);

    if (_done[_index] < dhikr.repeat) {
      HapticFeedback.selectionClick();
      return;
    }

    HapticFeedback.mediumImpact();

    if (_index < _total - 1) {
      // More steps left in this circuit.
      _advanceSoon();
      return;
    }

    if (_cycle < _cycles - 1) {
      // Last step of a circuit that is not the last: start the next lap.
      _startNextCycleSoon();
      return;
    }

    // Seventh circuit finished.
    HapticFeedback.heavyImpact();
  }

  void _advanceSoon() {
    if (_advancing || _index >= _total - 1) return;
    _advancing = true;

    Future.delayed(const Duration(milliseconds: 420), () {
      if (!mounted) return;
      _advancing = false;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  /// Roll over to the next circuit: bank the one just finished, clear the step
  /// counts and go back to the first step.
  ///
  /// The page jumps rather than animating. Sliding backwards through three
  /// pages reads as an undo, when what has actually happened is progress — a
  /// lap completed and a new one begun.
  void _startNextCycleSoon() {
    if (_advancing) return;
    _advancing = true;

    Future.delayed(const Duration(milliseconds: 620), () {
      if (!mounted) return;
      _advancing = false;

      setState(() {
        _cycle++;
        _done = List<int>.filled(_total, 0);
        _index = 0;
      });

      _pageController.jumpToPage(0);
      HapticFeedback.mediumImpact();
    });
  }

  void _reset() {
    setState(() {
      _done = List<int>.filled(_total, 0);
      _index = 0;
      _cycle = 0;
    });
    _pageController.jumpToPage(0);
  }

  /// The category's display title.
  ///
  /// The screen used to rebuild this as `'azkar_${category.id}_title'.tr`,
  /// which only works for categories whose id happens to match a key in that
  /// exact shape. The Umrah du'a categories have ids like `umrah_dua_travel`,
  /// so it built `azkar_umrah_dua_travel_title`, found nothing, and printed
  /// the key itself into the app bar.
  ///
  /// AzkarCategory already carries a resolved [titleEn]. Preferring it fixes
  /// the new categories, and the legacy lookup is kept ahead of it so nothing
  /// that relied on the old pattern changes.
  String get _title {
    final legacyKey = 'azkar_${widget.category.id}_title';
    final translated = legacyKey.tr;

    // GetX returns the key unchanged when there is no entry for it, which is
    // the only signal available that the lookup missed.
    return translated == legacyKey ? widget.category.titleEn : translated;
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);
    final category = widget.category;
    final variant = azkarSceneFor(category.id);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: category.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Stack(
          fit: StackFit.expand,
          children: [
            AzkarScene(variant: variant, accent: category.accent),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.34),
                    Colors.black.withValues(alpha: 0.10),
                  ],
                ),
              ),
            ),
          ],
        ),
        title: Column(
          children: [
            Text(
              _title,
              style: TextStyle(
                fontSize: 14.5.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              category.titleAr,
              style: TextStyle(fontSize: 11.sp, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'transliteration'.tr,
            icon: Icon(
              _showTransliteration ? Icons.abc_rounded : Icons.abc_outlined,
              color: Colors.white,
            ),
            onPressed: () =>
                setState(() => _showTransliteration = !_showTransliteration),
          ),
          IconButton(
            tooltip: 'reset'.tr,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _reset,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(4.h),
          child: LinearProgressIndicator(
            value: _overallProgress,
            minHeight: 4.h,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isComplete)
            _completeBanner(category)
          else if (_hasCycles)
            _circuitTracker(appColors, category),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _total,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, index) => _dhikrPage(
                appColors,
                category,
                category.items[index],
                index,
              ),
            ),
          ),
          _counterBar(appColors, category),
        ],
      ),
    );
  }

  /// Which lap the pilgrim is on, and how many are left.
  ///
  /// This is the piece the old screen had no room for: tawaf is counted in
  /// circuits, and a pilgrim mid-tawaf needs to know they are on the fourth
  /// without holding it in their head while walking. The dots make the count
  /// readable at a glance in bright sun and a crowd, where reading a sentence
  /// is not realistic.
  Widget _circuitTracker(dynamic appColors, AzkarCategory category) {
    final label = (category.cycleLabelKey ?? 'tawaf_circuit').tr;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 0),
      padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: category.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: category.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.refresh_rounded, size: 17.sp, color: category.accent),
          SizedBox(width: 9.w),
          Expanded(
            child: Text(
              'azkar_circuit_of'.trParams({
                'label': label,
                'current': '${_cycle + 1}',
                'total': '$_cycles',
              }),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: category.accent,
              ),
            ),
          ),
          // One dot per circuit: solid for laps finished, ringed for the one
          // under way, hollow for those still to come.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(_cycles, (i) {
              final done = i < _cycle;
              final current = i == _cycle;

              return Container(
                width: current ? 9.r : 7.r,
                height: current ? 9.r : 7.r,
                margin: EdgeInsets.only(left: 4.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || current
                      ? category.accent
                      : category.accent.withValues(alpha: 0.22),
                  border: current
                      ? Border.all(
                          color: category.accent.withValues(alpha: 0.35),
                          width: 2,
                        )
                      : null,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _counterBar(dynamic appColors, AzkarCategory category) {
    final dhikr = category.items[_index];
    final done = _done[_index];
    final target = dhikr.repeat;
    final isDone = done >= target;

    // For a category walked in circuits, the two readouts answer "where am I
    // in this lap" and "which lap am I on". The right-hand slot used to show
    // the current dhikr's repeat count, which for tawaf was the number 7 — the
    // very number that made the screen read as "say this seven times".
    final leftLabel =
        _hasCycles ? 'azkar_circuit_step'.tr : 'azkar_total_dhikr'.tr;
    final rightLabel = _hasCycles
        ? (category.cycleLabelKey ?? 'tawaf_circuit').tr
        : 'azkar_dhikr_count'.tr;
    final rightValue = _hasCycles ? '${_cycle + 1} / $_cycles' : '$target';

    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 16.h),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        border: Border(
          top: BorderSide(
            color: appColors.borderColor ?? Colors.transparent,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _readout(
                appColors,
                category,
                label: leftLabel,
                value: '${_index + 1}/$_total',
              ),
            ),
            _tapCircle(category, done, target, isDone),
            Expanded(
              child: _readout(
                appColors,
                category,
                label: rightLabel,
                value: rightValue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readout(
    dynamic appColors,
    AzkarCategory category, {
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w500,
            height: 1.25,
            color: appColors.bodyTextSmallColor,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: appColors.titleTextColor,
          ),
        ),
      ],
    );
  }

  Widget _tapCircle(
    AzkarCategory category,
    int done,
    int target,
    bool isDone,
  ) {
    final progress = target == 0 ? 0.0 : (done / target).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      label: '${'azkar_dhikr_count'.tr}: $done / $target',
      child: GestureDetector(
        onTap: _tapCounter,
        child: SizedBox(
          width: 96.w,
          height: 96.w,
          child: CustomPaint(
            painter: _CounterRingPainter(
              progress: progress,
              accent: category.accent,
              trackColor: category.accent.withValues(alpha: 0.16),
              filled: isDone,
            ),
            child: Center(
              child: isDone
                  ? Icon(
                      Icons.check_rounded,
                      size: 34.sp,
                      color: Colors.white,
                    )
                  : Text(
                      '$done',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: category.accent,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dhikrPage(
    dynamic appColors,
    AzkarCategory category,
    Dhikr dhikr,
    int index,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 20.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: category.accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w700,
                    color: category.accent,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'copy'.tr,
                icon: Icon(
                  Icons.copy_rounded,
                  size: 17.sp,
                  color: appColors.bodyTextSmallColor,
                ),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _shareText(dhikr)));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('copied'.tr),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'share'.tr,
                icon: Icon(
                  Icons.share_rounded,
                  size: 17.sp,
                  color: appColors.bodyTextSmallColor,
                ),
                onPressed: () => Share.share(_shareText(dhikr)),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Text(
            dhikr.arabic,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 21.sp,
              fontWeight: FontWeight.w600,
              height: 2.05,
              color: appColors.titleTextColor,
            ),
          ),
          if (_showTransliteration) ...[
            SizedBox(height: 14.h),
            Text(
              dhikr.transliteration,
              style: TextStyle(
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
                height: 1.55,
                color: category.accent,
              ),
            ),
          ],
          SizedBox(height: 14.h),
          Text(
            dhikr.translation.tr,
            style: TextStyle(
              fontSize: 12.5.sp,
              height: 1.6,
              color: appColors.bodyTextSmallColor,
            ),
          ),
          if (dhikr.virtue != null) ...[
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(11.w),
              decoration: BoxDecoration(
                color: category.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 15.sp,
                    color: category.accent,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      dhikr.virtue!.tr,
                      style: TextStyle(
                        fontSize: 11.sp,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        color: appColors.bodyTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: 12.h),
          Text(
            dhikr.reference,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: appColors.bodyTextSmallColor?.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _completeBanner(AzkarCategory category) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 0),
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 14.w),
      decoration: BoxDecoration(
        color: category.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: category.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: category.accent, size: 21.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              // Tawaf ends on a different note from a set of morning azkar:
              // the thing finished is seven laps, not a list.
              _hasCycles ? 'azkar_cycles_complete'.tr : 'azkar_complete'.tr,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: category.accent,
              ),
            ),
          ),
          TextButton(
            onPressed: _reset,
            child: Text(
              'reset'.tr,
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w700,
                color: category.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shareText(Dhikr dhikr) {
    return '${dhikr.arabic}\n\n${dhikr.transliteration}\n\n'
        '${dhikr.translation.tr}\n\n— ${dhikr.reference}';
  }
}

class _CounterRingPainter extends CustomPainter {
  _CounterRingPainter({
    required this.progress,
    required this.accent,
    required this.trackColor,
    required this.filled,
  });

  final double progress;
  final Color accent;
  final Color trackColor;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final stroke = size.width * 0.075;
    final radius = (size.width - stroke) / 2;

    canvas.drawCircle(
      centre,
      radius,
      Paint()..color = filled ? accent : trackColor,
    );

    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = accent.withValues(alpha: 0.22),
    );

    if (progress > 0 && !filled) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -1.5707963267948966,
        6.283185307179586 * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = accent,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CounterRingPainter old) =>
      old.progress != progress ||
      old.accent != accent ||
      old.filled != filled ||
      old.trackColor != trackColor;
}