import 'package:flutter/material.dart';

class WordMatchingTask extends StatefulWidget {
  const WordMatchingTask({super.key});

  @override
  State<WordMatchingTask> createState() => _WordMatchingTaskState();
}

class _WordMatchingTaskState extends State<WordMatchingTask> with SingleTickerProviderStateMixin {
  final String targetWord = 'ගහ'; // Tree
  final String imagePath = 'assets/images/tree_character.png';
  
  final List<String> options = ['මල', 'ගහ', 'කොළය', 'පලතුර']; // Flower, Tree, Leaf, Fruit

  bool? isCorrect;
  
  late AnimationController _controller;
  late Animation<double> _animation;

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
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9), // Solid light green
        image: DecorationImage(
          image: AssetImage('assets/images/welcome_owl.png'),
          opacity: 0.05,
          fit: BoxFit.scaleDown,
          alignment: Alignment.bottomRight,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('වචන ගලපමු', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.green.shade900,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _animation.value * 2),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/images/welcome_owl.png', // Huge Owl
                    height: 180,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.pets, size: 180, color: Colors.green),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'මේ මොකක්ද?', // What is this?
                  style: TextStyle(
                    fontSize: 34, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.green,
                    shadows: [
                      Shadow(color: Colors.white, blurRadius: 5, offset: Offset(2, 2))
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Target Image Container
                Container(
                  width: 200,
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.green, width: 8),
                    boxShadow: [
                      BoxShadow(color: Colors.green.shade300, offset: const Offset(0, 12), blurRadius: 0)
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
                const SizedBox(height: 20),

                if (isCorrect != null)
                  AnimatedScale(
                    scale: isCorrect! ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isCorrect! ? Icons.star_rounded : Icons.close_rounded,
                            color: isCorrect! ? Colors.orange : Colors.red,
                            size: 40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isCorrect! ? 'නියමයි!' : 'නැවත උත්සාහ කරන්න',
                            style: TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.w900,
                              color: isCorrect! ? Colors.orange : Colors.red,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),

                // Options
                Wrap(
                  spacing: 15,
                  runSpacing: 15,
                  alignment: WrapAlignment.center,
                  children: options.map((word) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          isCorrect = word == targetWord;
                        });
                      },
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.green.shade400, width: 6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.shade200,
                              offset: const Offset(0, 8),
                              blurRadius: 0,
                            )
                          ],
                        ),
                        child: Center(
                          child: Text(
                            word,
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.green.shade800),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
