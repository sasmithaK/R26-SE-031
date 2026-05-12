import 'package:flutter/material.dart';
import 'package:dyslexia_app/widgets/skip_button.dart';

class WordMatchingTask extends StatefulWidget {
  final VoidCallback? onComplete;

  const WordMatchingTask({super.key, this.onComplete});

  @override
  State<WordMatchingTask> createState() => _WordMatchingTaskState();
}

class _WordMatchingTaskState extends State<WordMatchingTask> with TickerProviderStateMixin {
  final String targetWord = 'ගහ'; // Tree
  final String imagePath = 'assets/images/tree_character.png';
  
  final List<String> options = ['මල', 'ගහ', 'කොළය', 'පලතුර']; // Flower, Tree, Leaf, Fruit

  bool? isCorrect;
  
  late AnimationController _controller;
  late Animation<double> _animation;
  
  int selectedIndex = -1;

  void _skipAndContinue() {
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -5.0, end: 5.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50,
            Colors.teal.shade50,
            Colors.cyan.shade50,
          ],
        ),
      ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('වචන ගලපමු 🎯', 
                style: TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.green.shade900,
              centerTitle: true,
              actions: [SkipButton(taskName: 'word_matching', onSkipped: _skipAndContinue)],
            ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Animated owl with bounce
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _animation.value * 3),
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.95, end: 1.05)
                            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.shade100,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.shade300.withOpacity(0.4),
                          blurRadius: 16,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/welcome_owl.png',
                      height: 160,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => 
                          const Icon(Icons.pets, size: 160, color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Question with animation
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade100, Colors.teal.shade100],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade300, width: 2),
                  ),
                  child: const Text(
                    'මේ මොකක්ද?',
                    style: TextStyle(
                      fontSize: 36, 
                      fontWeight: FontWeight.w900, 
                      color: Colors.green,
                      shadows: [
                        Shadow(color: Colors.white, blurRadius: 5, offset: Offset(2, 2))
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 28),
                
                // Target Image Container with enhanced styling
                Container(
                  width: 220,
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white, Colors.green.shade50],
                    ),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(
                      color: Colors.green.shade400,
                      width: 8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.shade300,
                        offset: const Offset(0, 12),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.green.shade200.withOpacity(0.3),
                        offset: const Offset(0, 20),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.park_rounded, size: 100, color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Feedback animation
                if (isCorrect != null)
                  ScaleTransition(
                    scale: AlwaysStoppedAnimation<double>(1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isCorrect!
                                ? [Colors.amber.shade300, Colors.orange.shade400]
                                : [Colors.red.shade200, Colors.red.shade300],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: isCorrect! 
                                  ? Colors.orange.withOpacity(0.4)
                                  : Colors.red.withOpacity(0.3),
                              blurRadius: 12,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCorrect! ? Icons.star_rounded : Icons.close_rounded,
                              color: Colors.white,
                              size: 44,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isCorrect! ? 'නියමයි! 🎉' : 'නැවත උත්සාහ කරන්න',
                              style: const TextStyle(
                                fontSize: 24, 
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade300, width: 2),
                    ),
                    child: const Text(
                      '🔽 පහතින් තෝරන්න',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal,
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                // Options with enhanced animations
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: List.generate(options.length, (index) {
                    final word = options[index];
                    final isSelected = selectedIndex == index;
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedIndex = index;
                          isCorrect = word == targetWord;
                        });
                        
                        if (word == targetWord && widget.onComplete != null) {
                          Future.delayed(const Duration(milliseconds: 1500), () {
                            if (mounted) {
                              widget.onComplete!();
                            }
                          });
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                          width: 140,
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? (isCorrect == true
                                    ? LinearGradient(
                                        colors: [
                                          Colors.green.shade400,
                                          Colors.green.shade600,
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.red.shade300,
                                          Colors.red.shade400,
                                        ],
                                      ))
                                : LinearGradient(
                                    colors: [
                                      Colors.white,
                                      Colors.green.shade50,
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: isSelected
                                  ? (isCorrect == true
                                      ? Colors.green.shade600
                                      : Colors.red.shade600)
                                  : Colors.green.shade400,
                              width: isSelected ? 4 : 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? (isCorrect == true
                                        ? Colors.green.withOpacity(0.5)
                                        : Colors.red.withOpacity(0.5))
                                    : Colors.green.shade200.withOpacity(0.3),
                                offset: const Offset(0, 8),
                                blurRadius: isSelected ? 12 : 6,
                                spreadRadius: isSelected ? 2 : 0,
                              )
                            ],
                          ),
                          child: Center(
                            child: Text(
                              word,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.green.shade800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),

                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
