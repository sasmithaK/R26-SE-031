import 'package:flutter/material.dart';
import '../theme/reading_theme.dart';
import '../services/reading_audio_service.dart';

/// Shared chrome for all activity screens: header, slow/normal toggle, body slot.
class ActivityShell extends StatefulWidget {
  const ActivityShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.builder,
    this.icon,
  });

  final String title;
  final String subtitle;
  final IconData? icon;
  final Widget Function(BuildContext) builder;

  @override
  State<ActivityShell> createState() => _ActivityShellState();
}

class _ActivityShellState extends State<ActivityShell> {
  bool _slow = false;
  final _audio = ReadingAudioService.instance;

  @override
  void initState() {
    super.initState();
    _audio.init();
  }

  Future<void> _toggleRate(bool slow) async {
    setState(() => _slow = slow);
    await _audio.setRate(slow ? 0.30 : 0.45);
  }

  @override
  void dispose() {
    _audio.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: const BackButton(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HeaderCard(
                icon: widget.icon ?? Icons.menu_book_rounded,
                subtitle: widget.subtitle,
                slow: _slow,
                onToggle: _toggleRate,
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<TtsStatus>(
                valueListenable: _audio.status,
                builder: (_, s, __) => _TtsBanner(status: s),
              ),
              const SizedBox(height: 8),
              Expanded(child: widget.builder(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.icon,
    required this.subtitle,
    required this.slow,
    required this.onToggle,
  });

  final IconData icon;
  final String subtitle;
  final bool slow;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ReadingKidTheme.card,
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        border: Border.all(color: ReadingKidTheme.primary.withOpacity(.15)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: ReadingKidTheme.primary.withOpacity(.12),
            radius: 26,
            child: Icon(icon, color: ReadingKidTheme.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(subtitle, style: ReadingKidTheme.hint),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              const Text('හෙමි',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              Switch.adaptive(value: slow, onChanged: onToggle),
            ],
          ),
        ],
      ),
    );
  }
}

class _TtsBanner extends StatelessWidget {
  const _TtsBanner({required this.status});
  final TtsStatus status;

  @override
  Widget build(BuildContext context) {
    final hasBackend = status.backendOnline;
    final hasDeviceSinhala = status.ttsSinhalaSupported;
    final sinhalaOk = hasBackend || hasDeviceSinhala;

    final color = status.error != null
        ? Colors.redAccent
        : (sinhalaOk ? ReadingKidTheme.primary : const Color(0xFFEF6C00));
    final icon = status.error != null
        ? Icons.error_outline_rounded
        : (sinhalaOk ? Icons.check_circle_rounded : Icons.info_outline_rounded);

    String message;
    if (status.error != null) {
      message = 'හඬ දෝෂයකි: ${status.error}';
    } else if (status.ttsLanguage == '...') {
      message = 'හඬ පූරණය වෙමින්...';
    } else if (hasBackend) {
      message = 'සිංහල හඬ සූදානම් 🔊';
    } else if (hasDeviceSinhala) {
      message = 'හඬ සූදානම්: ${status.ttsLanguage}';
    } else {
      message = 'සේවාව ක්\u200dරියා නොකරයි. intervention-service පටන් ගන්න.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (status.speaking)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

/// Big circular play button.
class PlayButton extends StatelessWidget {
  const PlayButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon = Icons.volume_up_rounded,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ReadingKidTheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
          boxShadow: [
            BoxShadow(
              color: c.withOpacity(.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A coloured chip (used for syllable boxes / chunks).
class ChunkBox extends StatelessWidget {
  const ChunkBox({
    super.key,
    required this.text,
    this.active = false,
    this.onTap,
    this.color,
  });

  final String text;
  final bool active;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final base = color ?? ReadingKidTheme.accent;
    return Material(
      color: active ? base : base.withOpacity(.10),
      borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(ReadingKidTheme.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          constraints: const BoxConstraints(minWidth: 80, minHeight: 64),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : ReadingKidTheme.textMain,
            ),
          ),
        ),
      ),
    );
  }
}
