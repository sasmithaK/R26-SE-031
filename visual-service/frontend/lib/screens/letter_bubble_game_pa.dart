import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'word_start_letter_game_pa.dart';

// ── Models ───────────────────────────────────────────────────────────────────

class Bubble {
  final String id;
  double x;
  double y;
  final String letter;
  double radius;
  final double targetRadius;
  final double speed;
  double wavePhase;
  final double waveAmplitude;
  final double waveSpeed;
  
  // Interaction states: 'growing', 'normal', 'correct', 'incorrect', 'popping'
  String state;
  double popScale;
  double opacity;
  double shakePhase;

  Bubble({
    required this.id,
    required this.x,
    required this.y,
    required this.letter,
    required this.radius,
    required this.targetRadius,
    required this.speed,
    required this.wavePhase,
    required this.waveAmplitude,
    required this.waveSpeed,
    this.state = 'normal',
    this.popScale = 1.0,
    this.opacity = 1.0,
    this.shakePhase = 0.0,
  });
}

class BackgroundBubble {
  double x;
  double y;
  final double radius;
  final double speed;
  double wavePhase;
  final double waveAmplitude;

  BackgroundBubble({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.wavePhase,
    required this.waveAmplitude,
  });
}

class PopParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  final Color color;

  PopParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.color,
  });
}

// ── Game Screen ──────────────────────────────────────────────────────────────

class LetterBubbleGamePa extends StatefulWidget {
  const LetterBubbleGamePa({super.key});

  @override
  State<LetterBubbleGamePa> createState() => _LetterBubbleGamePaState();
}

class _LetterBubbleGamePaState extends State<LetterBubbleGamePa> with SingleTickerProviderStateMixin {
  final String studentId = "student_001";
  final String targetLetter = "ප";
  final List<String> distractorLetters = ["ම", "ග", "ර"];
  
  // Game limits
  final int totalHitsRequired = 5;
  int currentHits = 0;
  int errorsCount = 0;
  bool isCompleted = false;

  // Timers and State variables
  Timer? _gameTimer;
  DateTime? _gameStartTime;
  DateTime? _lastActionTime;
  
  List<Bubble> _bubbles = [];
  List<BackgroundBubble> _bgBubbles = [];
  List<PopParticle> _particles = [];
  
  double _owlBlowingProgress = 0.0;
  bool _isOwlBlowing = false;
  bool _isOwlCheering = false;
  double _owlCheerAnimation = 0.0;
  Bubble? _growingBubble;

  // Screen size tracking
  Size _screenSize = Size.zero;
  final Random _random = Random();
  bool _initialized = false;
  
  // Intro Sequence State
  bool _isIntroMode = true;
  Timer? _introTimer;
  double _introAnimationProgress = 0.0;
  
  final AudioPlayer _audioPlayer = AudioPlayer();

  void _playSound(String fileName) async {
    try {
      await _audioPlayer.play(AssetSource('audio/$fileName'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _startIntroSequence();
  }

  void _startIntroSequence() {
    _playSound('intro.mp3'); // Play custom intro music
    _isIntroMode = true;
    _isOwlCheering = true;
    
    // Intro animation loop (for fast cheering/dancing)
    _introTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      setState(() {
        _introAnimationProgress += 0.15;
        _owlCheerAnimation = (sin(_introAnimationProgress) + 1) / 2;
      });
    });

    // End intro after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        _endIntroSequence();
      }
    });
  }

  void _endIntroSequence() {
    _introTimer?.cancel();
    _audioPlayer.stop(); // Stop intro music when the game starts
    
    setState(() {
      _isIntroMode = false;
      _isOwlCheering = false;
      _owlCheerAnimation = 0.0;
    });
    
    _gameStartTime = DateTime.now();
    _lastActionTime = DateTime.now();
    
    _resetGame();

    // Start game loop
    _gameTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      _updateGame();
    });
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _gameTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Telemetry & Mastery Integration ──────────────────────────────────────

  Future<void> _sendTelemetry() async {
    final responseTime = DateTime.now().difference(_gameStartTime!).inSeconds;
    final url = Uri.parse('http://127.0.0.1:8001/telemetry');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "task_id": "letter_bubble_game_pa_01",
          "response_time": responseTime.toDouble(),
          "error_count": errorsCount,
          "hesitation_count": 0,
          "input_velocity": 0.0
        }),
      );
    } catch (e) {
      debugPrint("Error sending telemetry: $e");
    }
  }

  Future<void> _updateMastery(bool correct) async {
    final latency = DateTime.now().difference(_lastActionTime!).inMilliseconds;
    _lastActionTime = DateTime.now();
    
    final url = Uri.parse('http://127.0.0.1:8002/api/v1/mastery/update');
    try {
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "student_id": studentId,
          "skill_id": "vowel_recognition_bubbles",
          "is_correct": correct,
          "response_latency_ms": latency.toDouble()
        }),
      );
    } catch (e) {
      debugPrint("Error updating mastery: $e");
    }
  }

  // ── Game Mechanics ─────────────────────────────────────────────────────────

  void _initPositions(Size size) {
    _screenSize = size;
    
    // Spawn initial background decorative bubbles
    for (int i = 0; i < 8; i++) {
      _bgBubbles.add(BackgroundBubble(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        radius: 16 + _random.nextDouble() * 24,
        speed: 0.4 + _random.nextDouble() * 0.6,
        wavePhase: _random.nextDouble() * pi * 2,
        waveAmplitude: 15 + _random.nextDouble() * 15,
      ));
    }

    // Stagger spawn the initial game bubbles directly as normal
    for (int i = 0; i < 3; i++) {
      final double targetR = 75 + _random.nextDouble() * 15;
      final double startX = size.width * 0.2 + _random.nextDouble() * (size.width * 0.4);
      final double startY = size.height * 0.15 + (i * size.height * 0.25);
      
      // Determine letters randomly for a shuffled challenge
      String letter = _random.nextDouble() < 0.35 
          ? targetLetter 
          : distractorLetters[_random.nextInt(distractorLetters.length)];
      
      _bubbles.add(Bubble(
        id: "init_$i",
        x: startX,
        y: startY,
        letter: letter,
        radius: targetR,
        targetRadius: targetR,
        speed: 0.6 + _random.nextDouble() * 0.4,
        wavePhase: _random.nextDouble() * pi * 2,
        waveAmplitude: 20 + _random.nextDouble() * 30,
        waveSpeed: 0.02 + _random.nextDouble() * 0.02,
        state: 'normal',
      ));
    }
    
    _initialized = true;
  }

  void _startBlowingBubble() {
    if (_screenSize == Size.zero || _isOwlBlowing || isCompleted) return;

    setState(() {
      _isOwlBlowing = true;
      _owlBlowingProgress = 0.0;
      _growingBubble = null;
    });
  }

  void _spawnGrowingBubble() {
    // Determine the letter purely randomly to shuffle
    String letter = _random.nextDouble() < 0.35 
        ? targetLetter 
        : distractorLetters[_random.nextInt(distractorLetters.length)];

    final double targetR = 75 + _random.nextDouble() * 15;
    
    // Spawn from bubble gun nozzle (character is at bottom middle of screen)
    final double charX = _screenSize.width / 2;
    final double charY = _screenSize.height - 80; // Character bottom is 20, height is 120, center is 80 from bottom
    final double startX = charX + 25; // Hand X is ~45, nozzle is left-up
    final double startY = charY - 15; // Hand Y is ~15, nozzle is left-up

    final id = DateTime.now().millisecondsSinceEpoch.toString() + _random.nextInt(100).toString();
    
    _growingBubble = Bubble(
      id: id,
      x: startX,
      y: startY,
      letter: letter,
      radius: 0.0, // starts tiny
      targetRadius: targetR,
      speed: 0.6 + _random.nextDouble() * 0.4,
      wavePhase: _random.nextDouble() * pi * 2,
      waveAmplitude: 20 + _random.nextDouble() * 30,
      waveSpeed: 0.02 + _random.nextDouble() * 0.02,
      state: 'growing',
    );
    
    _bubbles.add(_growingBubble!);
  }

  void _spawnParticles(double x, double y, Color color, {int count = 16, double burstSpeed = 5.0}) {
    for (int i = 0; i < count; i++) {
      final angle = _random.nextDouble() * pi * 2;
      final speed = 2.0 + _random.nextDouble() * burstSpeed;
      _particles.add(PopParticle(
        x: x,
        y: y,
        vx: cos(angle) * speed,
        vy: sin(angle) * speed - 2.0, // upward pop force
        size: 6 + _random.nextDouble() * 8,
        opacity: 1.0,
        color: color,
      ));
    }
  }

  void _updateGame() {
    if (!_initialized) return;

    setState(() {
      // 1. Update background decorative bubbles
      for (var bg in _bgBubbles) {
        bg.y -= bg.speed;
        bg.wavePhase += 0.01;
        bg.x += sin(bg.wavePhase) * 0.15;
        
        if (bg.y < -40) {
          bg.y = _screenSize.height + 40;
          bg.x = _random.nextDouble() * _screenSize.width;
        }
      }

      // 2. Update gameplay bubbles
      List<Bubble> deadBubbles = [];
      
      // Update Owl Blow Progress
      if (_isOwlBlowing) {
        _owlBlowingProgress += 0.012; // slow down to make animation clear
        
        // At 50% blow phase, spawn growing bubble
        if (_owlBlowingProgress >= 0.50 && _owlBlowingProgress < 0.85 && _growingBubble == null) {
          _spawnGrowingBubble();
        }

        // Scale growing bubble
        if (_growingBubble != null && _growingBubble!.state == 'growing') {
          // Normalize blow progress between 0.50 and 0.85
          double norm = ((_owlBlowingProgress - 0.50) / 0.35).clamp(0.0, 1.0);
          _growingBubble!.radius = _growingBubble!.targetRadius * norm;
          
          // keep it locked at the gun nozzle
          final double charX = _screenSize.width / 2;
          final double charY = _screenSize.height - 80;
          _growingBubble!.x = charX + 25;
          _growingBubble!.y = charY - 15;
        }

        // At 85% release phase, release bubble to float
        if (_owlBlowingProgress >= 0.85 && _growingBubble != null && _growingBubble!.state == 'growing') {
          _growingBubble!.state = 'normal';
          _growingBubble = null;
        }

        if (_owlBlowingProgress >= 1.0) {
          _isOwlBlowing = false;
        }
      }

      for (var b in _bubbles) {
        if (b.state == 'normal') {
          b.y -= b.speed;
          b.wavePhase += b.waveSpeed;
          // drift leftwards and wiggle
          b.x -= 0.5; 
          b.x += sin(b.wavePhase) * (b.waveAmplitude * 0.02);

          // Wrap / respawn if off-screen top
          if (b.y < -b.radius * 2) {
            deadBubbles.add(b);
          }
        } else if (b.state == 'correct') {
          // Popping transition
          b.popScale += 0.06;
          b.opacity -= 0.12;
          if (b.opacity <= 0.0) {
            deadBubbles.add(b);
          }
        } else if (b.state == 'incorrect') {
          // Shake wiggle
          b.shakePhase += 0.6;
          b.y -= b.speed * 0.3; // slow down during error
          
          if (b.shakePhase >= pi * 4) {
            b.state = 'normal';
            b.shakePhase = 0.0;
          }
        }
      }

      for (var db in deadBubbles) {
        _bubbles.remove(db);
        if (!isCompleted) {
          _startBlowingBubble();
        }
      }

      // 3. Update particles
      List<PopParticle> deadParticles = [];
      for (var p in _particles) {
        p.x += p.vx;
        p.y += p.vy;
        p.vy += 0.18; // gravity
        p.opacity -= 0.035;
        if (p.opacity <= 0) {
          deadParticles.add(p);
        }
      }
      _particles.removeWhere((p) => deadParticles.contains(p));

      // 4. Update owl cheering
      if (_isOwlCheering) {
        _owlCheerAnimation += 0.06;
        if (_owlCheerAnimation >= 1.0) {
          _isOwlCheering = false;
        }
      }
      
      // Keep bubble count healthy (at least 3 bubbles)
      int activeCount = _bubbles.where((b) => b.state == 'normal' || b.state == 'growing').length;
      if (activeCount < 3 && !_isOwlBlowing && !isCompleted) {
        _startBlowingBubble();
      }
    });
  }

  void _handleBubbleTap(Bubble bubble) {
    if (isCompleted || bubble.state == 'correct' || bubble.state == 'growing') return;

    if (bubble.letter == targetLetter) {
      // CORRECT CELEBRATION
      HapticFeedback.mediumImpact();
      _playSound('correct.mp3');
      
      setState(() {
        bubble.state = 'correct';
        currentHits++;
        
        // Owl cheering animation
        _isOwlCheering = true;
        _owlCheerAnimation = 0.0;
      });

      _spawnParticles(bubble.x, bubble.y, const Color(0xFF58CC02));
      _updateMastery(true);

      if (currentHits >= totalHitsRequired) {
        setState(() {
          isCompleted = true;
        });
        _sendTelemetry();
        _launchFireworks();
      }
    } else {
      // INCORRECT WARNING
      HapticFeedback.vibrate();
      _playSound('wrong.mp3');
      
      setState(() {
        bubble.state = 'incorrect';
        bubble.shakePhase = 0.0;
        errorsCount++;
      });
      
      _spawnParticles(bubble.x, bubble.y, const Color(0xFFFF9600));
      _updateMastery(false);
    }
  }

  void _launchFireworks() {
    for (int i = 0; i < 6; i++) {
      Future.delayed(Duration(milliseconds: i * 500), () {
        if (!mounted) return;
        setState(() {
          double x = _screenSize.width * 0.2 + _random.nextDouble() * (_screenSize.width * 0.6);
          double y = _screenSize.height * 0.2 + _random.nextDouble() * (_screenSize.height * 0.5);
          Color c = Colors.primaries[_random.nextInt(Colors.primaries.length)];
          _spawnParticles(x, y, c, count: 60, burstSpeed: 15.0);
        });
      });
    }

    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WordStartLetterGamePa()),
      );
    });
  }

  void _showVictoryDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierLabel: "ජයග්‍රහණය",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            backgroundColor: Colors.white,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                // Custom drawn owl in dialog cheering
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CustomPaint(
                    painter: DuoOwlPainter(
                      breathing: 0.5,
                      animProgress: 0.0,
                      isBlowing: false,
                      isCheering: true,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  "නියමයි!", // Awesome!
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF58CC02),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "ඔබ සාර්ථකව 'ප' අකුර හඳුනා ගත්තා!", // You successfully identified the letter 'ප'!
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 25),
                // Stars summary
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    bool gold = true;
                    if (index == 2 && errorsCount > 3) gold = false;
                    if (index == 1 && errorsCount > 5) gold = false;
                    return Icon(
                      Icons.star_rounded,
                      size: 56,
                      color: gold ? const Color(0xFFFFC107) : Colors.grey.shade300,
                    );
                  }),
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Dismiss dialog
                        Navigator.of(context).pop(); // Back to dashboard
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.grey.shade800,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: const Text(
                        "පිටවීම", // Exit
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Dismiss dialog
                        _resetGame();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF58CC02),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "නැවත ක්‍රීඩා කරන්න", // Play again
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetGame() {
    setState(() {
      currentHits = 0;
      errorsCount = 0;
      isCompleted = false;
      _bubbles.clear();
      _particles.clear();
      _growingBubble = null;
      _isOwlBlowing = false;
      _gameStartTime = DateTime.now();
      _lastActionTime = DateTime.now();
      
      // Spawn new bubbles
      for (int i = 0; i < 3; i++) {
        final double targetR = 75 + _random.nextDouble() * 15;
        final double startX = _screenSize.width * 0.2 + _random.nextDouble() * (_screenSize.width * 0.4);
        final double startY = _screenSize.height * 0.15 + (i * _screenSize.height * 0.25);
        _bubbles.add(Bubble(
          id: "init_$i",
          x: startX,
          y: startY,
          letter: (i == 0) ? targetLetter : distractorLetters[i % distractorLetters.length],
          radius: targetR,
          targetRadius: targetR,
          speed: 0.6 + _random.nextDouble() * 0.4,
          wavePhase: _random.nextDouble() * pi * 2,
          waveAmplitude: 20 + _random.nextDouble() * 30,
          waveSpeed: 0.02 + _random.nextDouble() * 0.02,
          state: 'normal',
        ));
      }
    });
  }

  // ── Payout Builder ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    
    // Initialize positions once screen size is ready
    if (!_initialized && size != Size.zero) {
      _initPositions(size);
    }

    double progress = (currentHits / totalHitsRequired).clamp(0.0, 1.0);

    if (_isIntroMode) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F9FF),
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background sky gradient
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFD0EFFE), Color(0xFFF0F9FF)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
              // Dancing Owl and Text
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "'ප' අකුර ඉගෙන ගනිමු",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF01579B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 70),
                    Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        Transform.translate(
                          offset: Offset(0, -sin(_owlCheerAnimation * pi) * 30),
                          child: SizedBox(
                            width: 200,
                            height: 200,
                            child: CustomPaint(
                              painter: DuoOwlPainter(
                                breathing: sin(DateTime.now().millisecondsSinceEpoch * 0.005),
                                animProgress: _owlCheerAnimation,
                                isBlowing: false,
                                isCheering: true,
                              ),
                            ),
                          ),
                        ),
                        // The letter 'ප' held by the Owl
                        Positioned(
                          top: -50,
                          child: Transform.translate(
                            offset: Offset(0, -sin(_owlCheerAnimation * pi) * 40),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF64B5F6), // Calm soft blue
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blue.withOpacity(0.3),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Text(
                                "ප",
                                style: TextStyle(
                                  fontSize: 70,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F9FF), 
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Background sky gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFD0EFFE), Color(0xFFF0F9FF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // 2. Render decorative background bubbles
            ..._bgBubbles.map((bg) => Positioned(
              left: bg.x + (sin(bg.wavePhase) * bg.waveAmplitude),
              top: bg.y,
              child: Container(
                width: bg.radius * 2,
                height: bg.radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.0,
                  ),
                ),
              ),
            )),

            // Character
            Positioned(
              left: _screenSize.width / 2 - 60,
              bottom: 20,
              child: GestureDetector(
                onTap: _startBlowingBubble,
                child: Transform.translate(
                  offset: Offset(0, _isOwlCheering ? -sin(_owlCheerAnimation * pi) * 20 : 
                                  (_isOwlBlowing ? -sin(_owlBlowingProgress * pi) * 30 : 0)),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: DuoOwlPainter(
                        breathing: _owlBlowingProgress == 0 ? sin(DateTime.now().millisecondsSinceEpoch * 0.003) : 0,
                        animProgress: _owlBlowingProgress,
                        isBlowing: _isOwlBlowing,
                        isCheering: _isOwlCheering,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 4. Render gameplay bubbles containing letters
            ..._bubbles.map((b) {
              // Calculate horizontal wobble and shake
              double posX = b.x;
              if (b.state == 'incorrect') {
                posX += sin(b.shakePhase) * 16.0;
              } else if (b.state == 'normal') {
                posX += sin(b.wavePhase) * b.waveAmplitude * 0.20;
              }

              // Color based on state
              Color bubbleBg = Colors.white.withOpacity(0.30);
              Color borderCol = Colors.white.withOpacity(0.65);
              Color textCol = Colors.black87;

              if (b.state == 'correct') {
                bubbleBg = const Color(0xFF58CC02).withOpacity(b.opacity);
                borderCol = const Color(0xFF78C800).withOpacity(b.opacity);
                textCol = Colors.white.withOpacity(b.opacity);
              } else if (b.state == 'incorrect') {
                bubbleBg = const Color(0xFFFF9600);
                borderCol = const Color(0xFFE07C00);
                textCol = Colors.white;
              }

              return Positioned(
                left: posX - b.radius,
                top: b.y - b.radius,
                child: GestureDetector(
                  onTap: () => _handleBubbleTap(b),
                  child: Transform.scale(
                    scale: b.state == 'correct' ? b.popScale : 1.0,
                    child: Opacity(
                      opacity: b.state == 'correct' ? b.opacity : 1.0,
                      child: Container(
                        width: b.radius * 2,
                        height: b.radius * 2,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: bubbleBg,
                          boxShadow: [
                            BoxShadow(
                              color: borderCol.withOpacity(0.25),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                          border: Border.all(
                            color: borderCol,
                            width: 4.0,
                          ),
                          gradient: (b.state == 'normal' || b.state == 'growing')
                              ? LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.55),
                                    Colors.blue.withOpacity(0.10),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                        ),
                        child: Stack(
                          children: [
                            // Glassmorphism shine overlay
                            if (b.state == 'normal' || b.state == 'growing')
                              Positioned(
                                top: b.radius * 0.2,
                                left: b.radius * 0.3,
                                child: Container(
                                  width: b.radius * 0.5,
                                  height: b.radius * 0.25,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.all(Radius.elliptical(b.radius * 0.25, b.radius * 0.12)),
                                    color: Colors.white.withOpacity(0.65),
                                  ),
                                ),
                              ),
                            Center(
                              child: Text(
                                b.letter,
                                style: TextStyle(
                                  fontSize: 80, // Substantially larger letter size for Grade 1
                                  fontWeight: FontWeight.w900,
                                  color: textCol,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),

            // 5. Render particle pops
            ..._particles.map((p) => Positioned(
              left: p.x,
              top: p.y,
              child: Opacity(
                opacity: p.opacity,
                child: Container(
                  width: p.size,
                  height: p.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.color,
                  ),
                ),
              ),
            )),

            // 6. Header HUD: progress bar + cross button
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    // Exit Cross Button
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text(
                              "ක්‍රීඩාවෙන් ඉවත් වීම", // Exiting Game
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            content: const Text(
                              "ඔබට මෙම ක්‍රීඩාවෙන් ඉවත් වීමට අවශ්‍යද?", // Do you want to exit?
                              style: TextStyle(fontSize: 18),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text("නැත", style: TextStyle(fontSize: 18)),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  Navigator.of(context).pop();
                                },
                                child: const Text("ඔව්", style: TextStyle(fontSize: 18)),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    // Progress bar
                    Expanded(
                      child: Stack(
                        children: [
                          // Track background
                          Container(
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          // Track fill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 22,
                            width: (size.width - 100) * progress,
                            decoration: BoxDecoration(
                              color: const Color(0xFF58CC02),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF78C800).withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                margin: const EdgeInsets.only(right: 6),
                                width: 10,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.55),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 7. Instructions HUD (Grade 1 optimized, large and 100% Sinhala)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFB3E5FC), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Flexible(
                        child: Text(
                          "මෙම අකුර ඇති බුබුල තෝරන්න:  ",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF01579B),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.blue.shade400, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade100,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          "ප",
                          style: TextStyle(
                            fontSize: 42, // Substantially larger target vowel
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Painter: Orange Monster (3D shaded & animated) ──────

class DuoOwlPainter extends CustomPainter {
  final double breathing;
  final double animProgress;
  final bool isBlowing;
  final bool isCheering;

  DuoOwlPainter({
    required this.breathing,
    required this.animProgress,
    required this.isBlowing,
    required this.isCheering,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Breathing scale modifier
    final double scale = 1.0 + (breathing * 0.02);

    final Paint fillPaint = Paint()..style = PaintingStyle.fill;
    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.black87
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    // Translate coordinate space center of body (0,0)
    canvas.translate(w * 0.5, h * 0.55);
    canvas.scale(scale);

    // Light source from top left for 3D effect
    final Alignment lightSource = const Alignment(-0.3, -0.4);

    // 1. Draw Feet (Dark stubby feet with small toes)
    fillPaint.color = const Color(0xFF6D3010); // Dark brownish orange
    _drawFoot(canvas, const Offset(-25, 75), fillPaint);
    _drawFoot(canvas, const Offset(25, 75), fillPaint);

    // 2. Antennas (Thin black stems with glowing orange/yellow bulbs)
    _drawAntenna(canvas, const Offset(-15, -60), const Offset(-40, -100), fillPaint, strokePaint);
    _drawAntenna(canvas, const Offset(15, -60), const Offset(40, -100), fillPaint, strokePaint);

    // 3. Draw Main Body (Egg/Blob shape with pointy ears/horns on sides)
    final Path bodyPath = Path();
    bodyPath.moveTo(0, -65); // top center
    // right top curve
    bodyPath.quadraticBezierTo(45, -65, 55, -30);
    // right horn
    bodyPath.lineTo(75, -45);
    bodyPath.lineTo(65, -10);
    // right bottom curve
    bodyPath.quadraticBezierTo(75, 40, 60, 65);
    bodyPath.quadraticBezierTo(30, 75, 0, 75); // bottom center
    // left bottom curve
    bodyPath.quadraticBezierTo(-30, 75, -60, 65);
    bodyPath.quadraticBezierTo(-75, 40, -65, -10);
    // left horn
    bodyPath.lineTo(-75, -45);
    bodyPath.lineTo(-55, -30);
    // left top curve
    bodyPath.quadraticBezierTo(-45, -65, 0, -65);

    // Radial gradient for 3D shaded body
    fillPaint.shader = RadialGradient(
      colors: const [Color(0xFFFFB74D), Color(0xFFFF8F00), Color(0xFFE65100), Color(0xFFBF360C)],
      stops: const [0.0, 0.4, 0.8, 1.0],
      center: lightSource,
      radius: 1.2,
    ).createShader(bodyPath.getBounds());

    // Drop shadow behind body
    canvas.drawShadow(bodyPath, Colors.black45, 8.0, true);
    
    // Draw body
    canvas.drawPath(bodyPath, fillPaint);
    fillPaint.shader = null; // Clear shader

    // 4. Draw Single Big Eye (Glossy 3D Cyclops Eye)
    // Eye shadow (inset shadow effect)
    fillPaint.color = Colors.black.withOpacity(0.15);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -10), width: 84, height: 90), fillPaint);
    
    // Eye white
    fillPaint.color = Colors.white;
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -12), width: 80, height: 86), fillPaint);
    
    // Eye pupil (Parge black oval)
    fillPaint.color = const Color(0xFF1A1A1A);
    canvas.drawOval(Rect.fromCenter(center: const Offset(0, -12), width: 40, height: 50), fillPaint);

    // Glossy 3D Glares
    fillPaint.color = Colors.white;
    // Primary big glare
    canvas.drawOval(Rect.fromCenter(center: const Offset(6, -22), width: 14, height: 20), fillPaint);
    // Secondary small glare
    canvas.drawOval(Rect.fromCenter(center: const Offset(-8, -4), width: 6, height: 8), fillPaint);

    // 5. Draw Mouth (Thin cute smile like the attached image)
    final Path mouth = Path();
    strokePaint.strokeWidth = 2.5;
    strokePaint.color = const Color(0xFF4E1600); // Dark brown mouth line

    if (isBlowing) {
      // Blowing Mouth: small circle
      fillPaint.color = const Color(0xFF4E1600);
      canvas.drawCircle(const Offset(0, 42), 8, fillPaint);
    } else if (isCheering) {
      // Open happy mouth
      mouth.moveTo(-25, 38);
      mouth.quadraticBezierTo(0, 55, 25, 38);
      mouth.close();
      fillPaint.color = const Color(0xFF4E1600);
      canvas.drawPath(mouth, fillPaint);
      canvas.drawPath(mouth, strokePaint);
    } else {
      // Wide thin smile
      mouth.moveTo(-35, 38);
      mouth.quadraticBezierTo(0, 48, 35, 38);
      // Small smile dimples
      mouth.moveTo(-35, 38);
      mouth.lineTo(-37, 35);
      mouth.moveTo(35, 38);
      mouth.lineTo(37, 35);
      canvas.drawPath(mouth, strokePaint);
    }

    // 6. Draw Hand & Bubble Gun
    Offset handPos = const Offset(45, 25);
    double gunAngle = 0.0;

    if (isBlowing) {
      // Move hand slightly up and point gun while blowing
      double t = animProgress < 0.5 ? animProgress * 2 : 1.0 - (animProgress - 0.5) * 2;
      handPos = Offset.lerp(const Offset(45, 25), const Offset(45, 10), t)!;
      gunAngle = lerpDouble(0.0, -pi / 16, t);
    }

    // Left hand resting (stubby small fluffy hand)
    _drawHand(canvas, const Offset(-45, 35), true, fillPaint, lightSource);

    // Bubble Gun
    _drawBubbleGun(canvas, handPos, gunAngle, fillPaint, strokePaint);

    // Right Hand (Holding Gun)
    _drawHand(canvas, handPos, false, fillPaint, lightSource);

    canvas.restore();
  }

  void _drawFoot(Canvas canvas, Offset center, Paint paint) {
    final Path foot = Path();
    foot.moveTo(center.dx - 16, center.dy - 10);
    foot.lineTo(center.dx + 16, center.dy - 10);
    foot.lineTo(center.dx + 18, center.dy + 10);
    // Three small toes
    foot.quadraticBezierTo(center.dx + 12, center.dy + 15, center.dx + 6, center.dy + 10);
    foot.quadraticBezierTo(center.dx + 0, center.dy + 15, center.dx - 6, center.dy + 10);
    foot.quadraticBezierTo(center.dx - 12, center.dy + 15, center.dx - 18, center.dy + 10);
    foot.close();
    canvas.drawPath(foot, paint);
  }

  void _drawAntenna(Canvas canvas, Offset base, Offset tip, Paint fillPaint, Paint strokePaint) {
    // Stem
    final Path stem = Path();
    stem.moveTo(base.dx, base.dy);
    stem.quadraticBezierTo(base.dx, tip.dy + 20, tip.dx, tip.dy);
    strokePaint.color = Colors.black87;
    strokePaint.strokeWidth = 3.0;
    canvas.drawPath(stem, strokePaint);
    
    // Glowing bulb
    fillPaint.shader = RadialGradient(
      colors: const [Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFFF57F17)],
      stops: const [0.0, 0.5, 1.0],
      center: const Alignment(-0.3, -0.3),
      radius: 0.8,
    ).createShader(Rect.fromCenter(center: tip, width: 24, height: 24));
    
    canvas.drawCircle(tip, 12, fillPaint);
    fillPaint.shader = null;
  }

  void _drawHand(Canvas canvas, Offset pos, bool isLeft, Paint fillPaint, Alignment lightSource) {
    // Radial gradient for hand
    fillPaint.shader = RadialGradient(
      colors: const [Color(0xFFFFB74D), Color(0xFFFF8F00), Color(0xFFE65100)],
      center: lightSource,
      radius: 0.8,
    ).createShader(Rect.fromCenter(center: pos, width: 30, height: 30));
    
    final Path hand = Path();
    hand.moveTo(pos.dx - 10, pos.dy - 5);
    hand.quadraticBezierTo(pos.dx, pos.dy - 15, pos.dx + 10, pos.dy - 5);
    hand.quadraticBezierTo(pos.dx + 15, pos.dy + 5, pos.dx + 5, pos.dy + 12);
    // Fingers/fluff
    hand.quadraticBezierTo(pos.dx, pos.dy + 15, pos.dx - 5, pos.dy + 12);
    hand.quadraticBezierTo(pos.dx - 15, pos.dy + 5, pos.dx - 10, pos.dy - 5);
    canvas.drawPath(hand, fillPaint);
    fillPaint.shader = null;
  }

  void _drawBubbleGun(Canvas canvas, Offset pos, double angle, Paint fillPaint, Paint strokePaint) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    // Gun body (Blue)
    fillPaint.color = const Color(0xFF2196F3);
    final Rect body = Rect.fromLTWH(-15, -15, 30, 20);
    canvas.drawRect(body, fillPaint);
    canvas.drawRect(body, strokePaint);

    // Gun nozzle (pointing up-left)
    fillPaint.color = const Color(0xFF64B5F6);
    final Rect nozzle = Rect.fromLTWH(-20, -25, 10, 10);
    canvas.drawRect(nozzle, fillPaint);
    canvas.drawRect(nozzle, strokePaint);

    // Handle (pointing down)
    fillPaint.color = const Color(0xFF1976D2);
    final Rect handle = Rect.fromLTWH(0, 5, 10, 20);
    canvas.drawRect(handle, fillPaint);
    canvas.drawRect(handle, strokePaint);

    canvas.drawCircle(const Offset(0, -12), 8, fillPaint);
    canvas.drawCircle(const Offset(0, -12), 8, strokePaint);

    // Soft bubble soapy layer reflection (shiny blue inside loop nozzle)
    if (isBlowing && animProgress < 0.85) {
      fillPaint.color = const Color(0xFF80DEEA).withOpacity(0.6);
      canvas.drawCircle(const Offset(0, -12), 7, fillPaint);
    }

    canvas.restore();
  }

  double lerpDouble(double a, double b, double t) => a + (b - a) * t;

  @override
  bool shouldRepaint(covariant DuoOwlPainter oldDelegate) {
    return oldDelegate.breathing != breathing ||
        oldDelegate.animProgress != animProgress ||
        oldDelegate.isBlowing != isBlowing ||
        oldDelegate.isCheering != isCheering;
  }
}

