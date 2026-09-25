import 'package:flutter/material.dart';
import 'name_prompt_dialog.dart';

class SessionResultSheet extends StatefulWidget {
  final Map<String, dynamic> sessionData;
  final VoidCallback? onDismiss;

  const SessionResultSheet({
    super.key,
    required this.sessionData,
    this.onDismiss,
  });

  static void show(BuildContext context, Map<String, dynamic> sessionData, {VoidCallback? onDismiss}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SessionResultSheet(sessionData: sessionData, onDismiss: onDismiss),
    );
  }

  @override
  State<SessionResultSheet> createState() => _SessionResultSheetState();
}

class _SessionResultSheetState extends State<SessionResultSheet> {
  bool _showTranscript = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A28);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF666680);
    final bg = isDark ? const Color(0xFF14141E) : Colors.white;

    final data = widget.sessionData;
    final sessionId = data['session_id']?.toString() ?? '';
    final personName = data['person_name'] as String?;
    final title = personName ?? 'Unmatched speaker';
    final summary = data['summary'] as String? ?? 'No summary was generated for this session.';
    final needsNaming = data['needs_naming'] == true;
    final segments = (data['segments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rawTranscript = data['transcript'] as String? ?? '';

    // Calculate host speech share
    int hostChars = 0;
    int totalChars = 0;
    for (var seg in segments) {
      final text = seg['text']?.toString() ?? '';
      final spk = seg['speaker']?.toString() ?? '';
      totalChars += text.length;
      if (spk == 'host') hostChars += text.length;
    }

    final double hostFraction = totalChars > 0 ? (hostChars / totalChars).clamp(0.0, 1.0) : 0.5;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green),
                  const SizedBox(width: 10),
                  Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryText)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onDismiss != null) widget.onDismiss!();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Speech share bar
          if (segments.isNotEmpty) ...[
            Text('Speech Share (Host vs Other)', style: TextStyle(fontSize: 11, color: secondaryText, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    flex: (hostFraction * 100).round(),
                    child: Container(height: 6, color: const Color(0xFF3DFBD1)),
                  ),
                  Expanded(
                    flex: ((1 - hostFraction) * 100).round(),
                    child: Container(height: 6, color: const Color(0xFFFFB238)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Summary
          Text('SUMMARY', style: TextStyle(fontSize: 11, color: secondaryText, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          const SizedBox(height: 6),
          Text(summary, style: TextStyle(fontSize: 15, height: 1.4, color: primaryText)),
          const SizedBox(height: 16),

          // Transcript Toggle
          TextButton.icon(
            onPressed: () => setState(() => _showTranscript = !_showTranscript),
            icon: Icon(_showTranscript ? Icons.expand_less : Icons.expand_more),
            label: Text(_showTranscript ? 'Hide Transcript' : 'Show Transcript'),
          ),

          if (_showTranscript) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: segments.isNotEmpty
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: segments.map((seg) {
                          final spk = seg['speaker']?.toString() ?? 'other';
                          final text = seg['text']?.toString() ?? '';
                          final isHost = spk == 'host';

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4, right: 8),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isHost ? const Color(0xFF3DFBD1) : const Color(0xFFFFB238),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '$spk: $text',
                                    style: TextStyle(fontSize: 13, color: primaryText),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      )
                    : Text(rawTranscript, style: TextStyle(fontSize: 13, color: primaryText)),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              if (needsNaming) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB238),
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      NamePromptDialog.show(context, sessionId: sessionId);
                    },
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Name Person', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onDismiss != null) widget.onDismiss!();
                  },
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
