enum StarterTaskKind {
  imageChoice,
  shadowChoice,
  textChoice,
  audioChoice,
  imageWordChoice,
  audioSequence,
  sentenceChoice,
  sentenceSequence,
}

class StarterChoice {
  final String id;
  final String label;
  final String? imageAsset;

  const StarterChoice({required this.id, required this.label, this.imageAsset});
}

class StarterBaselineTask {
  final String itemId;
  final int skillNumber;
  final StarterTaskKind kind;
  final String prompt;
  final String? helperText;
  final String? promptImageAsset;
  final String? spokenPrompt;
  final List<StarterChoice> choices;
  final List<String> correctAnswerIds;

  const StarterBaselineTask({
    required this.itemId,
    required this.skillNumber,
    required this.kind,
    required this.prompt,
    required this.choices,
    required this.correctAnswerIds,
    this.helperText,
    this.promptImageAsset,
    this.spokenPrompt,
  });

  bool get isSequence =>
      kind == StarterTaskKind.audioSequence ||
      kind == StarterTaskKind.sentenceSequence;

  bool get hasAudio =>
      kind == StarterTaskKind.audioChoice ||
      kind == StarterTaskKind.audioSequence;
}

class StarterBaselineStatus {
  final String status;
  final bool required;
  final String? sessionId;
  final int nextItemIndex;
  final int completedItemCount;
  final int totalItemCount;

  const StarterBaselineStatus({
    required this.status,
    required this.required,
    required this.sessionId,
    required this.nextItemIndex,
    required this.completedItemCount,
    required this.totalItemCount,
  });

  factory StarterBaselineStatus.fromJson(Map<String, dynamic> json) {
    return StarterBaselineStatus(
      status: json['status']?.toString() ?? 'not_started',
      required: json['required'] == true,
      sessionId: json['session_id']?.toString(),
      nextItemIndex: (json['next_item_index'] as num?)?.toInt() ?? 0,
      completedItemCount: (json['completed_item_count'] as num?)?.toInt() ?? 0,
      totalItemCount: (json['total_item_count'] as num?)?.toInt() ?? 8,
    );
  }

  bool get isTerminal =>
      status == 'completed' ||
      status == 'insufficient' ||
      status == 'not_required';
}

/// Returns a stable per-learner order so answer-position preference is not
/// confused with literacy skill, while a resumed task keeps the same layout.
List<StarterChoice> orderedStarterChoices(
  StarterBaselineTask task,
  String learnerKey,
) {
  final choices = List<StarterChoice>.from(task.choices);
  var state = 2166136261;
  for (final unit in '$learnerKey:${task.itemId}'.codeUnits) {
    state = ((state ^ unit) * 16777619) & 0x7fffffff;
  }
  for (var index = choices.length - 1; index > 0; index--) {
    state = (state * 1103515245 + 12345) & 0x7fffffff;
    final swapIndex = state % (index + 1);
    final value = choices[index];
    choices[index] = choices[swapIndex];
    choices[swapIndex] = value;
  }
  return choices;
}

/// Updates an ordered answer without forcing a child to remove a full tray
/// before trying a different option. Replacing the most recent choice is
/// neutral: it does not inspect or reveal the correct answer.
List<String> updateStarterSequenceSelection({
  required List<String> currentSelection,
  required String tappedId,
  required int requiredCount,
}) {
  final nextSelection = List<String>.from(currentSelection);
  if (nextSelection.contains(tappedId)) {
    nextSelection.remove(tappedId);
  } else if (nextSelection.length < requiredCount) {
    nextSelection.add(tappedId);
  } else if (nextSelection.isNotEmpty) {
    nextSelection[nextSelection.length - 1] = tappedId;
  }
  return nextSelection;
}

const starterBaselineTasks = <StarterBaselineTask>[
  StarterBaselineTask(
    itemId: 'BL1S1V01',
    skillNumber: 1,
    kind: StarterTaskKind.imageChoice,
    prompt: 'බල්ලා සොයා තෝරන්න.',
    helperText: 'පින්තූර හොඳින් බලන්න.',
    choices: [
      StarterChoice(
        id: 'cat',
        label: 'පූසා',
        imageAsset: 'assets/images/activity_icons/animals/cat.png',
      ),
      StarterChoice(
        id: 'dog',
        label: 'බල්ලා',
        imageAsset: 'assets/images/activity_icons/animals/dog.png',
      ),
      StarterChoice(
        id: 'cow',
        label: 'ගවයා',
        imageAsset: 'assets/images/activity_icons/animals/cow.png',
      ),
      StarterChoice(
        id: 'rabbit',
        label: 'හාවා',
        imageAsset: 'assets/images/activity_icons/animals/rabbit.png',
      ),
    ],
    correctAnswerIds: ['dog'],
  ),
  StarterBaselineTask(
    itemId: 'BL1S1V02',
    skillNumber: 1,
    kind: StarterTaskKind.shadowChoice,
    prompt: 'සෙවණැල්ලට ගැළපෙන පින්තූරය තෝරන්න.',
    promptImageAsset: 'assets/images/activity_icons/animals/elephant.png',
    choices: [
      StarterChoice(
        id: 'bird',
        label: 'කුරුල්ලා',
        imageAsset: 'assets/images/activity_icons/animals/bird.png',
      ),
      StarterChoice(
        id: 'elephant',
        label: 'අලියා',
        imageAsset: 'assets/images/activity_icons/animals/elephant.png',
      ),
      StarterChoice(
        id: 'turtle',
        label: 'ඉබ්බා',
        imageAsset: 'assets/images/activity_icons/animals/turtle.png',
      ),
      StarterChoice(
        id: 'fish',
        label: 'මාළුවා',
        imageAsset: 'assets/images/activity_icons/animals/fish.png',
      ),
    ],
    correctAnswerIds: ['elephant'],
  ),
  StarterBaselineTask(
    itemId: 'BL1S2L01',
    skillNumber: 2,
    kind: StarterTaskKind.textChoice,
    prompt: 'අ අකුර තෝරන්න.',
    choices: [
      StarterChoice(id: 'ම', label: 'ම'),
      StarterChoice(id: 'අ', label: 'අ'),
      StarterChoice(id: 'ක', label: 'ක'),
    ],
    correctAnswerIds: ['අ'],
  ),
  StarterBaselineTask(
    itemId: 'BL1S2L02',
    skillNumber: 2,
    kind: StarterTaskKind.audioChoice,
    prompt: 'ඇසෙන අකුර තෝරන්න.',
    helperText: 'ශබ්දය නැවත අහන්න පුළුවන්.',
    spokenPrompt: 'කා අකුර තෝරන්න.',
    choices: [
      StarterChoice(id: 'ග', label: 'ග'),
      StarterChoice(id: 'කා', label: 'කා'),
      StarterChoice(id: 'ත', label: 'ත'),
      StarterChoice(id: 'පා', label: 'පා'),
    ],
    correctAnswerIds: ['කා'],
  ),
  StarterBaselineTask(
    itemId: 'BL1S3W01',
    skillNumber: 3,
    kind: StarterTaskKind.imageWordChoice,
    prompt: 'පින්තූරයට ගැළපෙන වචනය තෝරන්න.',
    promptImageAsset: 'assets/images/activity_icons/plants/tree.png',
    choices: [
      StarterChoice(id: 'ගල', label: 'ගල'),
      StarterChoice(id: 'ගස', label: 'ගස'),
      StarterChoice(id: 'කට', label: 'කට'),
    ],
    correctAnswerIds: ['ගස'],
  ),
  StarterBaselineTask(
    itemId: 'BL1S3W02',
    skillNumber: 3,
    kind: StarterTaskKind.audioSequence,
    prompt: 'ඇසෙන වචනය අකුරුවලින් සකසන්න.',
    spokenPrompt: 'මාල. මාල වචනය සකසන්න.',
    choices: [
      StarterChoice(id: 'ල', label: 'ල'),
      StarterChoice(id: 'ත', label: 'ත'),
      StarterChoice(id: 'මා', label: 'මා'),
    ],
    correctAnswerIds: ['මා', 'ල'],
  ),
  StarterBaselineTask(
    itemId: 'BL1S4S01',
    skillNumber: 4,
    kind: StarterTaskKind.sentenceChoice,
    prompt: 'පින්තූරයට ගැළපෙන වාක්‍යය තෝරන්න.',
    promptImageAsset: 'assets/images/games/dog_running.png',
    choices: [
      StarterChoice(id: 'බල්ලා දුවනවා.', label: 'බල්ලා දුවනවා.'),
      StarterChoice(id: 'පූසා නිදියනවා.', label: 'පූසා නිදියනවා.'),
    ],
    correctAnswerIds: ['බල්ලා දුවනවා.'],
  ),
  StarterBaselineTask(
    itemId: 'BL1S4S02',
    skillNumber: 4,
    kind: StarterTaskKind.sentenceSequence,
    prompt: 'පින්තූරයට ගැළපෙන වාක්‍යය සකසන්න.',
    promptImageAsset: 'assets/images/games/girl_going_to_school.png',
    choices: [
      StarterChoice(id: 'යනවා', label: 'යනවා'),
      StarterChoice(id: 'ගසට', label: 'ගසට'),
      StarterChoice(id: 'පවනි', label: 'පවනි'),
      StarterChoice(id: 'පාසල්', label: 'පාසල්'),
    ],
    correctAnswerIds: ['පවනි', 'පාසල්', 'යනවා'],
  ),
];
