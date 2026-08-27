import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../../theme/app_theme.dart';

enum CharacterType {
  human,
  mascot,
}

class CharacterConfig {
  final String name;
  final String assetPath;
  final Color color;
  final CharacterType type;
  final bool isLocked;

  const CharacterConfig({
    required this.name,
    required this.assetPath,
    required this.color,
    required this.type,
    this.isLocked = false,
  });
}

class CharacterShopScreen extends StatefulWidget {
  const CharacterShopScreen({super.key});

  @override
  State<CharacterShopScreen> createState() => _CharacterShopScreenState();
}

class _CharacterShopScreenState extends State<CharacterShopScreen> with TickerProviderStateMixin {
  static const List<CharacterConfig> _allCharacters = [
    // --- Humans (Unused in Profile Selection) ---
    CharacterConfig(name: 'Leo', assetPath: 'assets/images/characters/human/human_student_7.png', color: AppColors.calmBlue, type: CharacterType.human),
    CharacterConfig(name: 'Mia', assetPath: 'assets/images/characters/human/human_student_8.png', color: AppColors.gentleGreen, type: CharacterType.human),
    CharacterConfig(name: 'Sam', assetPath: 'assets/images/characters/human/human_student_9.png', color: AppColors.warmAmber, type: CharacterType.human),
    CharacterConfig(name: 'Zoe', assetPath: 'assets/images/characters/human/human_student_10.png', color: AppColors.softCoral, type: CharacterType.human, isLocked: true),
    CharacterConfig(name: 'Max', assetPath: 'assets/images/characters/human/human_student_11.png', color: Colors.purpleAccent, type: CharacterType.human, isLocked: true),
    CharacterConfig(name: 'Ava', assetPath: 'assets/images/characters/human/human_student_12.png', color: Colors.teal, type: CharacterType.human, isLocked: true),
    
    // --- Mascots (Unused in Profile Selection) ---
    CharacterConfig(name: 'Blue Blob', assetPath: 'assets/images/characters/mascots/blue_monster.png', color: AppColors.calmBlue, type: CharacterType.mascot),
    CharacterConfig(name: 'Pink Berry', assetPath: 'assets/images/characters/mascots/pink_monster.png', color: AppColors.softCoral, type: CharacterType.mascot),
    CharacterConfig(name: 'Yellow Star', assetPath: 'assets/images/characters/mascots/yellow_monster.png', color: AppColors.warmAmber, type: CharacterType.mascot),
    CharacterConfig(name: 'Green Slime', assetPath: 'assets/images/characters/mascots/green_monster.png', color: AppColors.gentleGreen, type: CharacterType.mascot, isLocked: true),
    CharacterConfig(name: 'Blue Jump', assetPath: 'assets/images/characters/mascots/mascot_blue_jumping.png', color: Colors.teal, type: CharacterType.mascot, isLocked: true),
    CharacterConfig(name: 'Yellow Solo', assetPath: 'assets/images/characters/mascots/solo_yellow.png', color: Colors.orangeAccent, type: CharacterType.mascot, isLocked: true),
  ];

  late AnimationController _gridController;
  CharacterType _selectedCategory = CharacterType.human;
  int _selectedIndex = 0;

  List<CharacterConfig> get _filteredCharacters => 
      _allCharacters.where((c) => c.type == _selectedCategory).toList();

  @override
  void initState() {
    super.initState();
    _gridController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _gridController.dispose();
    super.dispose();
  }

  void _selectCategory(CharacterType type) {
    if (_selectedCategory == type) return;
    setState(() {
      _selectedCategory = type;
      _selectedIndex = 0;
    });
    _gridController.forward(from: 0.0);
  }

  void _selectCharacter(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final characters = _filteredCharacters;
    final selectedCharacter = characters.isNotEmpty ? characters[_selectedIndex] : _allCharacters.first;

    return Scaffold(
      backgroundColor: AppColors.cream, // Matched with app theme
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 24),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'යාලුවෙක් තෝරමු',
          style: AppTypography.heading(fontSize: 22, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Background ambient glow based on selected character, lightened for light theme
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            top: -100,
            left: -100,
            right: -100,
            height: 600,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    selectedCharacter.color.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.8],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Custom Tab Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadow,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _buildTab('ළමුන්', CharacterType.human),
                        _buildTab('සුරතලුන්', CharacterType.mascot),
                      ],
                    ),
                  ),
                ),

                // Main Stage
                Expanded(
                  flex: 5,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Stage base/pedestal
                      Positioned(
                        bottom: 30,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 220,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selectedCharacter.color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                            boxShadow: [
                              BoxShadow(
                                color: selectedCharacter.color.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 160,
                              height: 20,
                              decoration: BoxDecoration(
                                color: selectedCharacter.color.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(100),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      // Static Character Image
                      Image.asset(
                        selectedCharacter.assetPath,
                        width: 260,
                        height: 260,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),

                // Bottom Character Grid Selection
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowMedium,
                          blurRadius: 30,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 60,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColors.borderLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'යාලුවෙක් තෝරන්න',
                                style: AppTypography.heading(
                                  fontSize: 22,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                '${characters.where((c) => !c.isLocked).length}/${characters.length} ක් විවෘතයි',
                                style: AppTypography.caption(
                                  fontSize: 16,
                                  color: AppColors.calmBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              childAspectRatio: 0.85,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: characters.length,
                            itemBuilder: (context, index) {
                              final config = characters[index];
                              final isSelected = index == _selectedIndex;

                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.5),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: _gridController,
                                  curve: Interval(index * 0.1, 1.0, curve: Curves.easeOutBack),
                                )),
                                child: GestureDetector(
                                  onTap: () => _selectCharacter(index),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    decoration: BoxDecoration(
                                      color: isSelected ? config.color.withValues(alpha: 0.1) : Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isSelected ? config.color : AppColors.borderLight,
                                        width: isSelected ? 3 : 1,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: config.color.withValues(alpha: 0.2),
                                                blurRadius: 12,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : [
                                              BoxShadow(
                                                color: AppColors.shadow,
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              )
                                            ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Hero(
                                            tag: 'char_${config.name}',
                                            child: Image.asset(
                                              config.assetPath,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                        if (config.isLocked)
                                          Positioned.fill(
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(21),
                                              child: BackdropFilter(
                                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                                child: Container(
                                                  color: AppColors.cream.withValues(alpha: 0.4),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons.lock_rounded,
                                                      color: AppColors.textPrimary,
                                                      size: 32,
                                                    ),
                                                  ),
                                                ),
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
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, CharacterType type) {
    final isSelected = _selectedCategory == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => _selectCategory(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.calmBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.calmBlue.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              title,
              style: AppTypography.button(
                fontSize: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
