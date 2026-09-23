import 'package:flutter/material.dart';

/// 应用主题：仿豆包风格。
/// 品牌蓝 + 蓝紫渐变 + 大圆角 + 柔和填充式输入框。
/// 提供深/浅两套主题，默认深色。
class AppTheme {
  // ---- 品牌色 ----
  static const brand = Color(0xFF3370FF);
  static const brandDeep = Color(0xFF1F4FE0);
  static const gradientStart = Color(0xFF4D7CFF);
  static const gradientEnd = Color(0xFF6C5CE7);

  // ---- 圆角体系 ----
  static const radiusSm = 10.0;
  static const radiusMd = 14.0;
  static const radiusLg = 20.0;

  // ---- 渐变按钮 ----
  static LinearGradient get brandGradient => const LinearGradient(
        colors: [gradientStart, gradientEnd],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  // ---- 深色 ----
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.dark,
    ).copyWith(
      primary: brand,
      surface: const Color(0xFF1A1B20),
      surfaceContainerLowest: const Color(0xFF121317),
      surfaceContainerLow: const Color(0xFF1E1F25),
      surfaceContainer: const Color(0xFF23242B),
      surfaceContainerHigh: const Color(0xFF2A2B33),
      surfaceContainerHighest: const Color(0xFF32333C),
      onSurface: const Color(0xFFECECEF),
      onSurfaceVariant: const Color(0xFFA6A7B0),
      outline: const Color(0xFF3A3B44),
    );
    return _base(Brightness.dark, scheme);
  }

  // ---- 浅色 ----
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
    ).copyWith(
      primary: brand,
      surface: const Color(0xFFF7F8FA),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFEFF0F4),
      surfaceContainer: const Color(0xFFE8E9EE),
      surfaceContainerHigh: const Color(0xFFE1E2E8),
      surfaceContainerHighest: const Color(0xFFD8D9E0),
      onSurface: const Color(0xFF191A20),
      onSurfaceVariant: const Color(0xFF6B6D76),
      outline: const Color(0xFFD5D6DC),
    );
    return _base(Brightness.light, scheme);
  }

  static ThemeData _base(Brightness brightness, ColorScheme scheme) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF121317) : const Color(0xFFF2F3F6),
      // AppBar：透明无分割线
      appBarTheme: AppBarTheme(
        backgroundColor:
            dark ? const Color(0xFF121317) : const Color(0xFFF2F3F6),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      // 输入框：填充式大圆角（豆包风）
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      // 卡片：大圆角无阴影
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      // 列表项：圆角
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radiusMd)),
        ),
      ),
      // 底部导航
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark
            ? const Color(0xFF1A1B20)
            : const Color(0xFFFFFFFF),
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        height: 64,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: scheme.onSurfaceVariant,
        )),
        iconTheme: WidgetStatePropertyAll(IconThemeData(
          color: scheme.onSurfaceVariant,
        )),
      ),
      // 分割线
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.6),
        space: 1,
        thickness: 0.6,
      ),
      // 消息气泡默认圆角
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
      ),
    );
  }
}
