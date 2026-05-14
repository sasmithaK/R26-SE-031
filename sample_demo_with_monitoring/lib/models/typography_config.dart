class TypographyConfig {
  final double fontSize;
  final String fontFamily;
  final double letterSpacing;
  final double wordSpacing;
  final double lineHeight;
  final String backgroundContrast;
  final double diacriticOffset;
  final double glyphPadding;
  final String fontColor; // Added for UI theme alignment

  TypographyConfig({
    required this.fontSize,
    required this.fontFamily,
    required this.letterSpacing,
    required this.wordSpacing,
    required this.lineHeight,
    required this.backgroundContrast,
    required this.diacriticOffset,
    required this.glyphPadding,
    this.fontColor = '#000000',
  });

  factory TypographyConfig.fromJson(Map<String, dynamic> json) {
    return TypographyConfig(
      fontSize: (json['font_size'] ?? 20.0).toDouble(),
      fontFamily: json['font_family'] ?? 'Noto Sans',
      letterSpacing: (json['letter_spacing'] ?? 2.0).toDouble(),
      wordSpacing: (json['word_spacing'] ?? 8.0).toDouble(),
      lineHeight: (json['line_height'] ?? 1.6).toDouble(),
      backgroundContrast: json['background_contrast'] ?? 'WCAG_AA',
      diacriticOffset: (json['diacritic_offset'] ?? 0.0).toDouble(),
      glyphPadding: (json['glyph_padding'] ?? 0.0).toDouble(),
      fontColor: json['font_color'] ?? '#000000',
    );
  }

  factory TypographyConfig.defaultConfig() {
    return TypographyConfig(
      fontSize: 20.0,
      fontFamily: 'Inter',
      letterSpacing: 1.0,
      wordSpacing: 4.0,
      lineHeight: 1.5,
      backgroundContrast: 'WCAG_AA',
      diacriticOffset: 0.0,
      glyphPadding: 0.0,
      fontColor: '#000000',
    );
  }
}

class TypographyResponse {
  final String studentId;
  final int armId;
  final TypographyConfig config;
  final bool gameModeTrigger;

  TypographyResponse({
    required this.studentId,
    required this.armId,
    required this.config,
    required this.gameModeTrigger,
  });

  factory TypographyResponse.fromJson(Map<String, dynamic> json) {
    return TypographyResponse(
      studentId: json['student_id'] ?? '',
      armId: json['linucb_arm_selected'] ?? 0,
      config: TypographyConfig.fromJson(json['typography_config'] ?? {}),
      gameModeTrigger: json['game_mode_trigger'] ?? false,
    );
  }
}
