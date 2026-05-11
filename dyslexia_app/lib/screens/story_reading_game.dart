import 'package:flutter/material.dart';
import 'package:dyslexia_app/data/reading_passages.dart';
import 'dart:async';
import 'package:dyslexia_app/services/difficulty_profile_service.dart';
import 'package:characters/characters.dart';

class StoryReadingGame extends StatefulWidget {
  final VoidCallback? onComplete;

  const StoryReadingGame({Key? key, this.onComplete}) : super(key: key);

  @override
  State<StoryReadingGame> createState() => _StoryReadingGameState();
}

class _StoryReadingGameState extends State<StoryReadingGame>
    with TickerProviderStateMixin {
  int currentPassageIndex = 0;
  int currentSentenceIndex = 0;
  List<bool> tappedWords = [];
  Set<int> tappedWordIndices = {};
  int hintsUsed = 0;
  bool showHint = false;
  DateTime sessionStartTime = DateTime.now();
  late AnimationController _highlightController;
  int? highlightedWordIndex;
  // Inactivity timer: if student doesn't tap a word within this duration,
  // switch the first untapped word to letter-by-letter mode.
  Timer? _inactivityTimer;
  final Duration _tapTimeout = const Duration(milliseconds: 3500);
  int? _letterModeWordIndex; // which word index is currently split into letters
  Map<int, int> _letterProgress = {}; // wordIndex -> next letter index to tap

  @override
  void initState() {
    super.initState();
    currentPassageIndex = DifficultyProfileService.startIndexForLevel(
      DifficultyProfileService.cachedStartLevel,
      grade1Passages.length,
    );
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _initializeSentence();
  }

  void _initializeSentence() {
    final sentence = grade1Passages[currentPassageIndex]
        .sentences[currentSentenceIndex];
    final words = sentence.split(' ');
    tappedWords = List.filled(words.length, false);
    tappedWordIndices.clear();
    showHint = false;
    _letterModeWordIndex = null;
    _letterProgress.clear();
    _startInactivityTimer();
  }

  void _onWordTapped(int index) {
    // any interaction resets inactivity timer
    _cancelInactivityTimer();
    setState(() {
      tappedWords[index] = true;
      tappedWordIndices.add(index);
      highlightedWordIndex = index;
    });
    // clear letter-mode if user tapped the word directly
    if (_letterModeWordIndex == index) {
      _letterModeWordIndex = null;
      _letterProgress.remove(index);
    }

    // restart timer for next words
    _startInactivityTimer();

    if (!_highlightController.isAnimating) {
      _highlightController.forward().then((_) {
        if (mounted && !_highlightController.isAnimating) {
          _highlightController.reverse();
        }
      });
    }

    if (tappedWords.every((tapped) => tapped)) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          _moveToNextSentence();
        }
      });
    }
  }

  void _moveToNextSentence() {
    final passage = grade1Passages[currentPassageIndex];
    
    if (currentSentenceIndex < passage.sentences.length - 1) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            currentSentenceIndex++;
            _initializeSentence();
          });
        }
      });
    } else if (currentPassageIndex < grade1Passages.length - 1) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            currentPassageIndex++;
            currentSentenceIndex = 0;
            _initializeSentence();
          });
        }
      });
    } else {
      _showSessionCompleteDialog();
    }
    // ensure timer is running for next sentence
    _startInactivityTimer();
  }

  void _startInactivityTimer() {
    _cancelInactivityTimer();
    _inactivityTimer = Timer(_tapTimeout, () {
      if (!mounted) return;
      // find first untapped word and enable letter-by-letter mode
      final sentence = grade1Passages[currentPassageIndex]
          .sentences[currentSentenceIndex];
      final words = sentence.split(' ');
      for (int i = 0; i < words.length; i++) {
        if (!tappedWords[i]) {
          setState(() {
            _letterModeWordIndex = i;
            _letterProgress[i] = 0;
          });
          break;
        }
      }
    });
  }

  void _cancelInactivityTimer() {
    if (_inactivityTimer != null && _inactivityTimer!.isActive) {
      _inactivityTimer!.cancel();
    }
    _inactivityTimer = null;
  }

  List<String> _extractLetters(String word) {
    // Use Characters to split into user-perceived characters (grapheme clusters).
    final clusters = word.characters.toList();
    final List<String> letters = [];
    for (final cluster in clusters) {
      final trimmed = cluster.trim();
      if (trimmed.isEmpty) continue;
      final firstRune = trimmed.runes.first;
      // Sinhala block: U+0D80..U+0DFF, Latin letters: A-Z,a-z
      if ((firstRune >= 0x0D80 && firstRune <= 0x0DFF) ||
          (firstRune >= 0x0041 && firstRune <= 0x005A) ||
          (firstRune >= 0x0061 && firstRune <= 0x007A)) {
        letters.add(cluster);
      }
    }
    return letters;
  }

  void _onLetterTapped(int wordIndex, int letterIndex) {
    if (!mounted) return;
    // reset inactivity while user interacts with letters
    _cancelInactivityTimer();
    final sentence = grade1Passages[currentPassageIndex]
        .sentences[currentSentenceIndex];
    final words = sentence.split(' ');
    final word = words[wordIndex];
    final letters = _extractLetters(word);
    final expectedIndex = _letterProgress[wordIndex] ?? 0;
    if (letterIndex != expectedIndex) return; // only allow next letter

    setState(() {
      _letterProgress[wordIndex] = expectedIndex + 1;
    });

    // if completed the word (all letters tapped)
    if (_letterProgress[wordIndex]! >= letters.length) {
      // mark word tapped
      setState(() {
        tappedWords[wordIndex] = true;
        tappedWordIndices.add(wordIndex);
        highlightedWordIndex = wordIndex;
        _letterModeWordIndex = null;
        _letterProgress.remove(wordIndex);
      });

      // small highlight animation
      if (!_highlightController.isAnimating) {
        _highlightController.forward().then((_) {
          if (mounted && !_highlightController.isAnimating) {
            _highlightController.reverse();
          }
        });
      }

      // restart timer for next untapped word or sentence progression
      _startInactivityTimer();

      if (tappedWords.every((t) => t)) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _moveToNextSentence();
        });
      }
    }
  }

  void _showSessionCompleteDialog() {
    final duration = DateTime.now().difference(sessionStartTime);
    final totalSeconds = duration.inSeconds;
    final totalWords =
        grade1Passages.fold<int>(0, (sum, p) => sum + p.wordCount);
    final wordsPerMinute =
        totalSeconds > 0 ? ((totalWords / totalSeconds) * 60).toInt() : 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '🎉 පුටුවක්ෂණ සම්පූර්ණයි!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            _buildStatItem('වචන ප්‍රතිඵල', '$wordsPerMinute/min'),
            const SizedBox(height: 12),
            _buildStatItem('ඉඟු භාවිතා කරන ලද', '$hintsUsed'),
            const SizedBox(height: 12),
            _buildStatItem('පසි සම්පූර්ණ කරන ලද', '${grade1Passages.length}'),
            const SizedBox(height: 24),
            const Text(
              'ඔබ බෙහෙවින් කල්ට ලැබුවා!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onComplete != null) {
                widget.onComplete!();
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text(
              'ඉදිරියට යන්න',
              style: TextStyle(fontSize: 16, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _highlightController.dispose();
    _cancelInactivityTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final passage = grade1Passages[currentPassageIndex];
    final sentence = passage.sentences[currentSentenceIndex];
    final words = sentence.split(' ');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.purple.shade50,
            Colors.pink.shade50,
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              _buildProgressBar(),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
                        _buildEnhancedReadingCard(passage, words),
                        const SizedBox(height: 24),
                        if (showHint) _buildHintCard(passage),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large progress bar with animation
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: (currentPassageIndex + 1) / grade1Passages.length,
                minHeight: 12,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.blue.shade400,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Passage counter with animation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade300, Colors.purple.shade300],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'පසිය ${currentPassageIndex + 1} / ${grade1Passages.length}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Dot indicators with smooth animation
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(
                grade1Passages.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: AnimatedScale(
                    scale: index == currentPassageIndex ? 1.3 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      width: index == currentPassageIndex ? 18 : 14,
                      height: index == currentPassageIndex ? 18 : 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index < currentPassageIndex
                            ? Colors.green.shade400
                            : index == currentPassageIndex
                                ? Colors.blue.shade600
                                : Colors.grey.shade300,
                        boxShadow: index == currentPassageIndex
                            ? [
                                BoxShadow(
                                  color: Colors.blue.shade400.withOpacity(0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ]
                            : [],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedReadingCard(ReadingPassage passage, List<String> words) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.blue.shade50],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with large animated emoji and title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedScale(
                    scale: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade100,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Text(
                        passage.emoji,
                        style: const TextStyle(fontSize: 60),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.purple.shade300,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      passage.topic,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    showHint = !showHint;
                    if (showHint) hintsUsed++;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  transform: Matrix4.identity()
                    ..scale(showHint ? 1.1 : 1.0),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: showHint
                          ? [Colors.orange.shade300, Colors.amber.shade400]
                          : [Colors.blue.shade200, Colors.blue.shade400],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: showHint
                            ? Colors.orange.withOpacity(0.4)
                            : Colors.blue.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.lightbulb,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Animated sentence header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Text(
              'ශබ්දය ${currentSentenceIndex + 1} / ${grade1Passages[currentPassageIndex].sentences.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Word buttons with enhanced animations
          Wrap(
            spacing: 10,
            runSpacing: 14,
            children: List.generate(
              words.length,
              (index) => _buildEnhancedWordButton(words[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedWordButton(String word, int index) {
    final isTapped = tappedWords[index];
    final isHighlighted = highlightedWordIndex == index;
    // If this word is in letter-mode (user waited too long), show letters
    if (_letterModeWordIndex == index && !isTapped) {
      return _buildLetterTiles(word, index);
    }

    return GestureDetector(
      onTap: isTapped ? null : () => _onWordTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isHighlighted
              ? LinearGradient(
                  colors: [
                    Colors.yellow.shade300,
                    Colors.amber.shade300,
                  ],
                )
              : isTapped
                  ? LinearGradient(
                      colors: [
                        Colors.green.shade300,
                        Colors.green.shade600,
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        Colors.blue.shade200,
                        Colors.cyan.shade200,
                      ],
                    ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? Colors.amber.shade600
                : isTapped
                    ? Colors.green.shade600
                    : Colors.blue.shade400,
            width: isHighlighted ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? Colors.yellow.withOpacity(0.5)
                  : isTapped
                      ? Colors.green.withOpacity(0.3)
                      : Colors.blue.withOpacity(0.2),
              blurRadius: isHighlighted ? 12 : 6,
              spreadRadius: isHighlighted ? 2 : 0,
            ),
          ],
        ),
        child: Text(
          word,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isHighlighted
                ? Colors.amber.shade900
                : isTapped
                    ? Colors.green.shade900
                    : Colors.blue.shade900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildLetterTiles(String word, int wordIndex) {
    final letters = _extractLetters(word);
    final nextIndex = _letterProgress[wordIndex] ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 2),
      ),
      child: Wrap(
        spacing: 6,
        children: List.generate(letters.length, (i) {
          final enabled = i == nextIndex;
          final tapped = i < nextIndex;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: enabled ? () => _onLetterTapped(wordIndex, i) : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: tapped
                    ? Colors.orange.shade300
                    : (enabled ? Colors.amber.shade200 : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: tapped
                      ? Colors.orange.shade700
                      : (enabled ? Colors.amber.shade700 : Colors.grey.shade300),
                  width: 1.6,
                ),
                boxShadow: tapped
                    ? [
                        BoxShadow(
                          color: Colors.orange.shade300.withOpacity(0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : [],
              ),
              child: Text(
                letters[i],
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: tapped
                      ? Colors.white
                      : (enabled ? Colors.amber.shade900 : Colors.grey.shade800),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHintCard(ReadingPassage passage) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.shade50,
                  Colors.amber.shade50,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.orange.shade400,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.translate,
                    color: Colors.orange.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'English Help',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        passage.englishHint,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.orange.shade900,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class Particle {
  Offset offset;
  double angle;
  double speed;
  double life;

  Particle({
    required this.offset,
    required this.angle,
    required this.speed,
    required this.life,
  });
}
