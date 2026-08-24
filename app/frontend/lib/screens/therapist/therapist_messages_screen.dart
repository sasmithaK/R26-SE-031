import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'therapist_chat_screen.dart';
import '../../services/localization_service.dart';

class TherapistMessagesScreen extends StatefulWidget {
  const TherapistMessagesScreen({super.key});

  @override
  State<TherapistMessagesScreen> createState() => _TherapistMessagesScreenState();
}

class _TherapistMessagesScreenState extends State<TherapistMessagesScreen> {
  final _searchController = TextEditingController();

  // Mock conversations
  final List<Map<String, dynamic>> _conversations = [
    {
      'parentName': 'Kumari Perera',
      'studentName': 'Kavitha',
      'avatar': '👩',
      'lastMessage': 'Thank you so much doctor!',
      'time': '9:40 AM',
      'unread': 2,
      'online': true,
    },
    {
      'parentName': 'Saman Fernando',
      'studentName': 'Ashan',
      'avatar': '👨',
      'lastMessage': 'When is the next session?',
      'time': 'Yesterday',
      'unread': 1,
      'online': false,
    },
    {
      'parentName': 'Dilani Silva',
      'studentName': 'Nethmi',
      'avatar': '👩',
      'lastMessage': 'She completed all the exercises!',
      'time': 'Yesterday',
      'unread': 0,
      'online': true,
    },
    {
      'parentName': 'Rajith Bandara',
      'studentName': 'Dinuka',
      'avatar': '👨',
      'lastMessage': 'I noticed he is struggling with the new level.',
      'time': 'Mon',
      'unread': 0,
      'online': false,
    },
    {
      'parentName': 'Malini Jayawardena',
      'studentName': 'Sanduni',
      'avatar': '👩',
      'lastMessage': 'Great session today!',
      'time': 'Mon',
      'unread': 0,
      'online': false,
    },
    {
      'parentName': 'Nimal Rathnayake',
      'studentName': 'Tharindu',
      'avatar': '👨',
      'lastMessage': 'Can we reschedule to Friday?',
      'time': 'Sun',
      'unread': 0,
      'online': false,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LocalizationService.instance.t('messages'),
                    style: AppTypography.heading(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.calmBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_conversations.where((c) => (c['unread'] as int) > 0).length} ${LocalizationService.instance.t('New')}',
                      style: AppTypography.caption(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.calmBlueDark.withValues(alpha: 0.05),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  style: AppTypography.body(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: LocalizationService.instance.t('Search_Conversations'),
                    hintStyle: AppTypography.body(fontSize: 14, color: AppColors.textHint),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Conversation List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conv = _conversations[index];
                  final hasUnread = (conv['unread'] as int) > 0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TherapistChatScreen(
                            parentName: conv['parentName'],
                            studentName: conv['studentName'],
                            parentAvatar: conv['avatar'],
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: hasUnread
                            ? AppColors.slateBg.withValues(alpha: 0.7)
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hasUnread ? AppColors.borderBlue : AppColors.borderLight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.calmBlueDark.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar with online indicator
                          Stack(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.slateBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(conv['avatar'], style: const TextStyle(fontSize: 22)),
                                ),
                              ),
                              if (conv['online'] == true)
                                Positioned(
                                  bottom: 2,
                                  right: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.gentleGreen,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.cardSurface, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 14),

                          // Name and message
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        conv['parentName'],
                                        style: AppTypography.body(
                                          fontSize: 15,
                                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      conv['time'],
                                      style: AppTypography.caption(
                                        fontSize: 12,
                                        color: hasUnread ? AppColors.calmBlue : AppColors.textHint,
                                        fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'about ${conv['studentName']}',
                                  style: AppTypography.caption(
                                    fontSize: 11,
                                    color: AppColors.calmBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        conv['lastMessage'],
                                        style: AppTypography.caption(
                                          fontSize: 13,
                                          color: hasUnread ? AppColors.textPrimary : AppColors.textSecondary,
                                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasUnread)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.calmBlue,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${conv['unread']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
