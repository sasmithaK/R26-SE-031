class TypographyConfig {
  final double fontSize;
  final String fontFamily;
  final double letterSpacing;
  final double wordSpacing;
  final double lineHeight;
  final String backgroundContrast;
  final double diacriticOffset;
  final double glyphPadding;

  TypographyConfig({
    this.fontSize = 20.0,
    this.fontFamily = 'NotoSansSinhala',
    this.letterSpacing = 2.0,
    this.wordSpacing = 8.0,
    this.lineHeight = 1.6,
    this.backgroundContrast = 'WCAG_AA',
    this.diacriticOffset = 0.0,
    this.glyphPadding = 0.0,
  });

  factory TypographyConfig.fromJson(Map<String, dynamic> json) {
    return TypographyConfig(
      fontSize: (json['font_size'] as num?)?.toDouble() ?? 20.0,
      fontFamily: json['font_family'] as String? ?? 'NotoSansSinhala',
      letterSpacing: (json['letter_spacing'] as num?)?.toDouble() ?? 2.0,
      wordSpacing: (json['word_spacing'] as num?)?.toDouble() ?? 8.0,
      lineHeight: (json['line_height'] as num?)?.toDouble() ?? 1.6,
      backgroundContrast: json['background_contrast'] as String? ?? 'WCAG_AA',
      diacriticOffset: (json['diacritic_offset'] as num?)?.toDouble() ?? 0.0,
      glyphPadding: (json['glyph_padding'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class TypographyResponse {
  final String studentId;
  final int armSelected;
  final TypographyConfig config;
  final bool gameModeTrigger;
  final int gameDifficulty;

  TypographyResponse({
    required this.studentId,
    required this.armSelected,
    required this.config,
    this.gameModeTrigger = false,
    this.gameDifficulty = 2,
  });

  factory TypographyResponse.fromJson(Map<String, dynamic> json) {
    return TypographyResponse(
      studentId: json['student_id'] as String,
      armSelected: json['linucb_arm_selected'] as int,
      config: TypographyConfig.fromJson(json['typography_config'] as Map<String, dynamic>),
      gameModeTrigger: json['game_mode_trigger'] as bool? ?? false,
      gameDifficulty: json['game_difficulty'] as int? ?? 2,
    );
  }
}
