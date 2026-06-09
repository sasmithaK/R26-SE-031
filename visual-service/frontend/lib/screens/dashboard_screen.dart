import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({Key? key, this.userName = 'dinithi'}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNav = 0;

  final List<_NavItem> _navItems = [
    _NavItem(emoji: '⭐', label: 'Top Picks', color: Color(0xFFFFCC00)),
    _NavItem(emoji: '🎮', label: 'Activities', color: Color(0xFF4CAF50)),
    _NavItem(emoji: '🧩', label: 'Games', color: Color(0xFFFF6B6B)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB2EBF2), Color(0xFF81D4FA), Color(0xFF4FC3F7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              _buildNavBar(),
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Hi, ${widget.userName}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1565C0),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.pink.shade200,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                'https://api.dicebear.com/7.x/bottts/png?seed=${widget.userName}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.face, color: Colors.white, size: 26),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final selected = _selectedNav == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedNav = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? item.color.withOpacity(0.18) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: selected
                    ? Border.all(color: item.color, width: 2)
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNavIcon(item, selected),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? item.color : const Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavIcon(_NavItem item, bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: item.color.withOpacity(selected ? 0.25 : 0.12),
        boxShadow: selected
            ? [BoxShadow(color: item.color.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
            : [],
      ),
      child: Center(
        child: Text(item.emoji, style: TextStyle(fontSize: selected ? 28 : 24)),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Featured'),
          const SizedBox(height: 10),
          _buildFeaturedRow(),
          const SizedBox(height: 18),
          _buildSectionTitle('Keep Learning'),
          const SizedBox(height: 10),
          _buildGridCards(),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0D47A1),
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildFeaturedRow() {
    final featured = [
      _ContentCard(
        title: 'Word Beach',
        subtitle: 'Reading',
        color1: const Color(0xFF42A5F5),
        color2: const Color(0xFF1976D2),
        emoji: '🏖️',
        progress: 0.45,
        tag: 'In Progress',
      ),
      _ContentCard(
        title: 'Letter Hunt',
        subtitle: 'Alphabet',
        color1: const Color(0xFF66BB6A),
        color2: const Color(0xFF2E7D32),
        emoji: '🔍',
        progress: 0.0,
        tag: 'New',
      ),
    ];

    return Row(
      children: featured
          .map((card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _buildFeaturedCard(card),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildFeaturedCard(_ContentCard card) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [card.color1, card.color2],
        ),
        boxShadow: [
          BoxShadow(
            color: card.color2.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background emoji
          Positioned(
            right: -10,
            top: -10,
            child: Text(card.emoji, style: const TextStyle(fontSize: 80)),
          ),
          // Tag
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                card.tag,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Bottom info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: card.color2,
                    ),
                  ),
                  if (card.progress > 0) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: card.progress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(card.color1),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridCards() {
    final items = [
      _GridCard(title: 'Sound It Out', emoji: '🔊', color: const Color(0xFFFF8A65), subtitle: 'Phonics'),
      _GridCard(title: 'Spell & Win', emoji: '✏️', color: const Color(0xFFAB47BC), subtitle: 'Spelling'),
      _GridCard(title: 'Story Time', emoji: '📖', color: const Color(0xFF26A69A), subtitle: 'Reading'),
      _GridCard(title: 'Word Match', emoji: '🧠', color: const Color(0xFFEF5350), subtitle: 'Memory'),
      _GridCard(title: 'Trace It', emoji: '🖊️', color: const Color(0xFFFFCA28), subtitle: 'Writing'),
      _GridCard(title: 'Animal ABCs', emoji: '🦁', color: const Color(0xFF42A5F5), subtitle: 'Alphabet'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildGridCard(items[i]),
    );
  }

  Widget _buildGridCard(_GridCard card) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: card.color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: card.color.withOpacity(0.15),
              ),
              child: Center(
                child: Text(card.emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              card.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: card.color.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              card.subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final String emoji;
  final String label;
  final Color color;
  _NavItem({required this.emoji, required this.label, required this.color});
}

class _ContentCard {
  final String title;
  final String subtitle;
  final Color color1;
  final Color color2;
  final String emoji;
  final double progress;
  final String tag;
  _ContentCard({
    required this.title,
    required this.subtitle,
    required this.color1,
    required this.color2,
    required this.emoji,
    required this.progress,
    required this.tag,
  });
}

class _GridCard {
  final String title;
  final String emoji;
  final Color color;
  final String subtitle;
  _GridCard({required this.title, required this.emoji, required this.color, required this.subtitle});
}