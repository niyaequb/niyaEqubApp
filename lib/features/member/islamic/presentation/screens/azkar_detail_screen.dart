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
  late List<int> _done;

  int _index = 0;
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

  int get _completedItems {
    var count = 0;
    for (var i = 0; i < _total; i++) {
      if (_done[i] >= widget.category.items[i].repeat) count++;
    }
    return count;
  }

  bool get _isComplete => _completedItems == _total;

  double get _overallProgress {
    final target = widget.category.totalRepeats;
    if (target == 0) return 0;
    return _done.fold<int>(0, (sum, value) => sum + value) / target;
  }

  void _tapCounter() {
    final dhikr = widget.category.items[_index];
    if (_done[_index] >= dhikr.repeat) return;

    setState(() => _done[_index]++);

    if (_done[_index] >= dhikr.repeat) {
      HapticFeedback.mediumImpact();
      _advanceSoon();
    } else {
      HapticFeedback.selectionClick();
    }
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

  void _reset() {
    setState(() {
      _done = List<int>.filled(_total, 0);
      _index = 0;
    });
    _pageController.jumpToPage(0);
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
              ('azkar_${category.id}_title').tr,
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
          if (_isComplete) _completeBanner(category),
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

  Widget _counterBar(dynamic appColors, AzkarCategory category) {
    final dhikr = category.items[_index];
    final done = _done[_index];
    final target = dhikr.repeat;
    final isDone = done >= target;

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
                label: 'azkar_total_dhikr'.tr,
                value: '${_index + 1}/$_total',
              ),
            ),
            _tapCircle(category, done, target, isDone),
            Expanded(
              child: _readout(
                appColors,
                category,
                label: 'azkar_dhikr_count'.tr,
                value: '$target',
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
              'azkar_complete'.tr,
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