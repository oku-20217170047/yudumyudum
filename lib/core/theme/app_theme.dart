import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final light = FlexThemeData.light(
    scheme: FlexScheme.deepBlue,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 12,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 10,
      blendOnColors: false,
      useTextTheme: true,
      defaultRadius: 18,
      elevatedButtonRadius: 18,
      inputDecoratorRadius: 18,
      cardRadius: 22,
      navigationBarIndicatorRadius: 18,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    useMaterial3: true,
  );

  static final dark = FlexThemeData.dark(
    scheme: FlexScheme.deepBlue,
    surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
    blendLevel: 18,
    subThemesData: const FlexSubThemesData(
      blendOnLevel: 18,
      useTextTheme: true,
      defaultRadius: 18,
      elevatedButtonRadius: 18,
      inputDecoratorRadius: 18,
      cardRadius: 22,
      navigationBarIndicatorRadius: 18,
    ),
    textTheme: GoogleFonts.interTextTheme(),
    useMaterial3: true,
  );
}
