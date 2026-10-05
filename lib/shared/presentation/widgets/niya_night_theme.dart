import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// Re-paints a whole subtree in the Niya night palette.
///
/// WHY THIS EXISTS RATHER THAN A RECOLOURED COPY OF EVERY WIDGET
///
/// Almost every shared widget in this app takes its colours from
/// `colors(context)`, which is `Theme.of(context).extension<AppColors>()!`.
/// That is a ThemeExtension, so swapping it for a night version here turns the
/// entire subtree night-correct at once — the text fields, the ledger cards,
/// the member tiles, the pickers — without editing any of them, and without
/// touching how they look anywhere else in the app.
///
/// Modal sheets and dialogs come along too. `showModalBottomSheet` and
/// `showDialog` capture the calling context's inherited themes and re-plant
/// them under the navigator, so a sheet opened from inside this subtree is
/// night-styled even though its route is mounted far above it.
///
/// A full-screen route pushed from here does NOT inherit it — `MaterialPageRoute`
/// captures nothing — which is deliberate. The terms reader, for one, is meant
/// to look like paper.
class NiyaNightTheme extends StatelessWidget {
  final Widget child;

  const NiyaNightTheme({super.key, required this.child});

  /// The night palette as an [AppColors], so screens that need a single colour
  /// can read it without building a Theme.
  static const AppColors palette = AppColors(
    primaryColor: NiyaPalette.gold,
    accentColor: NiyaPalette.navySoft,
    buttonColor: NiyaPalette.gold,
    buttonTextColor: NiyaPalette.maroonDeep,
    bodyTextColor: Colors.white,
    bodyTextSmallColor: Colors.white70,
    titleTextColor: Colors.white,
    hintTextColor: Colors.white60,
    borderColor: Color(0x59C9A24A), // gold at 35%
    scaffoldBackgroundColor: NiyaPalette.navyDeep,
  );

  static const Color danger = Color(0xFFF87171);

  static ThemeData resolve(BuildContext context) {
    final base = Theme.of(context);

    // Everything else the app registers is kept; only AppColors is swapped.
    //
    // The element type is left to inference from `base.extensions.values`
    // rather than written out. Annotating this `<ThemeExtension<dynamic>>[...]`
    // does not compile: the class is declared
    // `ThemeExtension<T extends ThemeExtension<T>>`, `dynamic` does not satisfy
    // that bound, and the compiler recovers by instantiating to bounds — which
    // is where the `ThemeExtension<ThemeExtension<dynamic>>` in the error
    // comes from. The framework's own `Map<Object, ThemeExtension<dynamic>>`
    // hands us the right type already, so inference gets it right for free.
    final extensions = base.extensions.values
        .where((e) => e is! AppColors)
        .toList()
      ..add(palette);

    return base.copyWith(
      // `ThemeData.brightness` is a getter over `colorScheme.brightness`, and
      // copyWith pushes this value into the scheme — so this is the one that
      // takes effect. It is set because widgets across this app branch on
      // `Theme.of(context).brightness` to pick a dark palette, and the one
      // inside the scheme below is set too so the ColorScheme stays
      // self-consistent for anything that reads it directly.
      brightness: Brightness.dark,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: NiyaPalette.gold,
        onPrimary: NiyaPalette.maroonDeep,
        secondary: NiyaPalette.goldLight,
        onSecondary: NiyaPalette.maroonDeep,
        surface: NiyaPalette.navySoft,
        onSurface: Colors.white,
        surfaceContainer: NiyaPalette.navy,
        surfaceContainerHigh: NiyaPalette.navySoft,
        surfaceContainerHighest: NiyaPalette.navySoft,
        error: danger,
        onError: NiyaPalette.navyDeep,
        outline: NiyaPalette.gold,
      ),
      scaffoldBackgroundColor: NiyaPalette.navyDeep,
      canvasColor: NiyaPalette.navy,
      dividerColor: NiyaPalette.gold.withValues(alpha: 0.22),
      unselectedWidgetColor: NiyaPalette.goldLight,
      extensions: extensions,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: NiyaPalette.goldLight, size: 22.r),
        actionsIconTheme: IconThemeData(
          color: NiyaPalette.goldLight,
          size: 22.r,
        ),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 17.sp,
          fontWeight: FontWeight.w800,
          fontFamily: 'Lexend',
          letterSpacing: 0.3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: false,
        filled: true,
        fillColor: NiyaPalette.navyDeep.withValues(alpha: 0.55),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
        hintStyle: TextStyle(color: Colors.white54, fontSize: 13.sp),
        labelStyle: TextStyle(color: Colors.white60, fontSize: 13.sp),
        floatingLabelStyle: TextStyle(
          color: NiyaPalette.goldLight,
          fontSize: 13.sp,
        ),
        enabledBorder: _border(NiyaPalette.gold.withValues(alpha: 0.35)),
        border: _border(NiyaPalette.gold.withValues(alpha: 0.35)),
        focusedBorder: _border(NiyaPalette.gold, width: 1.5),
        disabledBorder: _border(NiyaPalette.gold.withValues(alpha: 0.15)),
        errorBorder: _border(danger),
        focusedErrorBorder: _border(danger, width: 1.5),
        errorStyle: TextStyle(color: danger, fontSize: 11.sp),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: NiyaPalette.goldLight,
        selectionColor: NiyaPalette.gold.withValues(alpha: 0.3),
        selectionHandleColor: NiyaPalette.gold,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NiyaPalette.gold,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NiyaPalette.gold
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(NiyaPalette.maroonDeep),
        side: const BorderSide(color: NiyaPalette.gold, width: 1.4),
      ),
      radioTheme: RadioThemeData(
        fillColor: const WidgetStatePropertyAll(NiyaPalette.gold),
        overlayColor: WidgetStatePropertyAll(
          NiyaPalette.gold.withValues(alpha: 0.12),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NiyaPalette.gold
              : Colors.white54,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? NiyaPalette.gold.withValues(alpha: 0.35)
              : NiyaPalette.navyDeep,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: NiyaPalette.navy,
        modalBackgroundColor: NiyaPalette.navy,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: NiyaPalette.goldLight,
      ),
      iconTheme: const IconThemeData(color: NiyaPalette.goldLight),
      dividerTheme: DividerThemeData(
        color: NiyaPalette.gold.withValues(alpha: 0.22),
        space: 1,
        thickness: 1,
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.r),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(data: resolve(context), child: child);
  }
}

/// How far down the first pixel of content has to start when the app bar is
/// drawn over the backdrop.
///
/// CALL THIS FROM INSIDE [NiyaNightScaffold]'s `body` BUILDER, nowhere else.
///
/// Scaffold rewrites the MediaQuery it hands its body: with
/// `extendBodyBehindAppBar: true`, `_BodyBuilder` sets the body's
/// `padding.top` to `max(statusBar, fullAppBarHeight)` — the toolbar is
/// already in there. Adding `kToolbarHeight` on top, which is the obvious
/// thing to write, silently buys about 56 logical pixels of dead space at the
/// head of every list. Called from a context ABOVE the Scaffold the padding is
/// the bare status bar instead and this returns too little, which is why it
/// belongs in the body builder and the builder is why `body` is a
/// [WidgetBuilder].
///
/// Pass it as the list's top padding and as a RefreshIndicator's `edgeOffset`.
double niyaTopInset(BuildContext context) => MediaQuery.paddingOf(context).top;

/// The shell every Equb group screen wears: the night theme, the navy
/// backdrop, a transparent app bar over it, and an optional bar pinned to the
/// bottom for the screen's main action.
///
/// [body] and [bottomBar] are builders rather than widgets so their content is
/// built from a context that is already underneath the night theme. Passing a
/// pre-built widget would work for anything that reads the theme in its own
/// build, but silently give light colours to anything the caller resolved
/// eagerly — `colors(context)` on the line where the widget is constructed is
/// exactly that mistake, and it is invisible until you look at the screen.
class NiyaNightScaffold extends StatelessWidget {
  final String title;
  final WidgetBuilder body;
  final WidgetBuilder? bottomBar;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;

  const NiyaNightScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomBar,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    return NiyaNightTheme(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: NiyaPalette.navyDeep,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(title),
            leading: leading,
            actions: actions,
            automaticallyImplyLeading: automaticallyImplyLeading,
          ),
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomBar == null
              ? null
              : NiyaBottomBar(child: Builder(builder: bottomBar!)),
          body: Stack(
            children: [
              const Positioned.fill(child: NiyaNightBackdrop()),
              Builder(builder: body),
            ],
          ),
        ),
      ),
    );
  }
}

/// An opaque navy strip along the bottom edge with a gold hairline on top, so
/// the main action never has to be read against the star lattice.
class NiyaBottomBar extends StatelessWidget {
  final Widget child;

  const NiyaBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: NiyaPalette.navyDeep,
        border: Border(
          top: BorderSide(color: NiyaPalette.gold.withValues(alpha: 0.3)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 12.h),
        child: child,
      ),
    );
  }
}

/// The card every panel on these screens is cut from: navy, a gold hairline,
/// and the same corner radius as a package row.
class NiyaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  /// A brighter frame, for the one card on a screen that is asking for a
  /// decision rather than reporting a fact.
  final bool emphasised;

  const NiyaCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16.r);
    final inner = Padding(
      padding: padding ?? EdgeInsets.all(14.r),
      child: child,
    );

    return Material(
      color: color ?? NiyaPalette.navySoft,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.5),
      borderRadius: radius,
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: NiyaPalette.gold.withValues(alpha: emphasised ? 0.65 : 0.35),
            width: emphasised ? 1.2 : 1,
          ),
        ),
        child: onTap == null
            ? inner
            : InkWell(borderRadius: radius, onTap: onTap, child: inner),
      ),
    );
  }
}

/// A form section's heading: a gold sparkle, the label, then a rule running
/// out to the edge. Quieter than [NiyaOrnamentTitle], which is for the top of
/// a whole list.
class NiyaSectionLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? tint;
  final Widget? trailing;

  const NiyaSectionLabel({
    super.key,
    required this.label,
    this.icon,
    this.tint,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colour = tint ?? NiyaPalette.goldLight;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15.sp, color: colour),
          SizedBox(width: 7.w),
        ] else ...[
          NiyaSparkle(size: 9.r, color: colour),
          SizedBox(width: 8.w),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(child: NiyaGoldRule(thickness: 1, leadsRight: false)),
        if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
      ],
    );
  }
}

/// A pill that reads against navy: a tinted ground, a half-strength ring and
/// the label in the full colour.
class NiyaPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const NiyaPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11.sp, color: color),
            SizedBox(width: 4.w),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The quiet half of a pair of actions: a gold outline and nothing inside it.
class NiyaGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double? height;
  final Color? tint;

  const NiyaGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(999);
    final colour = tint ?? NiyaPalette.gold;
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: colour.withValues(alpha: 0.55)),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: SizedBox(
              height: height ?? 44.h,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 15.sp, color: Colors.white),
                        SizedBox(width: 6.w),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A text field for the night screens.
///
/// Deliberately a thin wrapper over [TextFormField] rather than a restyled
/// [CustomTextField]: the borders, fill, label and cursor all come from the
/// `inputDecorationTheme` that [NiyaNightTheme] installs, so this only has to
/// say what the field is for. Put it under a [NiyaNightTheme] — on its own it
/// inherits whatever the ambient theme gives it.
class NiyaField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final IconData? icon;
  final Widget? suffix;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  const NiyaField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.helper,
    this.icon,
    this.suffix,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onChanged: onChanged,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      cursorColor: NiyaPalette.goldLight,
      style: TextStyle(
        color: Colors.white,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        helperStyle: TextStyle(color: Colors.white60, fontSize: 10.5.sp),
        counterStyle: TextStyle(color: Colors.white38, fontSize: 10.sp),
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 18.sp, color: NiyaPalette.goldLight),
        suffixIcon: suffix,
      ),
    );
  }
}

/// Says what is missing and what to do about it, on the night backdrop.
class NiyaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const NiyaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NiyaStarBadge(
            size: 86.r,
            child: Icon(icon, size: 34.r, color: NiyaPalette.maroon),
          ),
          SizedBox(height: 18.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 20.h),
            NiyaGoldButton(
              label: actionLabel!,
              icon: actionIcon,
              onPressed: onAction,
              height: 46.h,
              fontSize: 14.sp,
            ),
          ],
        ],
      ),
    );
  }
}
