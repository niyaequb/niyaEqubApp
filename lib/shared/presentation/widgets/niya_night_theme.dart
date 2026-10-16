import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:niya_equb/core/config/app_color.dart';
import 'package:niya_equb/shared/presentation/widgets/niya_style.dart';

/// Paints a whole subtree in the Niya brand look: cards on a plain page,
/// maroon headers and buttons — white and black in light mode, black and a
/// brighter maroon in dark mode.
///
/// (The file keeps its old name so no import changes; the screens it styles
/// used to be navy and gold.)
///
/// WHY THIS EXISTS RATHER THAN A RECOLOURED COPY OF EVERY WIDGET
///
/// Almost every shared widget in this app takes its colours from
/// `colors(context)`, which is `Theme.of(context).extension<AppColors>()!`.
/// That is a ThemeExtension, so swapping it here turns the entire subtree
/// brand-correct at once — the text fields, the ledger cards, the member
/// tiles, the pickers — without editing any of them.
///
/// It follows the phone's light/dark setting like the rest of the app: the
/// colours come from [NiyaSkin], which has a pair for each surface. These
/// screens used to be pinned to the light set, which is why the Equb list and
/// the group screens stayed white while everything around them went black.
///
/// Modal sheets and dialogs come along too. `showModalBottomSheet` and
/// `showDialog` capture the calling context's inherited themes and re-plant
/// them under the navigator, so a sheet opened from inside this subtree is
/// styled the same even though its route is mounted far above it.
///
/// A full-screen route pushed from here does NOT inherit it — `MaterialPageRoute`
/// captures nothing.
class NiyaBrandTheme extends StatelessWidget {
  final Widget child;

  const NiyaBrandTheme({super.key, required this.child});

  /// The brand colours of [skin] as an [AppColors], so a screen that needs a
  /// single colour can read it without building a Theme.
  static AppColors paletteFor(NiyaSkin skin) => AppColors(
    primaryColor: skin.accent,
    accentColor: skin.paper,
    buttonColor: skin.fill,
    buttonTextColor: Colors.white,
    bodyTextColor: skin.ink,
    bodyTextSmallColor: skin.inkSoft,
    titleTextColor: skin.ink,
    hintTextColor: skin.inkFaint,
    borderColor: skin.line,
    scaffoldBackgroundColor: skin.page,
  );

  static ThemeData resolve(BuildContext context) {
    final base = Theme.of(context);
    final skin = niya(context);
    final danger = skin.danger;

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
      ..add(paletteFor(skin));

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: skin.accent,
        onPrimary: Colors.white,
        primaryContainer: skin.rose,
        onPrimaryContainer: skin.isDark ? skin.accent : NiyaPalette.maroonDeep,
        secondary: skin.fill,
        onSecondary: Colors.white,
        surface: skin.paper,
        onSurface: skin.ink,
        onSurfaceVariant: skin.inkSoft,
        surfaceContainerLowest: skin.paper,
        surfaceContainerLow: skin.paper,
        surfaceContainer: skin.paper,
        surfaceContainerHigh: skin.paper,
        surfaceContainerHighest: skin.raised,
        error: danger,
        onError: Colors.white,
        outline: skin.isDark ? const Color(0xFF4A4345) : const Color(0xFFCFC6C8),
        outlineVariant: skin.line,
      ),
      scaffoldBackgroundColor: skin.page,
      canvasColor: skin.paper,
      dividerColor: skin.line,
      unselectedWidgetColor: skin.inkSoft,
      extensions: extensions,
      // Text that does not set its own colour would otherwise keep whatever
      // the ambient theme gave it.
      textTheme: base.textTheme.apply(
        bodyColor: skin.ink,
        displayColor: skin.ink,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: skin.fill,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white, size: 22.r),
        actionsIconTheme: IconThemeData(color: Colors.white, size: 22.r),
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
        fillColor: skin.paper,
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
        hintStyle: TextStyle(color: skin.inkSoft, fontSize: 13.sp),
        labelStyle: TextStyle(color: skin.inkSoft, fontSize: 13.sp),
        floatingLabelStyle: TextStyle(color: skin.accent, fontSize: 13.sp),
        enabledBorder: _border(
          skin.isDark ? skin.line : const Color(0xFFDDD4D6),
        ),
        border: _border(skin.isDark ? skin.line : const Color(0xFFDDD4D6)),
        focusedBorder: _border(skin.accent, width: 1.5),
        disabledBorder: _border(skin.line),
        errorBorder: _border(danger),
        focusedErrorBorder: _border(danger, width: 1.5),
        errorStyle: TextStyle(color: danger, fontSize: 11.sp),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: skin.accent,
        selectionColor: skin.accent.withValues(alpha: 0.22),
        selectionHandleColor: skin.accent,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: skin.accent),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: skin.accent),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: skin.accent,
          side: BorderSide(color: skin.accent.withValues(alpha: 0.6)),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? skin.fill
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: BorderSide(color: skin.inkSoft, width: 1.4),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? skin.accent : skin.inkSoft,
        ),
        overlayColor: WidgetStatePropertyAll(
          skin.accent.withValues(alpha: 0.1),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? skin.accent : skin.inkSoft,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? skin.accent.withValues(alpha: 0.35)
              : skin.line,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: skin.paper,
        modalBackgroundColor: skin.paper,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: ListTileThemeData(
        textColor: skin.ink,
        iconColor: skin.accent,
      ),
      iconTheme: IconThemeData(color: skin.accent),
      dividerTheme: DividerThemeData(color: skin.line, thickness: 1),
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
/// drawn over the page.
///
/// CALL THIS FROM INSIDE [NiyaScaffold]'s `body` BUILDER, nowhere else.
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

/// The shell every Equb group screen wears: the brand theme, the warm white
/// page, a maroon app bar, and an optional bar pinned to the bottom for the
/// screen's main action.
///
/// [body] and [bottomBar] are builders rather than widgets so their content is
/// built from a context that is already underneath the brand theme. Passing a
/// pre-built widget would work for anything that reads the theme in its own
/// build, but silently give the app-wide colours to anything the caller
/// resolved eagerly — `colors(context)` on the line where the widget is
/// constructed is exactly that mistake, and it is invisible until you look at
/// the screen in dark mode.
class NiyaScaffold extends StatelessWidget {
  final String title;
  final WidgetBuilder body;
  final WidgetBuilder? bottomBar;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final bool automaticallyImplyLeading;

  const NiyaScaffold({
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
    return NiyaBrandTheme(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: niyaHeaderOverlay,
        child: Scaffold(
          backgroundColor: niya(context).page,
          // The app bar is opaque now, but the body still starts under it so
          // the screens' top padding (niyaTopInset) stays exactly as it was.
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
          body: Builder(builder: body),
        ),
      ),
    );
  }
}

/// A strip the colour of a card along the bottom edge, with a hairline on
/// top, holding the screen's main action.
class NiyaBottomBar extends StatelessWidget {
  final Widget child;

  const NiyaBottomBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final skin = niya(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: skin.paper,
        border: Border(top: BorderSide(color: skin.line)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: skin.isDark ? 0.45 : 0.06),
            blurRadius: 14,
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

/// The card every panel on these screens is cut from: white, a hairline
/// border and a soft shadow, with the same corner radius as a package row.
class NiyaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  /// A maroon frame, for the one card on a screen that is asking for a
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
    final skin = niya(context);
    final radius = BorderRadius.circular(16.r);
    final inner = Padding(
      padding: padding ?? EdgeInsets.all(14.r),
      child: child,
    );

    return Material(
      color: color ?? skin.paper,
      elevation: skin.isDark ? 0 : 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: radius,
      child: Container(
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: emphasised
                ? skin.accent.withValues(alpha: 0.7)
                : skin.line,
            width: emphasised ? 1.3 : 1,
          ),
        ),
        child: onTap == null
            ? inner
            : InkWell(borderRadius: radius, onTap: onTap, child: inner),
      ),
    );
  }
}

/// A form section's heading: a maroon sparkle, the label, then a rule running
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
    final skin = niya(context);
    final colour = tint ?? skin.accent;

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
              color: skin.ink,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: NiyaRule(thickness: 1, leadsRight: false, color: colour),
        ),
        if (trailing != null) ...[SizedBox(width: 8.w), trailing!],
      ],
    );
  }
}

/// A small status pill: a tinted ground, a half-strength ring and the label
/// in the full colour. Pass a colour dark enough to read on white.
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
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

/// The quiet half of a pair of actions: a maroon outline, maroon text.
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
    final skin = niya(context);
    final radius = BorderRadius.circular(999);
    final colour = tint ?? skin.accent;
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: skin.paper,
          borderRadius: radius,
          border: Border.all(color: colour.withValues(alpha: 0.6)),
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
                        Icon(icon, size: 15.sp, color: colour),
                        SizedBox(width: 6.w),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colour,
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

/// A text field for the Equb screens.
///
/// Deliberately a thin wrapper over [TextFormField] rather than a restyled
/// [CustomTextField]: the borders, fill, label and cursor all come from the
/// `inputDecorationTheme` that [NiyaBrandTheme] installs, so this only has to
/// say what the field is for. Put it under a [NiyaBrandTheme] — on its own it
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
    final skin = niya(context);

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
      cursorColor: skin.accent,
      style: TextStyle(
        color: skin.ink,
        fontSize: 14.sp,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        helperStyle: TextStyle(color: skin.inkSoft, fontSize: 10.5.sp),
        counterStyle: TextStyle(color: skin.inkFaint, fontSize: 10.sp),
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 18.sp, color: skin.accent),
        suffixIcon: suffix,
      ),
    );
  }
}

/// Says what is missing and what to do about it.
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
    final skin = niya(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          NiyaStarBadge(
            size: 86.r,
            child: Icon(icon, size: 34.r, color: skin.accent),
          ),
          SizedBox(height: 18.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: skin.ink,
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: skin.inkSoft,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: 20.h),
            NiyaPrimaryButton(
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
