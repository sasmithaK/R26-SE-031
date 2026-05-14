import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Intervention overlay that shows syllable splitting with audio playback
class InterventionOverlay extends StatefulWidget {
  final List<String> syllables;
  final String fullWord;
  final VoidCallback onDismiss;

  const InterventionOverlay({
    super.key,
    required this.syllables,
    required this.fullWord,
    required this.onDismiss,
  });

  @override
  State<InterventionOverlay> createState() => _InterventionOverlayState();
}

class _InterventionOverlayState extends State<InterventionOverlay> {
  late FlutterTts _tts;
  int _highlightedIndex = -1;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initTTS();
    _playSequence();
  }

  Future<void> _initTTS() async {
    try {
      await _tts.setLanguage('si-LK'); // Sinhala
      await _tts.setSpeechRate(0.4);   // Slower speech
      await _tts.setPitch(1.0);
    } catch (e) {
      debugPrint('[Overlay] TTS init error: $e');
    }
  }

  Future<void> _playSequence() async {
    setState(() => _isPlaying = true);

    try {
      // Play each syllable
      for (int i = 0; i < widget.syllables.length; i++) {
        if (!mounted) break;

        setState(() => _highlightedIndex = i);

        await _tts.speak(widget.syllables[i]);
        await Future.delayed(const Duration(milliseconds: 800));
      }

      if (!mounted) return;

      // Play full word
      setState(() => _highlightedIndex = -1);
      await _tts.speak(widget.fullWord);
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted) return;
      setState(() => _isPlaying = false);
    } catch (e) {
      debugPrint('[Overlay] TTS playback error: $e');
      setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _isPlaying ? null : widget.onDismiss,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Text(
                    'අකුරු කියවමු',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Syllable tiles
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: widget.syllables.asMap().entries.map((e) {
                      final isHighlighted = e.key == _highlightedIndex;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? Colors.teal.shade400
                              : Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isHighlighted
                              ? [
                                  BoxShadow(
                                    color: Colors.teal.shade400.withOpacity(0.5),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  )
                                ]
                              : null,
                        ),
                        child: Text(
                          e.value,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: isHighlighted
                                ? Colors.white
                                : Colors.teal.shade900,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Full word display
                  Text(
                    widget.fullWord,
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status indicator
                  Text(
                    _isPlaying ? 'අහන්න...' : 'තිබිය නැති නම් තට කරන්න',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Continue button
                  AnimatedOpacity(
                    opacity: _isPlaying ? 0.5 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: ElevatedButton.icon(
                      onPressed: _isPlaying ? null : widget.onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      icon: const Icon(Icons.check),
                      label: const Text(
                        'දිගටම කරමු',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
  }

  @override
  void dispose() {
    try {
      _tts.stop();
    } catch (e) {
      debugPrint('[Overlay] TTS stop error: $e');
    }
    super.dispose();
  }
}
