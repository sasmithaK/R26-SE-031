import 'package:flutter/material.dart';
import '../services/therapist_dashboard_service.dart';
import '../theme/app_theme.dart';

/// Read-only assistant for asking questions about this student's recorded evidence.
class C3EvidenceChatPanel extends StatefulWidget {
  final String studentId;

  const C3EvidenceChatPanel({super.key, required this.studentId});

  @override
  State<C3EvidenceChatPanel> createState() => _C3EvidenceChatPanelState();
}

class _C3EvidenceChatPanelState extends State<C3EvidenceChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _service = TherapistDashboardService();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final question = _controller.text.trim();
    if (question.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _error = null;
      _sending = true;
      _messages.add({'role': 'user', 'content': question});
    });
    _scrollToBottom();

    final start = (_messages.length - 8).clamp(0, _messages.length).toInt();
    final recentMessages = _messages
        .skip(start)
        .map((message) => Map<String, String>.from(message))
        .toList();
    try {
      final result = await _service.askC3EvidenceChat(
        widget.studentId,
        recentMessages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': result['answer']?.toString() ??
              'I could not prepare an answer from the available records.',
        });
        _sending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not get an answer. Check the connection and try again.';
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_outlined, color: AppColors.calmBlue),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Ask about recorded learning observations',
                  style: AppTypography.heading(fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            'Answers use only this child’s recent activity, reading samples and parent questionnaire records. A summary of those records and your question is sent to the configured AI service. Chat is not saved in the child’s profile. This is not a diagnostic tool.',
            style: AppTypography.caption(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (_messages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.calmBlue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Try: “What patterns appear in recent reading practice?”',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            SizedBox(
              height: 250,
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_sending && index == _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  final message = _messages[index];
                  final isUser = message['role'] == 'user';
                  return Align(
                    alignment:
                        isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 310),
                      margin: const EdgeInsets.only(bottom: 9),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isUser
                            ? AppColors.calmBlue.withValues(alpha: 0.12)
                            : AppColors.gentleGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: SelectableText(
                        message['content'] ?? '',
                        style: AppTypography.body(fontSize: 13),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 1000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Ask a question about the records…',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(color: AppColors.borderLight),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(13),
                      borderSide: BorderSide(color: AppColors.borderLight),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                tooltip: 'Send question',
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.calmBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
