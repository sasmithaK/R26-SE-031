import 'package:flutter/material.dart';
import 'package:dyslexia_app/services/difficulty_profile_service.dart';
import 'package:dyslexia_app/widgets/skip_button.dart';

class StoryCard {
  final String imagePath;
  final String description;
  final int correctPosition;
  late int currentPosition;

  StoryCard({
    required this.imagePath,
    required this.description,
    required this.correctPosition,
  }) {
    currentPosition = correctPosition;
  }
}

class StorySequencingGame extends StatefulWidget {
  const StorySequencingGame({super.key});

  @override
  State<StorySequencingGame> createState() => _StorySequencingGameState();
}

class _StorySequencingGameState extends State<StorySequencingGame> {
  late List<StoryCard> cards;
  late List<StoryCard?> sequenceOrder;
  bool isCorrect = false;
  bool showCelebration = false;

  @override
  void initState() {
    super.initState();
    initializeGame();
  }

  void initializeGame() {
    final allCards = [
      StoryCard(
        imagePath: 'assets/images/BeanSticker.jpg',
        description: 'බිම ගැසීම',
        correctPosition: 0,
      ),
      StoryCard(
        imagePath: 'assets/images/planting.jpg',
        description: 'බීජ පැතිරීම',
        correctPosition: 1,
      ),
      StoryCard(
        imagePath: 'assets/images/watering.png',
        description: 'ජලය දැමීම',
        correctPosition: 2,
      ),
      StoryCard(
        imagePath: 'assets/images/finalplant.jpg',
        description: 'නටුනු වර්ධනය',
        correctPosition: 3,
      ),
    ];

    final cardCount = DifficultyProfileService.countForLevel(
      DifficultyProfileService.cachedStartingGameLevel,
      2,
      allCards.length,
    );
    cards = allCards.take(cardCount).toList();

    for (var i = 0; i < cards.length; i++) {
      cards[i] = StoryCard(
        imagePath: cards[i].imagePath,
        description: cards[i].description,
        correctPosition: i,
      );
    }

    // Shuffle the cards
    cards.shuffle();

    // Initialize sequence order as empty
    sequenceOrder = List<StoryCard?>.filled(cards.length, null);
    isCorrect = false;
    showCelebration = false;
  }

  void placeCard(StoryCard card, int position) {
    setState(() {
      // Remove card from any existing position
      for (int i = 0; i < sequenceOrder.length; i++) {
        if (sequenceOrder[i] == card) {
          sequenceOrder[i] = null;
        }
      }
      // Place card in new position
      sequenceOrder[position] = card;

      // Check if sequence is correct
      checkSequence();
    });
  }

  void checkSequence() {
    bool allFilled = sequenceOrder.every((card) => card != null);
    if (allFilled) {
      bool correctSequence = true;
      for (int i = 0; i < sequenceOrder.length; i++) {
        if (sequenceOrder[i]!.correctPosition != i) {
          correctSequence = false;
          break;
        }
      }
      if (correctSequence) {
        isCorrect = true;
        showCelebration = true;
      }
    }
  }

  void resetGame() {
    setState(() {
      initializeGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1), // Warm cream background
      appBar: AppBar(
        title: const Text(
          'කතාවේ අනුපිළිවෙල සකස් කරන්න',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(0xFF4CAF50), // Green
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [SkipButton(taskName: 'story_sequencing', onSkipped: resetGame)],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title
              Text(
                'සිතුවම් එකතු කර කතාව සකස් කරන්න',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Shuffled cards section
              Text(
                'ඉහත සිතුවම් තෝරන්න:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF558B2F),
                ),
              ),
              const SizedBox(height: 16),

              // Cards in a row (shuffled)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards.map((card) {
                    bool isPlaced = sequenceOrder.contains(card);
                    return GestureDetector(
                      onTap: !isPlaced
                          ? () {
                              // Show dialog to choose position
                              showPositionDialog(card);
                            }
                          : null,
                      child: Opacity(
                        opacity: isPlaced ? 0.4 : 1.0,
                        child: Container(
                          width: 100,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF81C784),
                              width: 3,
                            ),
                            boxShadow: !isPlaced
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF4CAF50)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                card.imagePath,
                                height: 70,
                                fit: BoxFit.cover,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card.description,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),

              // Sequence arrangement section
              Text(
                'සිතුවම් සකස් කරන්න:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF558B2F),
                ),
              ),
              const SizedBox(height: 16),

              // slots for arrangement
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF81C784),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildSequenceSlot(0),
                        if (sequenceOrder.length > 1) _buildSequenceSlot(1),
                      ],
                    ),
                    if (sequenceOrder.length > 2) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildSequenceSlot(2),
                          if (sequenceOrder.length > 3) _buildSequenceSlot(3),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Celebration message
              if (isCorrect && showCelebration)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF4CAF50),
                      width: 3,
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        '🎉 සුපිරිසිඳු! 🎉',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'ඔබ කතාව සම්පූර්ණ කිරීවි!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Reset button
              ElevatedButton.icon(
                onPressed: resetGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 6,
                ),
                icon: const Icon(Icons.refresh, size: 28),
                label: const Text(
                  'නැවත උත්සාහ කරන්න',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSequenceSlot(int position) {
    StoryCard? card = sequenceOrder[position];
    Color bgColor = [
      const Color(0xFFFFE082), // Yellow
      const Color(0xFF81C784), // Green
      const Color(0xFF64B5F6), // Blue
      const Color(0xFFFF8A80), // Red
    ][position];

    return GestureDetector(
      onTap: card != null
          ? () {
              setState(() {
                sequenceOrder[position] = null;
              });
            }
          : null,
      child: Container(
        width: 110,
        height: 140,
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.3),
          border: Border.all(
            color: bgColor,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: card != null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${position + 1}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: bgColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Image.asset(
                    card.imagePath,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    card.description,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              )
            : Center(
                child: Text(
                  '${position + 1}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: bgColor,
                  ),
                ),
              ),
      ),
    );
  }

  void showPositionDialog(StoryCard card) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF8E1),
          title: const Text(
            'අනුපිළිවෙල තෝරන්න',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2E7D32),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              sequenceOrder.length,
              (index) {
                Color bgColor = [
                  const Color(0xFFFFE082), // Yellow
                  const Color(0xFF81C784), // Green
                  const Color(0xFF64B5F6), // Blue
                  const Color(0xFFFF8A80), // Red
                ][index];

                bool isOccupied = sequenceOrder[index] != null;

                return GestureDetector(
                  onTap: !isOccupied
                      ? () {
                          placeCard(card, index);
                          Navigator.pop(context);
                        }
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor.withOpacity(0.3),
                        border: Border.all(
                          color: bgColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isOccupied
                                  ? 'ඉතිරි (ගිණුම ඉතිරි)'
                                  : 'අනුපිළිවෙල ${index + 1}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isOccupied
                                    ? Colors.grey
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
