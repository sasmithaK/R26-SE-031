import 'package:flutter/material.dart';

// ── Only import screens that actually exist in your screens/ folder ───────────
import 'firefly_tracking_game.dart';
import 'letter_identification_task.dart';
import 'syllable_train_game.dart';
import 'letter_bubble_game.dart';
import 'letter_bubble_game_i.dart';
import 'letter_bubble_game_ga.dart';
import 'letter_bubble_game_ka.dart';
import 'letter_bubble_game_ma.dart';
import 'letter_bubble_game_la.dart';
import 'letter_bubble_game_sa.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  const DashboardScreen({Key? key, this.userName = 'dinithi'}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedNav = 0;

  // ── Nav items ──────────────────────────────────────────────────────────────
  static const List<_NavItem> _navItems = [
    _NavItem(emoji: '⭐', label: 'Top Picks', color: Color(0xFFFFB300)),
    _NavItem(emoji: '🎨', label: 'Activities', color: Color(0xFF43A047)),
    _NavItem(emoji: '🎮', label: 'Games',      color: Color(0xFFE53935)),
  ];

  // ── All cards — assetImage filenames match exactly what is in assets/thumbnails/ ──
  static final List<_Card> _allCards = [
    // ── GAMES ─────────────────────────────────────────────────────────────────
  
    _Card(
      title: 'බුබුලු සෙල්ලම',
      subtitle: 'ස්වර හඳුනාගනිමු',
      tag: 'ක්‍රීඩාව',
      category: 'game',
      assetImage: 'assets/thumbnails/drawing_game.jpg',
      fallbackEmoji: '🫧',
      color1: Color(0xFF00ACC1),
      color2: Color(0xFF00838F),
      screenKey: 'letter_bubbles',
    ),
    _Card(
      title: 'බුබුලු සෙල්ලම - ඉ',
      subtitle: 'ස්වර හඳුනාගනිමු',
      tag: 'ක්‍රීඩාව',
      category: 'game',
      assetImage: 'assets/thumbnails/drawing_game.jpg',
      fallbackEmoji: '🫧',
      color1: Color(0xFF00ACC1),
      color2: Color(0xFF00838F),
      screenKey: 'letter_bubbles_i',
    ),
    _Card(
      title: 'බුබුලු සෙල්ලම - ග',
      subtitle: 'ස්වර හඳුනාගනිමු',
      tag: 'ක්‍රීඩාව',
      category: 'game',
      assetImage: 'assets/thumbnails/drawing_game.jpg',
      fallbackEmoji: '🫧',
      color1: Color(0xFF00ACC1),
      color2: Color(0xFF00838F),
      screenKey: 'letter_bubbles_ga',
    ),
    _Card(
      title: 'බුබුලු සෙල්ලම - ක',
      subtitle: 'ස්වර හඳුනාගනිමු',
      tag: 'ක්‍රීඩාව',
      category: 'game',
      assetImage: 'assets/thumbnails/drawing_game.jpg',
      fallbackEmoji: '🫧',
      color1: Color(0xFF00ACC1),
      color2: Color(0xFF00838F),
      screenKey: 'letter_bubbles_ka',
    ),
    _Card(
      title: 'බුබුලු සෙල්ලම - ම',
      subtitle: 'ස්වර හඳුනාගනිමු',
      tag: 'ක්‍රීඩාව',
      category: 'game',
      assetImage: 'assets/thumbnails/drawing_game.jpg',
      fallbackEmoji: '🫧',
      color1: Color(0xFF00ACC1),
      color2: Color(0xFF00838F),
      screenKey: 'letter_bubbles_ma',
    ),
    _Card(
      title: 'බුබුලු සෙල්ලම - ල',
      subtitle: 'ස්වර හඳුනාගනිමු',
      tag: 'ක්‍රීඩාව',
      category: 'game',
      assetImage: 'assets/thumbnails/drawing_game.jpg',
      fallbackEmoji: '🫧',
      color1: Color(0xFF00ACC1),
      color2: Color(0xFF00838F),
      screenKey: 'letter_bubbles_la',
    ),
    _Card(
      title: 'බුබුලු සෙල්ලම - ස',
      subtitle: 'ස්වර හඳුනාගනිමු',
      tag: 'ක්‍රීඩාව',
      category: 'game',
      assetImage: 'assets/thumbnails/drawing_game.jpg',
      fallbackEmoji: '🫧',
      color1: Color(0xFF00ACC1),
      color2: Color(0xFF00838F),
      screenKey: 'letter_bubbles_sa',
    ),
    _Card(
      title: 'Story Sequencing',
      subtitle: 'Order & Logic',
      tag: 'Game',
      category: 'game',
      assetImage: 'assets/thumbnails/story_sequencing.jpg',
      fallbackEmoji: '📚',
      color1: Color(0xFF1B5E20),
      color2: Color(0xFF2E7D32),
      screenKey: 'story_seq',
    ),
  
    // ── ACTIVITIES ────────────────────────────────────────────────────────────
    _Card(
      title: 'Letter Identification',
      subtitle: 'Alphabet Recognition',
      tag: 'Activity',
      category: 'activity',
      assetImage: 'assets/thumbnails/letter_identification.jpg',
      fallbackEmoji: '🔤',
      color1: Color(0xFFE65100),
      color2: Color(0xFFBF360C),
      screenKey: 'letter_id',
    ),
    _Card(
      title: 'Reading Comprehension',
      subtitle: 'Read & Understand',
      tag: 'Activity',
      category: 'activity',
      assetImage: 'assets/thumbnails/reading_comprehension.jpg',
      fallbackEmoji: '📖',
      color1: Color(0xFF006064),
      color2: Color(0xFF00838F),
      screenKey: 'read_comp',
    ),
    _Card(
      title: 'Reading Fluency',
      subtitle: 'Read Smoothly',
      tag: 'Activity',
      category: 'activity',
      // no image yet — emoji fallback
      assetImage: 'assets/thumbnails/reading_fluency.jpg',
      fallbackEmoji: '🗣️',
      color1: Color(0xFF1565C0),
      color2: Color(0xFF0D47A1),
      screenKey: 'read_fluency',
    ),
    _Card(
      title: 'Story Reading',
      subtitle: 'Fun Stories',
      tag: 'Activity',
      category: 'activity',
      assetImage: 'assets/thumbnails/story_reading.jpg',
      fallbackEmoji: '🌟',
      color1: Color(0xFF4E342E),
      color2: Color(0xFF3E2723),
      screenKey: 'story_read',
    ),
    _Card(
      title: 'Syllable Train',
      subtitle: 'Break Words Apart',
      tag: 'Activity',
      category: 'activity',
      assetImage: 'assets/thumbnails/syllable_train.jpg',
      fallbackEmoji: '🚂',
      color1: Color(0xFF37474F),
      color2: Color(0xFF263238),
      screenKey: 'syllable',
    ),
  ];

  // ── Tab filtering ──────────────────────────────────────────────────────────
  List<_Card> get _currentCards {
    switch (_selectedNav) {
      case 1:  return _allCards.where((c) => c.category == 'activity').toList();
      case 2:  return _allCards.where((c) => c.category == 'game').toList();
      default: return _allCards; // Top Picks = all
    }
  }

  // ── Navigation to real screens ─────────────────────────────────────────────
  void _open(String key) {
    final map = <String, Widget>{
      'firefly':      FireflyTrackingGame(),
      'letter_id':    LetterIdentificationTask(),
      'syllable':     SyllableTrainGame(),
      'letter_bubbles': const LetterBubbleGame(),
      'letter_bubbles_i': const LetterBubbleGameI(),
      'letter_bubbles_ga': const LetterBubbleGameGa(),
      'letter_bubbles_ka': const LetterBubbleGameKa(),
      'letter_bubbles_ma': const LetterBubbleGameMa(),
      'letter_bubbles_la': const LetterBubbleGameLa(),
      'letter_bubbles_sa': const LetterBubbleGameSa(),
    };
    final screen = map[key];
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB3E5FC), Color(0xFF81D4FA), Color(0xFF4FC3F7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              _navBar(),
              Expanded(child: _content()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Learn & Play',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900,
                color: Color(0xFF0D47A1), letterSpacing: 0.5)),
          Row(children: [
            Text('Hi, ${widget.userName}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0))),
            const SizedBox(width: 10),
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.pink.shade200,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [BoxShadow(color: Colors.pink.withOpacity(0.3), blurRadius: 6)],
              ),
              child: const Center(child: Text('😊', style: TextStyle(fontSize: 22))),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Nav bar ────────────────────────────────────────────────────────────────
  Widget _navBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(
            color: Colors.blue.withOpacity(0.15), blurRadius: 14,
            offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final sel  = _selectedNav == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedNav = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? item.color.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: sel ? item.color : Colors.transparent, width: 2),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.color.withOpacity(sel ? 0.22 : 0.10),
                    boxShadow: sel
                        ? [BoxShadow(color: item.color.withOpacity(0.35),
                            blurRadius: 10, spreadRadius: 1)]
                        : [],
                  ),
                  child: Center(child: Text(item.emoji,
                      style: TextStyle(fontSize: sel ? 28 : 24))),
                ),
                const SizedBox(height: 5),
                Text(item.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                    color: sel ? item.color : const Color(0xFF1565C0),
                  )),
              ]),
            ),
          );
        }),
      ),
    );
  }

  // ── Content ────────────────────────────────────────────────────────────────
  Widget _content() {
    final cards    = _currentCards;
    final featured = cards.take(2).toList();   // first 2 → large hero cards
    final rest     = cards.skip(2).toList();   // remaining → grid

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section label ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _selectedNav == 1 ? 'ක්‍රියාකාරකම් (Activities)'
                  : _selectedNav == 2 ? 'ක්‍රීඩා (Games)'
                  : 'ඉහළ තේරීම් (Top Picks)',
              style: const TextStyle(fontSize: 15, color: Color(0xFF1565C0),
                  fontWeight: FontWeight.w700),
            ),
          ),

          // ── Two large hero cards ───────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: featured.map((c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: _heroCard(c),
              ),
            )).toList(),
          ),

          // ── Grid for the rest ──────────────────────────────────────────────
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('More to Explore',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1))),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
              itemCount: rest.length,
              itemBuilder: (_, i) => _gridCard(rest[i]),
            ),
          ],
        ],
      ),
    );
  }

  // ── Hero (large) card ──────────────────────────────────────────────────────
  Widget _heroCard(_Card c) {
    return GestureDetector(
      onTap: () => _open(c.screenKey),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: c.color2.withOpacity(0.45),
              blurRadius: 14, offset: const Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(fit: StackFit.expand, children: [

            // ── Thumbnail (asset image or emoji fallback) ──────────────────
            _thumb(c),

            // ── Dark gradient so text is always readable ───────────────────
            Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, c.color2.withOpacity(0.88)],
                stops: const [0.4, 1.0],
              ),
            )),

            // ── Tag badge ──────────────────────────────────────────────────
            Positioned(top: 12, left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(c.tag, style: TextStyle(
                    color: c.color2, fontSize: 11, fontWeight: FontWeight.bold)),
              )),

            // ── Title + subtitle at bottom ─────────────────────────────────
            Positioned(bottom: 14, left: 14, right: 14,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.title, style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(c.subtitle, style: TextStyle(
                    color: Colors.white.withOpacity(0.88), fontSize: 12)),
              ])),
          ]),
        ),
      ),
    );
  }

  // ── Grid card ──────────────────────────────────────────────────────────────
  Widget _gridCard(_Card c) {
    return GestureDetector(
      onTap: () => _open(c.screenKey),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: c.color1.withOpacity(0.22),
              blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Thumbnail (top ~58%) ───────────────────────────────────────────
          Expanded(
            flex: 58,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Stack(fit: StackFit.expand, children: [
                _thumb(c),
                // subtle bottom fade
                Positioned(bottom: 0, left: 0, right: 0, height: 28,
                  child: Container(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Colors.transparent, c.color2.withOpacity(0.55)],
                    ),
                  ))),
                // tag
                Positioned(top: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: c.color1, borderRadius: BorderRadius.circular(10)),
                    child: Text(c.tag, style: const TextStyle(
                        color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )),
              ]),
            ),
          ),

          // ── Text strip (bottom ~42%) ───────────────────────────────────────
          Expanded(
            flex: 42,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold, color: c.color2),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(c.subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Thumbnail: tries asset, falls back to gradient + big emoji ─────────────
  Widget _thumb(_Card c) {
    return Image.asset(
      c.assetImage,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [c.color1, c.color2],
        )),
        child: Center(child: Text(c.fallbackEmoji,
            style: const TextStyle(fontSize: 64))),
      ),
    );
  }
}

// ── Data models ───────────────────────────────────────────────────────────────

class _NavItem {
  final String emoji, label;
  final Color color;
  const _NavItem({required this.emoji, required this.label, required this.color});
}

class _Card {
  final String title, subtitle, tag, category, assetImage, fallbackEmoji, screenKey;
  final Color color1, color2;
  const _Card({
    required this.title, required this.subtitle, required this.tag,
    required this.category, required this.assetImage, required this.fallbackEmoji,
    required this.color1, required this.color2, required this.screenKey,
  });
}