import 'package:flutter/material.dart';
import '../../services/localization_service.dart';
import '../../services/auth_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../connect_specialist_screen.dart';

import 'package:intl/intl.dart';

/// Therapist Management Screen — View, manage, and disconnect therapists.
class TherapistManagementScreen extends StatefulWidget {
  const TherapistManagementScreen({super.key});

  @override
  State<TherapistManagementScreen> createState() =>
      _TherapistManagementScreenState();
}



class _TherapistManagementScreenState extends State<TherapistManagementScreen> {
  List<dynamic> _therapists = [];
  bool _isLoading = true;
  final Set<String> _disconnectingIds = {};

  @override
  void initState() {
    super.initState();
    _loadConnections();
  }

  Future<void> _loadConnections() async {
    final connections = await AuthService().getConnections();
    if (mounted) {
      setState(() {
        _therapists = connections.map((c) {
          String formattedDate = 'Unknown';
          if (c['connected_at'] != null) {
            try {
              final dt = DateTime.parse(c['connected_at'].toString());
              formattedDate = DateFormat('MMMM d, yyyy').format(dt);
            } catch (_) {}
          }
          return {
            'id': c['id'],
            'name': c['therapist_name'] ?? 'Unknown',
            'clinic': c['clinic_name'] ?? 'Clinic',
            'specialization': 'Specialist',
            'child': c['student_name'] ?? 'Unknown',
            'connectedDate': formattedDate,
            'status': c['status'],
          };
        }).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ConnectSpecialistScreen(),
            ),
          );
          // Reload the list of therapists when we come back!
          _loadConnections();
        },
        backgroundColor: AppColors.calmBlue,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          LocalizationService.instance.t('add_therapist'),
          style: AppTypography.button(fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
              else if (_therapists.isEmpty)
                _buildEmptyState()
              else
                ..._therapists.map((t) {
                  final bool isDisconnecting = _disconnectingIds.contains(t['id']);
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: isDisconnecting ? 0.0 : 1.0,
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 400),
                      scale: isDisconnecting ? 0.8 : 1.0,
                      child: _buildTherapistCard(t),
                    ),
                  );
                }),
              const SizedBox(height: 80), // FAB clearance
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gentleGreen.withValues(alpha: 0.08),
            AppColors.cream,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary, size: 22),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocalizationService.instance.t('therapist_connections'),
                  style: AppTypography.heading(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'manage specialist access to your child\'s data',
                  style: AppTypography.caption(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 32),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.gentleGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(FontAwesomeIcons.userDoctor,
                    size: 36, color: AppColors.gentleGreen),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationService.instance.t('no_therapists_connected'),
              style: AppTypography.heading(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'connect your child\'s reading specialist or speech-language pathologist to share learning data securely.',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTherapistCard(Map<String, dynamic> therapist) {
    final isActive = therapist['status'] == 'active';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.borderLight, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar + Name + Status
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.gentleGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: FaIcon(FontAwesomeIcons.userDoctor,
                        size: 24, color: AppColors.gentleGreen),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        therapist['name'] as String,
                        style: AppTypography.heading(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        therapist['specialization'] as String,
                        style: AppTypography.caption(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.gentleGreen.withValues(alpha: 0.12)
                        : AppColors.warmAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isActive ? 'active' : 'pending',
                    style: AppTypography.caption(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppColors.gentleGreen
                          : AppColors.warmAmber,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: AppColors.borderLight, height: 1),
            const SizedBox(height: 16),

            // Detail rows
            _buildDetailRow(
                FontAwesomeIcons.hospital, 'clinic', therapist['clinic'] as String),
            const SizedBox(height: 10),
            _buildDetailRow(FontAwesomeIcons.child, 'connected child',
                therapist['child'] as String),
            const SizedBox(height: 10),
            _buildDetailRow(FontAwesomeIcons.calendar, 'connected since',
                therapist['connectedDate'] as String),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDisconnectDialog(therapist),
                    icon: const FaIcon(FontAwesomeIcons.linkSlash,
                        size: 14, color: AppColors.softCoral),
                    label: Text(
                      LocalizationService.instance.t('disconnect'),
                      style: AppTypography.button(
                          fontSize: 13, color: AppColors.softCoral),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.softCoral),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('messaging feature coming soon!')),
                      );
                    },
                    icon: const FaIcon(FontAwesomeIcons.envelope,
                        size: 14, color: AppColors.calmBlue),
                    label: Text(
                      LocalizationService.instance.t('message'),
                      style: AppTypography.button(
                          fontSize: 13, color: AppColors.calmBlue),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.calmBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(dynamic icon, String label, String value) {
    return Row(
      children: [
        FaIcon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: AppTypography.caption(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTypography.body(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  void _showDisconnectDialog(Map<String, dynamic> therapist) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'disconnect therapist?',
          style: AppTypography.heading(
              fontSize: 20, color: AppColors.textPrimary),
        ),
        content: Text(
          'this will revoke ${therapist['name']}\'s access to ${therapist['child']}\'s learning data. you can reconnect later.',
          style: AppTypography.body(
              fontSize: 15, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocalizationService.instance.t('cancel'),
                style: AppTypography.body(
                    fontSize: 14, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              // Optimistically close dialog
              Navigator.pop(context);
              
              final connectionId = therapist['id'] as String?;
              if (connectionId != null) {
                // Trigger the magic disappear effect!
                setState(() {
                  _disconnectingIds.add(connectionId);
                });

                final error = await AuthService().disconnectSpecialist(connectionId);
                
                if (!mounted) return;
                if (error != null) {
                  // Revert the disappearing effect if it fails
                  setState(() {
                    _disconnectingIds.remove(connectionId);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('failed to disconnect: $error'), backgroundColor: AppColors.softCoral),
                  );
                } else {
                  // Wait for the poof animation to finish before removing from list
                  await Future.delayed(const Duration(milliseconds: 500));

                  if (!mounted) return;
                  setState(() {
                    _therapists.removeWhere((t) => t['id'] == connectionId);
                    _disconnectingIds.remove(connectionId);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.instance.t('therapist_disconnected')),
                      backgroundColor: AppColors.softCoral,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.softCoral,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(LocalizationService.instance.t('disconnect'),
                style: AppTypography.button(fontSize: 14)),
          ),
        ],
      ),
    );
  }
}
