import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:niya_equb/core/config/app_theme.dart';
import 'package:niya_equb/features/member/islamic/presentation/islamic_theme.dart';
import 'package:niya_equb/features/member/islamic/services/islamic_prefs.dart';

/// A preset dhikr with its conventional target.
class _TasbihPreset {
  final String id;
  final String arabic;
  final String transliteration;
  final int target;

  const _TasbihPreset(this.id, this.arabic, this.transliteration, this.target);
}

/// Digital tasbih counter.
///
/// The whole screen is the button — reaching for a small target while keeping
/// your eyes lowered defeats the point. Counting is haptic-first: a light tick
/// per bead, a heavier pulse at the target, so it can be used without looking.
class TasbihScreen extends StatefulWidget {
  static const String routeName = '/islamic-tasbih';

  const TasbihScreen({super.key});

  @override
  State<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends State<TasbihScreen>
    with SingleTickerProviderStateMixin {
  static const List<_TasbihPreset> _presets = [
    _TasbihPreset('subhanallah', 'سُبْحَانَ اللَّهِ', 'Subhanallah', 33),
    _TasbihPreset('alhamdulillah', 'الْحَمْدُ لِلَّهِ', 'Alhamdulillah', 33),
    _TasbihPreset('allahuakbar', 'اللَّهُ أَكْبَرُ', 'Allahu Akbar', 34),
    _TasbihPreset(
      'tahlil',
      'لَا إِلَهَ إِلَّا اللَّهُ',
      'La ilaha illallah',
      100,
    ),
    _TasbihPreset(
      'istighfar',
      'أَسْتَغْفِرُ اللَّهَ',
      'Astaghfirullah',
      100,
    ),
    _TasbihPreset(
      'salawat',
      'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
      'Allahumma salli ala Muhammad',
      100,
    ),
  ];

  late AnimationController _pulse;

  int _count = 0;
  int _rounds = 0;
  int _lifetime = 0;
  int _presetIndex = 0;

  bool _vibrate = true;

  _TasbihPreset get _preset => _presets[_presetIndex];

  int get _target => _preset.target;

  double get _progress => _target == 0 ? 0 : (_count % _target) / _target;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _loadLifetime();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadLifetime() async {
    final value = await IslamicPrefs.getTasbihLifetime();
    if (mounted) setState(() => _lifetime = value);
  }

  void _increment() {
    setState(() {
      _count++;
      if (_target > 0 && _count % _target == 0) {
        _rounds++;
      }
    });

    _pulse.forward().then((_) => _pulse.reverse());

    // Lifetime is persisted in batches of ten rather than on every tap — a
    // disk write per bead would be wasteful during a hundred-count session.
    if (_count % 10 == 0) {
      IslamicPrefs.addTasbihLifetime(10);
      _lifetime += 10;
    }

    if (!_vibrate) return;

    if (_target > 0 && _count % _target == 0) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  Future<void> _reset() async {
    // Flush whatever has not yet been batched into the lifetime total.
    final unsaved = _count % 10;
    if (unsaved > 0) {
      await IslamicPrefs.addTasbihLifetime(unsaved);
    }

    await _loadLifetime();

    if (!mounted) return;
    setState(() {
      _count = 0;
      _rounds = 0;
    });
    HapticFeedback.mediumImpact();
  }

  void _undo() {
    if (_count == 0) return;
    setState(() {
      _count--;
      if (_target > 0 && (_count + 1) % _target == 0 && _rounds > 0) {
        _rounds--;
      }
    });
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final appColors = colors(context);

    return Scaffold(
      backgroundColor: appColors.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: IslamicColors.featureTasbih,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'tasbih'.tr,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'vibration'.tr,
            icon: Icon(
              _vibrate
                  ? Icons.vibration_rounded
                  : Icons.smartphone_rounded,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _vibrate = !_vibrate),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _increment,
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: 10.h),
              _presetPicker(appColors),
              SizedBox(height: 14.h),
              _dhikrLabel(appColors),
              Expanded(child: Center(child: _counterRing(appColors))),
              _stats(appColors),
              SizedBox(height: 12.h),
              _controls(appColors),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetPicker(dynamic appColors) {
    return SizedBox(
      height: 34.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        itemCount: _presets.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final preset = _presets[index];
          final selected = index == _presetIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _presetIndex = index;
                _count = 0;
                _rounds = 0;
              });
              HapticFeedback.selectionClick();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? IslamicColors.featureTasbih
                    : appColors.accentColor,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: selected
                      ? IslamicColors.featureTasbih
                      : (appColors.borderColor ?? Colors.transparent),
                ),
              ),
              child: Text(
                '${preset.transliteration} · ${preset.target}',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : appColors.bodyTextColor,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dhikrLabel(dynamic appColors) {
    return Column(
      children: [
        Text(
          _preset.arabic,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            height: 1.7,
            color: appColors.titleTextColor,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          _preset.transliteration,
          style: TextStyle(
            fontSize: 11.5.sp,
            fontStyle: FontStyle.italic,
            color: appColors.bodyTextSmallColor,
          ),
        ),
      ],
    );
  }

  Widget _counterRing(dynamic appColors) {
    final displayCount = _target > 0 && _count > 0 && _count % _target == 0
        ? _target
        : _count % (_target == 0 ? 1000000 : _target);

    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        return Transform.scale(scale: 1 + _pulse.value, child: child);
      },
      child: SizedBox(
        width: 230.w,
        height: 230.w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: _progress == 0 && _count > 0 ? 1.0 : _progress,
                strokeWidth: 12,
                backgroundColor: IslamicColors.featureTasbih.withValues(
                  alpha: 0.14,
                ),
                valueColor: const AlwaysStoppedAnimation(
                  IslamicColors.featureTasbih,
                ),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$displayCount',
                  style: TextStyle(
                    fontSize: 62.sp,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: appColors.titleTextColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${'of'.tr} $_target',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: appColors.bodyTextSmallColor,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'tap_anywhere'.tr,
                  style: TextStyle(
                    fontSize: 9.5.sp,
                    color: appColors.bodyTextSmallColor?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(dynamic appColors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Expanded(
            child: _stat(appColors, '$_count', 'total_this_session'.tr),
          ),
          SizedBox(width: 10.w),
          Expanded(child: _stat(appColors, '$_rounds', 'rounds_completed'.tr)),
          SizedBox(width: 10.w),
          Expanded(
            child: _stat(appColors, _formatLifetime(_lifetime), 'lifetime'.tr),
          ),
        ],
      ),
    );
  }

  String _formatLifetime(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  Widget _stat(dynamic appColors, String value, String label) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 6.w),
      decoration: BoxDecoration(
        color: appColors.accentColor,
        borderRadius: BorderRadius.circular(13.r),
        border: Border.all(color: appColors.borderColor ?? Colors.transparent),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
                color: IslamicColors.featureTasbih,
              ),
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.sp,
              height: 1.2,
              color: appColors.bodyTextSmallColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controls(dynamic appColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _controlButton(
          appColors,
          icon: Icons.undo_rounded,
          label: 'undo'.tr,
          onTap: _undo,
        ),
        SizedBox(width: 30.w),
        _controlButton(
          appColors,
          icon: Icons.refresh_rounded,
          label: 'reset'.tr,
          onTap: _reset,
        ),
      ],
    );
  }

  Widget _controlButton(
    dynamic appColors, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      // Stops the tap falling through to the counter behind it.
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: appColors.accentColor,
              border: Border.all(
                color: appColors.borderColor ?? Colors.transparent,
              ),
            ),
            child: Icon(
              icon,
              size: 21.sp,
              color: appColors.bodyTextSmallColor,
            ),
          ),
          SizedBox(height: 5.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: appColors.bodyTextSmallColor,
            ),
          ),
        ],
      ),
    );
  }
}
