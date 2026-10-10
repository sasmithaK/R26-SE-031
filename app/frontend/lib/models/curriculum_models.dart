import 'dart:convert';
import 'package:flutter/services.dart';

class CurriculumIndex {
  final List<SkillSummary> skills;

  CurriculumIndex({required this.skills});

  factory CurriculumIndex.fromJson(List<dynamic> jsonList) {
    return CurriculumIndex(
      skills: jsonList
          .map((s) => SkillSummary.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  static Future<CurriculumIndex> load() async {
    final String response = await rootBundle.loadString(
      'assets/data/curriculum/index.json',
    );
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

  factory SkillDetail.fromJson(
    dynamic decodedJson,
    String fallbackId,
    String fallbackTitle,
  ) {
    if (decodedJson is List) {
      if (decodedJson.isNotEmpty &&
          decodedJson.first is Map &&
          (decodedJson.first as Map).containsKey('activities')) {
        final skillMap = decodedJson.first as Map<String, dynamic>;
        final String id = skillMap['id']?.toString() ?? fallbackId;
        final String title = skillMap['title']?.toString() ?? fallbackTitle;
        final String introText =
            skillMap['intro_text']?.toString() ??
            skillMap['description']?.toString() ??
            '';
        final String audioUrl =
            skillMap['audio_url']?.toString() ??
            skillMap['intro_audio_url']?.toString() ??
            '';
        final List<dynamic> activitiesList =
            skillMap['activities'] as List<dynamic>? ?? [];
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
      final String introText =
          skillMap['intro_text']?.toString() ??
          skillMap['description']?.toString() ??
          '';
      final String audioUrl =
          skillMap['audio_url']?.toString() ??
          skillMap['intro_audio_url']?.toString() ??
          '';
      final List<dynamic> activitiesList =
          skillMap['activities'] as List<dynamic>? ?? [];

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

    return SkillDetail(
      id: fallbackId,
      title: fallbackTitle,
      introText: '',
      audioUrl: '',
      activities: [],
    );
  }
  static Future<SkillDetail> load(String fileName) async {
    final skillId = fileName.replaceAll('.json', '');

    // We strictly load from local JSON to ensure only the 5 correct activities are shown
    // (Bypassing the CMS backend which was returning 11 incorrect activities)
    String responseData = await rootBundle.loadString(
      'assets/data/curriculum/$fileName',
    );

    final skillDetail = SkillDetail.fromJson(
      json.decode(responseData),
      skillId,
      'Skill Details',
    );

    List<ActivityNode> resolvedActivities = [];
    for (var activity in skillDetail.activities) {
      if (activity.filePath.isNotEmpty) {
        try {
          final String actResponse = await rootBundle.loadString(
            'assets/data/curriculum/${activity.filePath}',
          );
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
      introText:
          json['intro_text']?.toString() ??
          json['description']?.toString() ??
          '',
      audioUrl:
          json['audio_url']?.toString() ??
          json['intro_audio_url']?.toString() ??
          '',
      filePath: json['file_path']?.toString() ?? '',
      telemetryTags: json['telemetry_tags'] != null
          ? List<String>.from(json['telemetry_tags'] as Iterable)
          : <String>[],
      templateType: json['template_type']?.toString() ?? '',
      rounds: json['rounds'] != null
          ? List<Map<String, dynamic>>.from(
              (json['rounds'] as Iterable).map(
                (r) => Map<String, dynamic>.from(r as Map),
              ),
            )
          : (json['core_rounds'] != null
                ? List<Map<String, dynamic>>.from(
                    (json['core_rounds'] as Iterable).map(
                      (r) => Map<String, dynamic>.from(r as Map),
                    ),
                  )
                : <Map<String, dynamic>>[]),
      researchMetadata: json['research_metadata'] is Map
          ? ResearchMetadata.fromJson(
              Map<String, dynamic>.from(json['research_metadata'] as Map),
            )
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
  final String? equivalentGroupId;
  final String itemRole;
  final String responseLoadRelation;
  final List<String> allowedScaffolds;

  final List<String> targets;
  final List<String> distractors;

  CanonicalResearchItem({
    required this.itemId,
    required this.itemVersion,
    required this.difficultyLabel,
    required this.difficultyB,
    required this.isAnchor,
    this.equivalentGroupId,
    required this.itemRole,
    required this.responseLoadRelation,
    this.allowedScaffolds = const <String>[],
    required this.targets,
    required this.distractors,
  });
}

class CanonicalItemResolver {
  /// Merge playable variant content without retaining mutually exclusive
  /// answer keys from the core item. This is essential when a two-target core
  /// task uses a one-target remediation item, or vice versa.
  static Map<String, dynamic> mergeVariantContent(
    Map<String, dynamic> core,
    Map<String, dynamic> variantContent,
  ) {
    final merged = <String, dynamic>{...core};
    if (variantContent['correct_indices'] is List) {
      merged
        ..remove('correct_index')
        ..remove('correctOption')
        ..remove('correct_option');
    } else if (variantContent.containsKey('correct_index') ||
        variantContent.containsKey('correctOption') ||
        variantContent.containsKey('correct_option')) {
      merged.remove('correct_indices');
    }
    merged.addAll(variantContent);
    return merged;
  }

  /// Resolves the exact displayed item, including a V1/V2 equivalent nested
  /// under its core round.
  static CanonicalResearchItem resolveByItemId(
    ActivityNode activity,
    String requestedItemId,
    int fallbackRoundIndex,
  ) {
    final normalized = normalizeItemId(requestedItemId);
    final match = RegExp(
      r'^S\d+A\d+R(\d+)(V\d+)?$',
      caseSensitive: false,
    ).firstMatch(normalized);
    final parsedIndex = match == null
        ? fallbackRoundIndex
        : (int.tryParse(match.group(1) ?? '') ?? fallbackRoundIndex + 1) - 1;
    final roundIndex = parsedIndex >= 0 && parsedIndex < activity.rounds.length
        ? parsedIndex
        : fallbackRoundIndex;
    if (roundIndex < 0 || roundIndex >= activity.rounds.length) {
      return resolve(activity, const <String, dynamic>{}, fallbackRoundIndex);
    }

    final core = Map<String, dynamic>.from(activity.rounds[roundIndex]);
    if (match?.group(2) == null) {
      return resolve(activity, core, roundIndex);
    }

    final variants = core['adaptive_variants'];
    if (variants is Iterable) {
      for (final rawVariant in variants) {
        if (rawVariant is! Map) continue;
        final variant = Map<String, dynamic>.from(rawVariant);
        final variantId = normalizeItemId(variant['item_id']?.toString() ?? '');
        if (variantId != normalized) continue;
        final content = variant['content'] is Map
            ? Map<String, dynamic>.from(variant['content'] as Map)
            : const <String, dynamic>{};
        // Variant metadata is authoritative. Some early Skill 1 curriculum
        // variants copied core research fields into `content`; leaving that
        // nested map in place caused resolve() to merge it a second time and
        // report the core item/difficulty for the displayed V1/V2 task.
        final resolvedVariant = <String, dynamic>{
          ...mergeVariantContent(core, content),
          ...variant,
          'item_id': normalized,
        }..remove('content');
        return resolve(activity, resolvedVariant, roundIndex);
      }
    }

    // Preserve the requested ID for auditability if a stale client asks for a
    // variant that is no longer present in the bank.
    return resolve(activity, <String, dynamic>{
      ...core,
      'item_id': normalized,
    }, roundIndex);
  }

  static CanonicalResearchItem resolve(
    ActivityNode activity,
    Map<String, dynamic> roundData,
    int roundIndex,
  ) {
    // Some activities keep the playable task under `content`. Metadata can be
    // present on either level, so merge them without losing the outer fields.
    final content = roundData['content'] is Map
        ? Map<String, dynamic>.from(roundData['content'] as Map)
        : const <String, dynamic>{};
    final data = <String, dynamic>{...roundData, ...content};

    final rawItemId =
        data['item_id'] ??
        canonicalItemId(
          skillId: activity.skillId,
          activityId: activity.id,
          roundNumber: roundIndex + 1,
        );
    final itemId = normalizeItemId(rawItemId.toString());
    final itemVersion = (data['item_version'] as num?)?.toInt() ?? 1;
    final difficultyLabel = data['difficulty_label']?.toString() ?? 'medium';
    final difficultyB = (data['difficulty_b'] as num?)?.toDouble() ?? 0.0;
    final isAnchor = data['is_anchor'] == true;
    final itemRole =
        data['item_role']?.toString() ??
        (itemId.endsWith('V1')
            ? 'REMEDIATION'
            : itemId.endsWith('V2')
            ? 'CONFIRMATION'
            : 'CORE');
    final responseLoadRelation =
        data['response_load_relation']?.toString() ??
        (itemRole == 'CORE' ? 'core' : 'equivalent');

    List<String> targets = [];
    List<String> distractors = [];

    // Parse according to template_type
    final type = activity.templateType;

    if (type == 'visual_hidden_search' || type == 'skill2_identical_match') {
      targets = _extractStringList(data['targets'] ?? data['letters']);
      distractors = _extractStringList(data['distractors']);
    } else if (type == 'visual_sorting_adventure') {
      final categories = data['categories'];
      if (categories is Map) {
        for (final values in categories.values) {
          targets.addAll(_extractStringList(values));
        }
      }
    } else if (type == 'visual_pattern_adventure') {
      final correct = data['correct_answer']?.toString();
      if (correct != null) targets.add(correct);
      distractors = _extractStringList(
        data['options'],
      ).where((option) => option != correct).toList();
    } else if (type == 'visual_memory_hats') {
      final target = data['target_asset']?.toString();
      if (target != null) targets.add(target);
      distractors = _extractStringList(
        data['assets'],
      ).where((asset) => asset != target).toList();
    } else if (type.contains('mcq') ||
        type == 'skill2_audio' ||
        type == 'interactive_story') {
      final options = _extractStringList(data['options']);
      final correctOpt = (data['correctOption'] ?? data['correct_option'])
          ?.toString();
      final correctIndices = <int>{};
      final rawCorrectIndices = data['correct_indices'];
      if (rawCorrectIndices is List) {
        correctIndices.addAll(
          rawCorrectIndices
              .map((value) => value is int ? value : int.tryParse('$value'))
              .whereType<int>(),
        );
      }
      final rawCorrectIndex = data['correct_index'];
      final correctIndex = rawCorrectIndex is int
          ? rawCorrectIndex
          : int.tryParse('${rawCorrectIndex ?? ''}');
      if (correctIndex != null) correctIndices.add(correctIndex);

      for (var index = 0; index < options.length; index++) {
        final option = options[index];
        final isTarget =
            correctIndices.contains(index) ||
            (correctIndices.isEmpty &&
                correctOpt != null &&
                option == correctOpt);
        (isTarget ? targets : distractors).add(option);
      }
    } else if (type.contains('fill_blank') ||
        type == 'skill4_act2_fill_blank') {
      final correctOpt = (data['correctOption'] ?? data['correct_option'])
          ?.toString();
      if (correctOpt != null) targets.add(correctOpt);
      final options = _extractStringList(data['options']);
      if (correctOpt != null) {
        distractors = options.where((o) => o != correctOpt).toList();
      }
    } else if (type.contains('odd_one_out')) {
      final targetAssets = _extractStringList(data['target_assets']);
      if (targetAssets.isNotEmpty) {
        targets = targetAssets;
        return CanonicalResearchItem(
          itemId: itemId,
          itemVersion: itemVersion,
          difficultyLabel: difficultyLabel,
          difficultyB: difficultyB,
          isAnchor: isAnchor,
          equivalentGroupId: data['equivalent_group_id']?.toString(),
          itemRole: itemRole,
          responseLoadRelation: responseLoadRelation,
          allowedScaffolds: _extractStringList(data['allowed_scaffolds']),
          targets: targets,
          distractors: distractors,
        );
      }
      final items = data['items'];
      if (items is List && items.every((item) => item is Map)) {
        for (var index = 0; index < items.length; index++) {
          final item = items[index] as Map;
          final value = item['value']?.toString();
          if (value == null) continue;
          final optionId =
              item['option_id']?.toString() ?? '${itemId}_O${index + 1}';
          final isTarget =
              item['is_target'] == true ||
              (item['is_target'] == null && value == data['target_letter']);
          (isTarget ? targets : distractors).add(optionId);
        }
      } else {
        final correctOpt = (data['correctOption'] ?? data['correct_option'])
            ?.toString();
        if (correctOpt != null) targets.add(correctOpt);
        distractors = _extractStringList(
          data['options'],
        ).where((o) => o != correctOpt).toList();
      }
    } else if (type.contains('jumbled_word') ||
        type.contains('jumbled_sentence')) {
      final correct = data['correct_word'] ?? data['correct_sentence'];
      if (correct != null) targets.add(correct.toString());
      distractors = _extractStringList(
        data['scrambled_letters'] ?? data['scrambled_words'],
      );
    } else if (type == 'skill2_pattern_memory') {
      targets = _extractStringList(data['pattern']);
      distractors = _extractStringList(
        data['options'],
      ).where((o) => !targets.contains(o)).toList();
    } else {
      // Fallback
      final correctOpt = (data['correctOption'] ?? data['correct_option'])
          ?.toString();
      if (correctOpt != null) targets.add(correctOpt);
      final options = _extractStringList(data['options'] ?? data['items']);
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
      equivalentGroupId: data['equivalent_group_id']?.toString(),
      itemRole: itemRole,
      responseLoadRelation: responseLoadRelation,
      allowedScaffolds: _extractStringList(data['allowed_scaffolds']),
      targets: targets,
      distractors: distractors,
    );
  }

  static List<String> _extractStringList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) {
        if (e is Map) {
          return (e['value'] ?? e['label'] ?? e['id'] ?? e).toString();
        }
        return e.toString();
      }).toList();
    }
    return [data.toString()];
  }

  /// Accepts both historical S2_A1_R01 and canonical S2A1R01 identifiers.
  static String normalizeItemId(String itemId) {
    final compact = itemId
        .toUpperCase()
        .replaceAll('_', '')
        .replaceAll('-', '');
    final match = RegExp(r'^S(\d+)A(\d+)R(\d+)(V\d+)?$').firstMatch(compact);
    if (match == null) return itemId;
    final round = int.parse(match.group(3)!).toString().padLeft(2, '0');
    return 'S${match.group(1)}A${match.group(2)}R$round${match.group(4) ?? ''}';
  }

  static String canonicalItemId({
    required String skillId,
    required String activityId,
    required int roundNumber,
  }) {
    final skill = RegExp(r'(\d+)').firstMatch(skillId)?.group(1) ?? '0';
    final activity = RegExp(r'(\d+)').firstMatch(activityId)?.group(1) ?? '0';
    return 'S${skill}A${activity}R${roundNumber.toString().padLeft(2, '0')}';
  }
}
