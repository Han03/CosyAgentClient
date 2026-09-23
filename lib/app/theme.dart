import 'package:flutter/material.dart';

/// 应用主题：深色专业风（默认深色，避免大面积刺眼配色）。
class AppTheme {
  static const seed = Color(0xFF4F6BFF);

  static ThemeData dark() => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          isDense: true,
        ),
      );
}
