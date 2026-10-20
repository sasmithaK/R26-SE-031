import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/localization_service.dart';
import '../../services/therapist_dashboard_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/dashboard/dashboard_kit.dart';
import 'therapist_messages_screen.dart';
import 'therapist_profile_screen.dart';
import 'therapist_student_detail_screen.dart';
import 'therapist_students_screen.dart';

class TherapistDashboardScreen extends StatefulWidget {
  const TherapistDashboardScreen({super.key});

  @override
  State<TherapistDashboardScreen> createState() =>
      _TherapistDashboardScreenState();
}

class _TherapistDashboardScreenState extends State<TherapistDashboardScreen> {
  final _service = TherapistDashboardService();
  int _tab = 0;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _dashboard;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final values = await Future.wait<dynamic>([
        AuthService().getUserProfile(),
        _service.getDashboardSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = values[0] as Map<String, dynamic>?;
        _dashboard = values[1] as Map<String, dynamic>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.cream,
        body: IndexedStack(
          index: _tab,
          children: [
            _DashboardHome(
              profile: _profile,
              data: _dashboard,
              loading: _loading,
              error: _error,
              onRefresh: _load,
              onProfileTap: () => setState(() => _tab = 3),
            ),
            const TherapistStudentsScreen(),
            const TherapistMessagesScreen(),
            const TherapistProfileScreen(),
          ],
        ),
        bottomNavigationBar: _DashboardNavigation(
          selected: _tab,
          onSelected: (index) {
            setState(() => _tab = index);
            if (index == 0) _load();
          },
        ),
      ),
    );
  }
}

class _DashboardNavigation extends StatelessWidget {
  const _DashboardNavigation({
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.space_dashboard_outlined,
        Icons.space_dashboard_rounded,
        LocalizationService.instance.t('dash_nav_home'),
      ),
      (
        Icons.people_outline_rounded,
        Icons.people_rounded,
        LocalizationService.instance.t('nav_students'),
      ),
      (
        Icons.chat_bubble_outline_rounded,
        Icons.chat_bubble_rounded,
        LocalizationService.instance.t('messages'),
      ),
      (
        Icons.person_outline_rounded,
        Icons.person_rounded,
        LocalizationService.instance.t('nav_profile'),
      ),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        border: const Border(top: BorderSide(color: AppColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlueDark.withValues(alpha: .08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: List.generate(items.length, (index) {
              final active = index == selected;
              final item = items[index];
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: item.$3,
                  child: InkWell(
                    onTap: () => onSelected(index),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.calmBlue.withValues(alpha: .11)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            active ? item.$2 : item.$1,
                            size: 24,
                            color: active
                                ? AppColors.calmBlue
                                : AppColors.textHint,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            item.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DashText.caption(
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active
                                  ? AppColors.calmBlueDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _DashboardHome extends StatelessWidget {
  const _DashboardHome({
    required this.profile,
    required this.data,
    required this.loading,
    required this.error,
    required this.onRefresh,
    required this.onProfileTap,
  });
  final Map<String, dynamic>? profile;
  final Map<String, dynamic>? data;
  final bool loading;
  final String? error;
  final Future<void> Function() onRefresh;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    if (loading && data == null) return const _LoadingView();
    if (error != null && data == null) {
      return _ErrorView(message: error!, onRetry: onRefresh);
    }
    final payload = data ?? <String, dynamic>{};
    final summary = _map(payload['summary']);
    final queue = _list(payload['review_queue']);
    final recent = _list(payload['recent_activity']);
    final connected = _integer(summary['connected_learners']);
    final covered = _integer(summary['learners_with_evidence']);
    final priorities = _integer(summary['review_priorities']);
    final observed = _integer(summary['observed_core_tasks']);
    final independent = _integer(summary['independent_core_tasks']);
    final supported = _integer(summary['supported_core_tasks']);
    final checks = _integer(summary['confirmation_checks']);
    final rate = _decimal(summary['independent_rate']);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.calmBlue,
        backgroundColor: AppColors.cardSurface,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            _Header(
              profile: profile,
              onRefresh: onRefresh,
              onProfileTap: onProfileTap,
            ),
            const SizedBox(height: 22),
            _Hero(
              connected: connected,
              covered: covered,
              observed: observed,
              priorities: priorities,
            ),
            const SizedBox(height: 20),
            _MetricGrid(
              connected: connected,
              priorities: priorities,
              observed: observed,
              independent: independent,
              rate: rate,
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              eyebrow: 'REMOTE MONITORING',
              title: 'Needs attention',
              subtitle: 'Inactivity, unclear recordings, repeated fatigue.',
            ),
            const SizedBox(height: 12),
            DashCard(
              child: AlertList(
                alerts: _list(payload['alerts']),
                showStudentName: true,
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(
              eyebrow: 'PRIORITY WORKLIST',
              title: 'Learners to review',
              subtitle: queue.isEmpty
                  ? 'No review priority is currently identified.'
                  : 'Ordered from observed task evidence—not diagnostic labels.',
              badge: queue.isEmpty ? null : '${queue.length}',
            ),
            const SizedBox(height: 12),
            if (queue.isEmpty)
              const _EmptyPriorityCard()
            else
              ...queue
                  .take(6)
                  .map(
                    (learner) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ReviewCard(learner: learner),
                    ),
                  ),
            const SizedBox(height: 18),
            const _SectionTitle(
              eyebrow: 'ADAPTIVE SUPPORT',
              title: 'How learning is progressing',
              subtitle: 'Independent work, app support, and fresh checks.',
            ),
            const SizedBox(height: 12),
            _SupportCard(
              observed: observed,
              independent: independent,
              supported: supported,
              checks: checks,
            ),
            const SizedBox(height: 28),
            const _SectionTitle(
              eyebrow: 'LATEST EVIDENCE',
              title: 'Recent observed learning',
              subtitle: 'Most recent completed Component 4 task outcomes.',
            ),
            const SizedBox(height: 12),
            _RecentCard(rows: recent),
            const SizedBox(height: 20),
            _EvidenceNotice(
              coverage: payload['coverage_note']?.toString(),
              limitations: _strings(payload['limitations']),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.onRefresh,
    required this.onProfileTap,
  });
  final Map<String, dynamic>? profile;
  final Future<void> Function() onRefresh;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final raw = profile?['name']?.toString().trim();
    final name = raw == null || raw.isEmpty ? 'Therapist' : raw;
    final picture = profile?['profile_picture_url']?.toString();
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: DashText.body(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DashText.heading(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Learning overview',
                style: DashText.caption(fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Refresh evidence',
          onPressed: () => onRefresh(),
          icon: const Icon(Icons.refresh_rounded),
          style: IconButton.styleFrom(
            foregroundColor: AppColors.calmBlueDark,
            backgroundColor: AppColors.slateBg,
            minimumSize: const Size(48, 48),
          ),
        ),
        const SizedBox(width: 10),
        Semantics(
          button: true,
          label: 'Open therapist profile',
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.blueButtonGradient,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 2),
                image: picture != null && picture.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(picture),
                        fit: BoxFit.cover,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.calmBlue.withValues(alpha: .22),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: picture == null || picture.isEmpty
                  ? Text(
                      _initials(name),
                      style: DashText.button(fontSize: 16),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.connected,
    required this.covered,
    required this.observed,
    required this.priorities,
  });
  final int connected, covered, observed, priorities;

  @override
  Widget build(BuildContext context) {
    final ratio = connected == 0 ? 0.0 : covered / connected;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF327CC4), Color(0xFF5C9DCE), Color(0xFF70B7A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.calmBlueDark.withValues(alpha: .22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _HeroIcon(icon: Icons.insights_rounded),
              const Spacer(),
              _HeroPill(text: '$observed observed tasks'),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            priorities > 0
                ? '$priorities learner${priorities == 1 ? '' : 's'} ready for review'
                : 'Learning evidence is up to date',
            style: DashText.heading(
              fontSize: 29,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            connected == 0
                ? 'Connect a learner to begin receiving observed learning evidence.'
                : '$covered of $connected connected learners have recorded task evidence.',
            style: DashText.body(
              fontSize: 14,
              color: Colors.white.withValues(alpha: .91),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: .2),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${(ratio * 100).round()}% evidence coverage',
            style: DashText.caption(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  const _HeroIcon({required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    width: 48,
    height: 48,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .17),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Icon(icon, color: Colors.white, size: 27),
  );
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .17),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: DashText.caption(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({
    required this.connected,
    required this.priorities,
    required this.observed,
    required this.independent,
    required this.rate,
  });
  final int connected, priorities, observed, independent;
  final double? rate;
  @override
  Widget build(BuildContext context) {
    final cards = [
      _Metric(
        Icons.people_alt_rounded,
        'Connected learners',
        '$connected',
        'Active care connections',
        AppColors.calmBlue,
        AppColors.slateBg,
      ),
      _Metric(
        Icons.flag_rounded,
        'Review priorities',
        '$priorities',
        'Evidence to inspect',
        priorities > 0 ? AppColors.softCoral : AppColors.gentleGreen,
        priorities > 0 ? const Color(0xFFFFECE8) : AppColors.mintBg,
      ),
      _Metric(
        Icons.fact_check_rounded,
        'Observed tasks',
        '$observed',
        'Latest core outcomes',
        AppColors.warmAmber,
        const Color(0xFFFFF1D9),
      ),
      _Metric(
        Icons.psychology_alt_rounded,
        'Independent first try',
        rate == null ? '—' : '${(rate! * 100).round()}%',
        '$independent tasks without hints',
        AppColors.gentleGreenDark,
        AppColors.mintBg,
      ),
    ];
    return LayoutBuilder(
      builder: (_, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: width,
                  child: _MetricCard(metric: card),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _Metric {
  const _Metric(
    this.icon,
    this.label,
    this.value,
    this.note,
    this.color,
    this.tint,
  );
  final IconData icon;
  final String label, value, note;
  final Color color, tint;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 154),
    padding: const EdgeInsets.all(16),
    decoration: _cardDecoration(radius: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: metric.tint,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(metric.icon, size: 20, color: metric.color),
            ),
            const Spacer(),
            Text(
              metric.value,
              style: DashText.heading(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: metric.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          metric.label,
          maxLines: 2,
          style: DashText.body(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          metric.note,
          maxLines: 2,
          style: DashText.caption(fontSize: 12),
        ),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.badge,
  });
  final String eyebrow, title, subtitle;
  final String? badge;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: DashText.caption(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.calmBlueDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: DashText.heading(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: DashText.body(fontSize: 13, height: 1.45),
            ),
          ],
        ),
      ),
      if (badge != null)
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFECE8),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            badge!,
            style: DashText.body(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.softCoralDark,
            ),
          ),
        ),
    ],
  );
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.learner});
  final Map<String, dynamic> learner;
  @override
  Widget build(BuildContext context) {
    final name = learner['student_name']?.toString() ?? 'Learner';
    final awaiting = learner['status'] == 'awaiting_evidence';
    final observed = _integer(learner['observed_tasks']);
    final supported = _integer(learner['supported_tasks']);
    final checks = _integer(learner['confirmation_checks']);
    final weakest = _map(learner['weakest_area']);
    final mastery = _decimal(weakest['mastery']);
    final accent = awaiting ? AppColors.warmAmber : AppColors.softCoral;
    final tint = awaiting ? const Color(0xFFFFF4DF) : const Color(0xFFFFECE8);
    return Material(
      color: AppColors.cardSurface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TherapistStudentDetailScreen(student: learner),
          ),
        ),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: .24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: tint,
                    child: Text(
                      _initials(name),
                      style: DashText.body(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DashText.body(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          learner['grade']?.toString() ?? 'Grade 1',
                          style: DashText.caption(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: awaiting ? 'Awaiting evidence' : 'Review',
                    color: accent,
                    tint: tint,
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                learner['review_title']?.toString() ?? 'Learning evidence',
                style: DashText.body(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                learner['review_reason']?.toString() ?? '',
                style: DashText.body(fontSize: 12, height: 1.45),
              ),
              if (observed > 0) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _EvidenceChip('$observed observed', AppColors.calmBlue),
                    _EvidenceChip('$supported supported', AppColors.warmAmber),
                    _EvidenceChip('$checks checks', AppColors.gentleGreenDark),
                    if (weakest.isNotEmpty && mastery != null)
                      _EvidenceChip(
                        '${weakest['name']}: mastery estimate ${(mastery * 100).round()}% (${_integer(weakest['observations'])} responses)',
                        AppColors.softCoralDark,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _CoverageChips(coverage: _map(learner['coverage'])),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Open learner evidence',
                    style: DashText.body(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.calmBlueDark,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.calmBlueDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.tint,
  });
  final String label;
  final Color color, tint;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: DashText.caption(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

class _EvidenceChip extends StatelessWidget {
  const _EvidenceChip(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: DashText.caption(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );
}

class _EmptyPriorityCard extends StatelessWidget {
  const _EmptyPriorityCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.mintBg,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.borderGreen),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          color: AppColors.gentleGreenDark,
          size: 34,
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            'No connected learner currently crosses the review threshold.',
            style: DashText.body(fontSize: 13, height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required this.observed,
    required this.independent,
    required this.supported,
    required this.checks,
  });
  final int observed, independent, supported, checks;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: _cardDecoration(radius: 24),
    child: Column(
      children: [
        _SupportRow(
          Icons.visibility_rounded,
          AppColors.calmBlue,
          observed,
          'Tasks observed',
          'Latest unique core task outcomes',
        ),
        const _SupportDivider(),
        _SupportRow(
          Icons.favorite_rounded,
          AppColors.gentleGreenDark,
          independent,
          'Independent first try',
          'Correct without an app hint',
        ),
        const _SupportDivider(),
        _SupportRow(
          Icons.pan_tool_alt_rounded,
          AppColors.warmAmber,
          supported,
          'Completed with support',
          'A scaffold helped completion',
        ),
        const _SupportDivider(),
        _SupportRow(
          Icons.verified_rounded,
          AppColors.calmBlueDark,
          checks,
          'Fresh learning checks',
          'Confirmation tasks after support',
        ),
      ],
    ),
  );
}

class _SupportRow extends StatelessWidget {
  const _SupportRow(
    this.icon,
    this.color,
    this.value,
    this.title,
    this.description,
  );
  final IconData icon;
  final Color color;
  final int value;
  final String title, description;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: DashText.body(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(description, style: DashText.caption(fontSize: 12)),
          ],
        ),
      ),
      Text(
        '$value',
        style: DashText.heading(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    ],
  );
}

class _SupportDivider extends StatelessWidget {
  const _SupportDivider();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 25,
    child: Padding(
      padding: EdgeInsets.only(left: 21),
      child: Align(
        alignment: Alignment.centerLeft,
        child: VerticalDivider(width: 1, color: AppColors.borderLight),
      ),
    ),
  );
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.rows});
  final List<Map<String, dynamic>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: _cardDecoration(radius: 22),
        child: Row(
          children: [
            const Icon(
              Icons.history_toggle_off_rounded,
              color: AppColors.textHint,
              size: 32,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                'No completed learning outcomes are available yet.',
                style: DashText.body(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
    final visible = rows.take(6).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        children: List.generate(visible.length, (index) {
          final row = visible[index];
          final type = row['event_type']?.toString() ?? 'supported';
          final color = type == 'independent'
              ? AppColors.gentleGreenDark
              : type == 'confirmation'
              ? AppColors.calmBlue
              : AppColors.warmAmber;
          final icon = type == 'independent'
              ? Icons.auto_awesome_rounded
              : type == 'confirmation'
              ? Icons.verified_outlined
              : Icons.lightbulb_outline_rounded;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 39,
                      height: 39,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row['student_name']?.toString() ?? 'Learner',
                            style: DashText.body(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            row['description']?.toString() ??
                                'Completed a learning task.',
                            style: DashText.caption(fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _activityMeta(row),
                            style: DashText.caption(
                              fontSize: 12,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (index != visible.length - 1)
                const Divider(height: 1, color: AppColors.borderLight),
            ],
          );
        }),
      ),
    );
  }
}

class _EvidenceNotice extends StatelessWidget {
  const _EvidenceNotice({required this.coverage, required this.limitations});
  final String? coverage;
  final List<String> limitations;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.slateBg.withValues(alpha: .55),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.borderBlue),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.calmBlueDark,
          size: 21,
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (coverage != null && coverage!.isNotEmpty)
                Text(
                  coverage!,
                  style: DashText.body(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              if (limitations.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  limitations.first,
                  style: DashText.caption(fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          Container(
            width: 180,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.slateBg,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 28),
          Container(
            height: 238,
            decoration: BoxDecoration(
              color: AppColors.slateBg,
              borderRadius: BorderRadius.circular(28),
            ),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(color: AppColors.calmBlue),
          ),
          const SizedBox(height: 22),
          Text(
            'Preparing observed learning evidence…',
            style: DashText.body(fontSize: 14),
          ),
        ],
      ),
    ),
  );
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: _cardDecoration(radius: 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: AppColors.softCoral,
              ),
              const SizedBox(height: 14),
              Text(
                'Learning evidence is unavailable',
                textAlign: TextAlign.center,
                style: DashText.heading(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: DashText.body(fontSize: 12),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

BoxDecoration _cardDecoration({required double radius}) => BoxDecoration(
  color: AppColors.cardSurface,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: AppColors.borderLight),
  boxShadow: [
    BoxShadow(
      color: AppColors.textPrimary.withValues(alpha: .04),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ],
);

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

List<String> _strings(dynamic value) =>
    value is List ? value.map((item) => item.toString()).toList() : <String>[];

int _integer(dynamic value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;

double? _decimal(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'T';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _activityMeta(Map<String, dynamic> row) {
  final parts = <String>[];
  final activity = row['activity_id']?.toString() ?? '';
  if (activity.isNotEmpty) parts.add('Activity $activity');
  final relative = _relativeTime(row['timestamp']?.toString());
  if (relative.isNotEmpty) parts.add(relative);
  return parts.join(' · ');
}

String _relativeTime(String? raw) {
  final parsed = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  if (parsed == null) return '';
  final gap = DateTime.now().difference(parsed);
  if (gap.isNegative || gap.inMinutes < 1) return 'Just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes}m ago';
  if (gap.inHours < 24) return '${gap.inHours}h ago';
  if (gap.inDays < 7) return '${gap.inDays}d ago';
  return '${parsed.day}/${parsed.month}/${parsed.year}';
}


/// Data-coverage chips for a learner (activities / reading / questionnaire / review).
class _CoverageChips extends StatelessWidget {
  const _CoverageChips({required this.coverage});
  final Map<String, dynamic> coverage;

  @override
  Widget build(BuildContext context) {
    if (coverage.isEmpty) return const SizedBox.shrink();
    final sessions = _integer(coverage['activity_sessions']);
    final recordings = _integer(coverage['recordings']);
    final usable = _integer(coverage['usable_recordings']);
    final done = _integer(coverage['questionnaire_sections_done']);
    final total = _integer(coverage['questionnaire_sections_total']);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        StatusChip(
          label: '$sessions activity sessions',
          tone: sessions > 0 ? DashTone.good : DashTone.neutral,
          icon: Icons.touch_app_outlined,
        ),
        StatusChip(
          label: recordings == 0 ? 'No reading yet' : '$usable/$recordings clear recordings',
          tone: recordings == 0 ? DashTone.neutral : (usable > 0 ? DashTone.good : DashTone.watch),
          icon: Icons.mic_none_rounded,
        ),
        StatusChip(
          label: 'Questionnaire $done/$total',
          tone: total > 0 && done >= total ? DashTone.good : DashTone.neutral,
          icon: Icons.assignment_outlined,
        ),
        if (coverage['professional_review'] == true)
          const StatusChip(label: 'Reviewed', tone: DashTone.good, icon: Icons.rate_review_outlined),
      ],
    );
  }
}
