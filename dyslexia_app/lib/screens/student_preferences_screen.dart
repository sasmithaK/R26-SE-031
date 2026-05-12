import 'package:flutter/material.dart';

class StudentPreferencesScreen extends StatefulWidget {
  const StudentPreferencesScreen({super.key});

  @override
  State<StudentPreferencesScreen> createState() => _StudentPreferencesScreenState();
}

class _StudentPreferencesScreenState extends State<StudentPreferencesScreen> {
  final List<_ColorChoice> _colorOptions = const [
    _ColorChoice('සුදු', Color(0xFFFFFFFF), Color(0xFFE0E0E0)),
    _ColorChoice('නිල්', Color(0xFFE3F2FD), Color(0xFF90CAF9)),
    _ColorChoice('කහ', Color(0xFFFFFDE7), Color(0xFFFFF176)),
    _ColorChoice('කොළ', Color(0xFFE8F5E9), Color(0xFFA5D6A7)),
    _ColorChoice('රෝස', Color(0xFFFCE4EC), Color(0xFFF48FB1)),
    _ColorChoice('දම්', Color(0xFFF3E5F5), Color(0xFFCE93D8)),
    _ColorChoice('ලා නිල්', Color(0xFFE1F5FE), Color(0xFF81D4FA)),
  ];

  final List<double> _fontOptions = const [14, 16, 18, 20, 24, 28, 32];

  int _selectedColorIndex = 0;
  int _selectedFontIndex = 2;

  double get _fontSize => _fontOptions[_selectedFontIndex];

  Color get _previewBackground => _colorOptions[_selectedColorIndex].background;

  Color get _previewAccent => _colorOptions[_selectedColorIndex].accent;

  void _saveAndContinue() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    Navigator.pushNamed(context, '/wcag_assessment', arguments: {
      'preferredColorIndex': _selectedColorIndex,
      'preferredFontSize': _fontSize,
      'studentName': args != null && args['studentName'] != null ? args['studentName'] as String : '',
      'studentAge': args != null && args['studentAge'] != null ? args['studentAge'] as String : '',
      'studentGrade': args != null && args['studentGrade'] != null ? args['studentGrade'] as String : '',
      'totalScore': args != null && args['totalScore'] != null ? args['totalScore'] as int : 0,
      'tier': args != null && args['tier'] != null ? args['tier'] as String : 'Tier 1',
      'isNewStudent': args != null && args['isNewStudent'] == true,
    });
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final studentName = args != null && args['studentName'] != null ? args['studentName'] as String : '';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF7),
      appBar: AppBar(
        title: const Text('මගේ කැමතිකම්'),
        backgroundColor: const Color(0xFFFFC857),
        foregroundColor: Colors.brown.shade900,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFFDF7), Color(0xFFF3F8FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(studentName),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: '1. පාටක් තෝරන්න',
                  subtitle: 'ඔබට පහසුම පාට එකක් තෝරන්න.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_colorOptions.length, (index) {
                      final option = _colorOptions[index];
                      final isSelected = _selectedColorIndex == index;
                      return AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: isSelected ? 1.05 : 1.0,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedColorIndex = index),
                          child: Container(
                            width: 92,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: option.background,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected ? Colors.brown : option.accent,
                                width: isSelected ? 3 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: option.accent.withValues(alpha: 0.12),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: option.accent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.brush, color: Colors.white, size: 22),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  option.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  title: '2. අකුරු ප්‍රමාණය තෝරන්න',
                  subtitle: 'ලොකුද? කුඩද? ඔබට සුවපහසු එකක් තෝරන්න.',
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(_fontOptions.length, (index) {
                      final isSelected = _selectedFontIndex == index;
                      final size = _fontOptions[index];
                      return ChoiceChip(
                        label: Text('${size.toInt()}'),
                        selected: isSelected,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.brown.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                        backgroundColor: Colors.white,
                        selectedColor: Colors.orangeAccent,
                        onSelected: (_) => setState(() => _selectedFontIndex = index),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 14),
                _buildPreviewCard(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _saveAndContinue,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14.0),
                    child: Text('සුරකින්න සහ ඉදිරියට යන්න', style: TextStyle(fontSize: 17)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A65),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String studentName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3B0), Color(0xFFFFDDE2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.asset(
              'assets/images/student_icon.png',
              width: 78,
              height: 78,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName.isNotEmpty ? '$studentName, අපි තෝරමු.' : 'අපි තෝරමු.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.brown.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ඔබට පහසු පාට සහ අකුරු තෝරන්න.',
                  style: TextStyle(fontSize: 15, height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Image.asset(
            'assets/images/welcome_owl.png',
            width: 52,
            height: 52,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required String subtitle, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.brown.shade600),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _previewBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _previewAccent.withValues(alpha: 0.5), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded, color: _previewAccent),
              const SizedBox(width: 8),
              const Text('පෙරදසුන', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'මෙම ලිපිය කියවන්න. එය ඔබට සුවපහසු ද?',
            style: TextStyle(fontSize: _fontSize, height: 1.45),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 74,
                  decoration: BoxDecoration(
                    color: _previewAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Icon(Icons.auto_awesome, color: _previewAccent, size: 30),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 74,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Icon(Icons.menu_book_rounded, color: Colors.brown.shade400, size: 30),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorChoice {
  const _ColorChoice(this.label, this.background, this.accent);

  final String label;
  final Color background;
  final Color accent;
}
