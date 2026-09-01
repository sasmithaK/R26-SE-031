import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/progress_service.dart';
import '../services/student_service.dart';
import '../config/api_config.dart';

class CurriculumIndex {
  final List<SkillSummary> skills;

  CurriculumIndex({required this.skills});

  factory CurriculumIndex.fromJson(List<dynamic> jsonList) {
    return CurriculumIndex(
      skills: jsonList.map((s) => SkillSummary.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }

  static Future<CurriculumIndex> load() async {
    final String response = await rootBundle.loadString('assets/data/curriculum/index.json');
    return CurriculumIndex.fromJson(json.decode(response) as List<dynamic>);
  }
}

class SkillSummary {
  final String id;
  final String title;
  final String subtitle;
  final String icon;
  final String file;
  final int totalActivities;
  final String imagePath;
  final String colorHex;
  final String emoji;
  final String audioUrl;

  SkillSummary({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.file,
    this.totalActivities = 0,
    this.imagePath = 'assets/images/skills/s0.png',
    this.colorHex = '#4A90D9',
    this.emoji = '⭐',
    this.audioUrl = '',
  });

  /// Parses the colorHex string (e.g. "#4A90D9") into a Flutter Color.
  Color get color {
    final hex = colorHex.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  factory SkillSummary.fromJson(Map<String, dynamic> json) {
    return SkillSummary(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['description'] ?? '',
      icon: json['icon'] ?? 'assets/images/skills/s0.png',
      file: json['file_path'] ?? json['file'] ?? '',
      totalActivities: json['total_activities'] ?? 0,
      imagePath: json['image_path'] ?? 'assets/images/skills/s0.png',
      colorHex: json['color_hex'] ?? '#4A90D9',
      emoji: json['emoji'] ?? '⭐',
      audioUrl: json['audio_url'] ?? json['audio_path'] ?? json['audio'] ?? '',
    );
  }
}

class SkillDetail {
  final String id;
  final String title;
  final String introText;
  final String audioUrl;
  final List<ActivityNode> activities;

  SkillDetail({
    required this.id,
    required this.title,
    this.introText = '',
    this.audioUrl = '',
    required this.activities,
  });

  factory SkillDetail.fromJson(dynamic decodedJson, String fallbackId, String fallbackTitle) {
    if (decodedJson is List) {
      if (decodedJson.isNotEmpty &&
          decodedJson.first is Map &&
          (decodedJson.first as Map).containsKey('activities')) {
        final skillMap = decodedJson.first as Map<String, dynamic>;
        final String id = skillMap['id']?.toString() ?? fallbackId;
        final String title = skillMap['title']?.toString() ?? fallbackTitle;
        final String introText = skillMap['intro_text']?.toString() ?? skillMap['description']?.toString() ?? '';
        final String audioUrl = skillMap['audio_url']?.toString() ?? skillMap['intro_audio_url']?.toString() ?? '';
        final List<dynamic> activitiesList = skillMap['activities'] as List<dynamic>? ?? [];
        final parsedActivities = activitiesList
            .map((a) => ActivityNode.fromJson(a as Map<String, dynamic>))
            .toList();
        for (var a in parsedActivities) {
          a.skillTitle = title;
        }
        return SkillDetail(
          id: id,
          title: title,
          introText: introText,
          audioUrl: audioUrl,
          activities: parsedActivities,
        );
      } else {
        final parsedActivities = decodedJson
            .map((a) => ActivityNode.fromJson(a as Map<String, dynamic>))
            .toList();
        for (var a in parsedActivities) {
          a.skillTitle = fallbackTitle;
        }
        return SkillDetail(
          id: fallbackId,
          title: fallbackTitle,
          introText: '',
          audioUrl: '',
          activities: parsedActivities,
        );
      }
    } else if (decodedJson is Map) {
      final skillMap = decodedJson as Map<String, dynamic>;
      final String id = skillMap['id']?.toString() ?? fallbackId;
      final String title = skillMap['title']?.toString() ?? fallbackTitle;
      final String introText = skillMap['intro_text']?.toString() ?? skillMap['description']?.toString() ?? '';
      final String audioUrl = skillMap['audio_url']?.toString() ?? skillMap['intro_audio_url']?.toString() ?? '';
      final List<dynamic> activitiesList = skillMap['activities'] as List<dynamic>? ?? [];
      
      final parsedActivities = activitiesList
          .map((a) => ActivityNode.fromJson(a as Map<String, dynamic>))
          .toList();
      for (var a in parsedActivities) {
        a.skillTitle = title;
      }
      
      return SkillDetail(
        id: id,
        title: title,
        introText: introText,
        audioUrl: audioUrl,
        activities: parsedActivities,
      );
    }

    return SkillDetail(id: fallbackId, title: fallbackTitle, introText: '', audioUrl: '', activities: []);
  }
  static String get _baseUrl {
    return ApiConfig.authBaseUrl;
  }

  static Future<SkillDetail> load(String fileName) async {
    final skillId = fileName.replaceAll('.json', '');
    
    // We strictly load from local JSON to ensure only the 5 correct activities are shown
    // (Bypassing the CMS backend which was returning 11 incorrect activities)
    String responseData = await rootBundle.loadString('assets/data/curriculum/$fileName');

    final skillDetail = SkillDetail.fromJson(json.decode(responseData), skillId, 'Skill Details');

    List<ActivityNode> resolvedActivities = [];
    for (var activity in skillDetail.activities) {
      if (activity.filePath.isNotEmpty) {
        try {
          final String actResponse = await rootBundle.loadString('assets/data/curriculum/${activity.filePath}');
          final Map<String, dynamic> actJson = json.decode(actResponse);
          final resolvedAct = ActivityNode.fromJson(actJson);
          resolvedAct.skillTitle = skillDetail.title;
          resolvedActivities.add(resolvedAct);
        } catch (e) {
          resolvedActivities.add(activity);
        }
      } else {
        resolvedActivities.add(activity);
      }
    }

    for (var act in resolvedActivities) {
      act.skillId = skillDetail.id;
    }

    return SkillDetail(
      id: skillDetail.id,
      title: skillDetail.title,
      introText: skillDetail.introText,
      audioUrl: skillDetail.audioUrl,
      activities: resolvedActivities,
    );
  }
}

class ActivityNode {
  final String id;
  String skillId;
  String skillTitle;
  final String title;
  final String description;
  final String introText;
  final String audioUrl;
  final String filePath;
  final List<String> telemetryTags;
  final String templateType;
  final List<Map<String, dynamic>> rounds;
  final ResearchMetadata? researchMetadata;

  ActivityNode({
    required this.id, 
    this.skillId = '',
    this.skillTitle = '',
    required this.title, 
    this.description = '',
    this.introText = '',
    this.audioUrl = '',
    this.filePath = '',
    required this.telemetryTags, 
    required this.templateType, 
    required this.rounds,
    this.researchMetadata,
  });

  factory ActivityNode.fromJson(Map<String, dynamic> json) {
    return ActivityNode(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      introText: json['intro_text']?.toString() ?? json['description']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString() ?? json['intro_audio_url']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      telemetryTags: json['telemetry_tags'] != null
          ? List<String>.from(json['telemetry_tags'] as Iterable)
          : <String>[],
      templateType: json['template_type']?.toString() ?? '',
      rounds: json['rounds'] != null
          ? List<Map<String, dynamic>>.from(
              (json['rounds'] as Iterable).map((r) => Map<String, dynamic>.from(r as Map)))
          : <Map<String, dynamic>>[],
      researchMetadata: json['research_metadata'] != null 
          ? ResearchMetadata.fromJson(json['research_metadata']) 
          : null,
    );
  }
}

class ResearchMetadata {
  final String knowledgeComponentId;
  final String promptModality;
  final String responseModality;
  final String researchRole;

  ResearchMetadata({
    required this.knowledgeComponentId,
    required this.promptModality,
    required this.responseModality,
    required this.researchRole,
  });

  factory ResearchMetadata.fromJson(Map<String, dynamic> json) {
    return ResearchMetadata(
      knowledgeComponentId: json['knowledge_component_id'] ?? 'KC_UNKNOWN',
      promptModality: json['prompt_modality'] ?? 'visual',
      responseModality: json['response_modality'] ?? 'tap',
      researchRole: json['research_role'] ?? 'primary',
    );
  }
}

class CanonicalResearchItem {
  final String itemId;
  final int itemVersion;
  final String difficultyLabel;
  final double difficultyB;
  final bool isAnchor;
  
  final List<String> targets;
  final List<String> distractors;

  CanonicalResearchItem({
    required this.itemId,
    required this.itemVersion,
    required this.difficultyLabel,
    required this.difficultyB,
    required this.isAnchor,
    required this.targets,
    required this.distractors,
  });
}

class CanonicalItemResolver {
  static CanonicalResearchItem resolve(ActivityNode activity, Map<String, dynamic> roundData, int roundIndex) {
    // Extract standard item metadata injected by python script
    final itemId = roundData['item_id'] ?? '${activity.id}_R${roundIndex + 1}';
    final itemVersion = roundData['item_version'] ?? 1;
    final difficultyLabel = roundData['difficulty_label'] ?? 'medium';
    final difficultyB = (roundData['difficulty_b'] as num?)?.toDouble() ?? 0.0;
    final isAnchor = roundData['is_anchor'] ?? false;

    List<String> targets = [];
    List<String> distractors = [];

    // Parse according to template_type
    final type = activity.templateType;

    if (type == 'visual_hidden_search' || type == 'skill2_identical_match') {
      targets = _extractStringList(roundData['targets'] ?? roundData['letters']);
      distractors = _extractStringList(roundData['distractors']);
    } 
    else if (type.contains('mcq') || type == 'skill2_audio' || type == 'interactive_story') {
      final correctOpt = roundData['correctOption']?.toString();
      if (correctOpt != null) targets.add(correctOpt);
      
      final options = _extractStringList(roundData['options']);
      if (correctOpt != null) {
        distractors = options.where((o) => o != correctOpt).toList();
      } else {
        distractors = options;
      }
    }
    else if (type.contains('fill_blank') || type == 'skill4_act2_fill_blank') {
      final correctOpt = roundData['correctOption']?.toString();
      if (correctOpt != null) targets.add(correctOpt);
      final options = _extractStringList(roundData['options']);
      if (correctOpt != null) {
        distractors = options.where((o) => o != correctOpt).toList();
      }
    }
    else if (type.contains('odd_one_out')) {
      final items = roundData['items'];
      if (items is List && items.every((item) => item is Map)) {
        for (final item in items) {
          final value = item['value']?.toString();
          if (value == null) continue;
          final isTarget = item['is_target'] == true ||
              (item['is_target'] == null && value == roundData['target_letter']);
          (isTarget ? targets : distractors).add(value);
        }
      } else {
        final correctOpt = roundData['correctOption']?.toString();
        if (correctOpt != null) targets.add(correctOpt);
        distractors = _extractStringList(roundData['options'])
            .where((o) => o != correctOpt).toList();
      }
    }
    else if (type.contains('jumbled_word') || type.contains('jumbled_sentence')) {
      final correct = roundData['correct_word'] ?? roundData['correct_sentence'];
      if (correct != null) targets.add(correct.toString());
      distractors = _extractStringList(roundData['scrambled_letters'] ?? roundData['scrambled_words']);
    }
    else if (type == 'skill2_pattern_memory') {
      targets = _extractStringList(roundData['pattern']);
      distractors = _extractStringList(roundData['options']).where((o) => !targets.contains(o)).toList();
    }
    else {
      // Fallback
      final correctOpt = roundData['correctOption']?.toString();
      if (correctOpt != null) targets.add(correctOpt);
      final options = _extractStringList(roundData['options'] ?? roundData['items']);
      if (correctOpt != null) {
        distractors = options.where((o) => o != correctOpt).toList();
      }
    }

    return CanonicalResearchItem(
      itemId: itemId,
      itemVersion: itemVersion,
      difficultyLabel: difficultyLabel,
      difficultyB: difficultyB,
      isAnchor: isAnchor,
      targets: targets,
      distractors: distractors,
    );
  }

  static List<String> _extractStringList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => e.toString()).toList();
    }
    return [data.toString()];
  }
}
