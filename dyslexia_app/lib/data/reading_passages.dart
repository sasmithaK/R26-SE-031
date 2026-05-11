class ReadingPassage {
  final String id;
  final String sinhalaText;     // full passage text
  final List<String> sentences; // split for word-tap tracking
  final String topic;
  final String emoji;
  final String englishHint;     // for teacher reference only
  final int wordCount;

  const ReadingPassage({
    required this.id,
    required this.sinhalaText,
    required this.sentences,
    required this.topic,
    required this.emoji,
    required this.englishHint,
    required this.wordCount,
  });
}

const List<ReadingPassage> grade1Passages = [
  ReadingPassage(
    id: 'g1_p01',
    emoji: '🐶',
    topic: 'සතුන්',
    wordCount: 8,
    englishHint: 'The dog is at home. The dog is eating food.',
    sinhalaText: 'බල්ලා ගෙදර ඉන්නවා.\nබල්ලා කෑම කනවා.',
    sentences: [
      'බල්ලා ගෙදර ඉන්නවා.',
      'බල්ලා කෑම කනවා.',
    ],
  ),
  ReadingPassage(
    id: 'g1_p02',
    emoji: '👩',
    topic: 'පවුල',
    wordCount: 9,
    englishHint: 'Mother is at home. Mother is making food. Mother is kind.',
    sinhalaText: 'අම්මා ගෙදර ඉන්නවා.\nඅම්මා කෑම හදනවා.\nඅම්මා හොඳයි.',
    sentences: [
      'අම්මා ගෙදර ඉන්නවා.',
      'අම්මා කෑම හදනවා.',
      'අම්මා හොඳයි.',
    ],
  ),
  ReadingPassage(
    id: 'g1_p03',
    emoji: '🌸',
    topic: 'ස්වභාවය',
    wordCount: 8,
    englishHint: 'Flowers bloomed. Flowers are beautiful. Flowers are red.',
    sinhalaText: 'මල් පිපිලා.\nමල් ලස්සනයි.\nමල් රතුයි.',
    sentences: [
      'මල් පිපිලා.',
      'මල් ලස්සනයි.',
      'මල් රතුයි.',
    ],
  ),
  ReadingPassage(
    id: 'g1_p04',
    emoji: '🌳',
    topic: 'ස්වභාවය',
    wordCount: 8,
    englishHint: 'The tree is tall. There are flowers on the tree. The tree is beautiful.',
    sinhalaText: 'ගස මහතයි.\nගසේ මල් තිබේ.\nගස ලස්සනයි.',
    sentences: [
      'ගස මහතයි.',
      'ගසේ මල් තිබේ.',
      'ගස ලස්සනයි.',
    ],
  ),
  ReadingPassage(
    id: 'g1_p05',
    emoji: '🐔',
    topic: 'සතුන්',
    wordCount: 9,
    englishHint: 'The hen is in the yard. The hen lays eggs. The hen eats food.',
    sinhalaText: 'කුකුළා මළුවේ ඉන්නවා.\nකුකුළා බිත්තර දෙනවා.\nකුකුළා කෑම කනවා.',
    sentences: [
      'කුකුළා මළුවේ ඉන්නවා.',
      'කුකුළා බිත්තර දෙනවා.',
      'කුකුළා කෑම කනවා.',
    ],
  ),
  ReadingPassage(
    id: 'g1_p06',
    emoji: '🏫',
    topic: 'පාසල',
    wordCount: 9,
    englishHint: 'I go to school. The teacher teaches. I read books.',
    sinhalaText: 'මම පාසලට යනවා.\nගුරුතුමිය ඉගැන්වෙනවා.\nමම පොත් කියවනවා.',
    sentences: [
      'මම පාසලට යනවා.',
      'ගුරුතුමිය ඉගැන්වෙනවා.',
      'මම පොත් කියවනවා.',
    ],
  ),
  ReadingPassage(
    id: 'g1_p07',
    emoji: '🐱',
    topic: 'සතුන්',
    wordCount: 8,
    englishHint: 'The cat is small. The cat drinks milk. The cat sleeps.',
    sinhalaText: 'පූසා කුඩාය.\nපූසා කිරි බොනවා.\nපූසා නිදනවා.',
    sentences: [
      'පූසා කුඩාය.',
      'පූසා කිරි බොනවා.',
      'පූසා නිදනවා.',
    ],
  ),
  ReadingPassage(
    id: 'g1_p08',
    emoji: '☀️',
    topic: 'දිනය',
    wordCount: 9,
    englishHint: 'The sun rises in the morning. Children go to school. It is beautiful.',
    sinhalaText: 'උදේ හිරු උදා වෙනවා.\nළමයෝ පාසල් යති.\nදිනය ලස්සනයි.',
    sentences: [
      'උදේ හිරු උදා වෙනවා.',
      'ළමයෝ පාසල් යති.',
      'දිනය ලස්සනයි.',
    ],
  ),
];
