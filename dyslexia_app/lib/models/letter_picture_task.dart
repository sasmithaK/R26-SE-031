/// Picture-Sound Mapping for Phonological Awareness Task
/// Each letter has 3 pictures: correct (starts with that sound) and 2 distractors

class PictureOption {
  final String sinhalaWord; // The Sinhala word displayed/understood
  final String imagePath; // Path to the image
  final bool isCorrect; // Is this the correct option for this letter?

  PictureOption({
    required this.sinhalaWord,
    required this.imagePath,
    required this.isCorrect,
  });
}

class LetterPictureTask {
  final String letter; // Sinhala letter (e.g., 'ක')
  final String letterSound; // Sound name for TTS
  final List<PictureOption> pictures; // 3 pictures (1 correct, 2 distractors)
  
  LetterPictureTask({
    required this.letter,
    required this.letterSound,
    required this.pictures,
  });

  /// Get the correct picture
  PictureOption get correctPicture => pictures.firstWhere((p) => p.isCorrect);

  /// Randomize picture order for the UI
  List<PictureOption> getRandomizedPictures() {
    final shuffled = List<PictureOption>.from(pictures);
    shuffled.shuffle();
    return shuffled;
  }
}

/// Phonological Awareness Picture Database for Sinhala Letters
class LetterPictureDatabase {
  static final List<LetterPictureTask> tasks = [
    // ක - කපුටා (crow), කඩම (cadamb fruit), කිරි (milk)
    LetterPictureTask(
      letter: 'ක',
      letterSound: 'ka',
      pictures: [
        PictureOption(
          sinhalaWord: 'කපුටා', // crow
          imagePath: 'assets/images/gole.jpg',
          isCorrect: true,
        ),
        PictureOption(
          sinhalaWord: 'බල්ලා', // dog
          imagePath: 'assets/images/elephant.png', // placeholder
          isCorrect: false,
        ),
        PictureOption(
          sinhalaWord: 'මල', // flower
          imagePath: 'assets/images/download.jpg',
          isCorrect: false,
        ),
      ],
    ),
    
    // අ - අලියා (elephant), ඇඩ (ladder), අරු (wheat)
    LetterPictureTask(
      letter: 'අ',
      letterSound: 'ah',
      pictures: [
        PictureOption(
          sinhalaWord: 'අලියා', // elephant
          imagePath: 'assets/images/elephant.png',
          isCorrect: true,
        ),
        PictureOption(
          sinhalaWord: 'බල්ලා', // dog
          imagePath: 'assets/images/tree_character.png', // placeholder
          isCorrect: false,
        ),
        PictureOption(
          sinhalaWord: 'කපුටා', // crow
          imagePath: 'assets/images/gole.jpg',
          isCorrect: false,
        ),
      ],
    ),

    // ම - මල (flower), මීයා (fish), මුතු (pearl)
    LetterPictureTask(
      letter: 'ම',
      letterSound: 'ma',
      pictures: [
        PictureOption(
          sinhalaWord: 'මල', // flower
          imagePath: 'assets/images/download.jpg',
          isCorrect: true,
        ),
        PictureOption(
          sinhalaWord: 'අලියා', // elephant
          imagePath: 'assets/images/elephant.png',
          isCorrect: false,
        ),
        PictureOption(
          sinhalaWord: 'කපුටා', // crow
          imagePath: 'assets/images/gole.jpg',
          isCorrect: false,
        ),
      ],
    ),

    // ඉ - ඉර (sun/ray), ඉතුරු (remainder), ඉතා (very)
    LetterPictureTask(
      letter: 'ඉ',
      letterSound: 'i',
      pictures: [
        PictureOption(
          sinhalaWord: 'ඉර', // sun
          imagePath: 'assets/images/HappySunshineClipart.jpg',
          isCorrect: true,
        ),
        PictureOption(
          sinhalaWord: 'මල', // flower
          imagePath: 'assets/images/download.jpg',
          isCorrect: false,
        ),
        PictureOption(
          sinhalaWord: 'අලියා', // elephant
          imagePath: 'assets/images/elephant.png',
          isCorrect: false,
        ),
      ],
    ),

    // බ - බල්ලා (dog), බඩ (stomach), බිම (ground)
    LetterPictureTask(
      letter: 'බ',
      letterSound: 'ba',
      pictures: [
        PictureOption(
          sinhalaWord: 'බල්ලා', // dog
          imagePath: 'assets/images/apple_character.png', // placeholder - update with dog image
          isCorrect: true,
        ),
        PictureOption(
          sinhalaWord: 'ඉර', // sun
          imagePath: 'assets/images/HappySunshineClipart.jpg',
          isCorrect: false,
        ),
        PictureOption(
          sinhalaWord: 'කපුටා', // crow
          imagePath: 'assets/images/gole.jpg',
          isCorrect: false,
        ),
      ],
    ),

    // ර - රිටින්ගම (ring), රට (country), රතු (red)
    LetterPictureTask(
      letter: 'ර',
      letterSound: 'ra',
      pictures: [
        PictureOption(
          sinhalaWord: 'රිටින්ගම', // ring
          imagePath: 'assets/images/welcome_owl.png', // placeholder
          isCorrect: true,
        ),
        PictureOption(
          sinhalaWord: 'මල', // flower
          imagePath: 'assets/images/download.jpg',
          isCorrect: false,
        ),
        PictureOption(
          sinhalaWord: 'බල්ලා', // dog
          imagePath: 'assets/images/apple_character.png',
          isCorrect: false,
        ),
      ],
    ),

    // ස - සිරුවා (bird), සර්ප (snake), සබ (soap)
    LetterPictureTask(
      letter: 'ස',
      letterSound: 'sa',
      pictures: [
        PictureOption(
          sinhalaWord: 'සිරුවා', // bird
          imagePath: 'assets/images/gole.jpg',
          isCorrect: true,
        ),
        PictureOption(
          sinhalaWord: 'අලියා', // elephant
          imagePath: 'assets/images/elephant.png',
          isCorrect: false,
        ),
        PictureOption(
          sinhalaWord: 'ඉර', // sun
          imagePath: 'assets/images/HappySunshineClipart.jpg',
          isCorrect: false,
        ),
      ],
    ),
  ];

  /// Get a picture task for a letter
  static LetterPictureTask? getTaskForLetter(String letter) {
    try {
      return tasks.firstWhere((task) => task.letter == letter);
    } catch (e) {
      return null;
    }
  }
}
