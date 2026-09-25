import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/person_model.dart';
import '../models/memory_cue.dart';

class PersonCardWidget extends StatelessWidget {
  final PersonModel person;
  final bool isUnknown;
  final double? confidence;
  final MemoryCue? memoryCue;

  const PersonCardWidget({
    super.key,
    required this.person,
    required this.isUnknown,
    this.confidence,
    this.memoryCue,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.avatarColors(person.name);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isUnknown ? const Color(0xFFFFF8F8) : AppTheme.surfaceAlt,
        border: Border.all(
          color: isUnknown
              ? AppTheme.brandRed.withOpacity(0.18)
              : AppTheme.border,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card top row ────────────────────────────────
          Row(
            children: [
              // Avatar
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: colors[0],
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  person.initials,
                  style: GoogleFonts.syne(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors[1],
                  ),
                ),
              ),
              const SizedBox(width: 9),

              // Name + confidence
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUnknown ? 'Unidentified' : person.displayName,
                      style: AppTheme.cardName,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (confidence != null)
                      Text(
                        '${(confidence! * 100).round()}% match',
                        style: GoogleFonts.dmMono(
                            fontSize: 10, color: AppTheme.inkFaint),
                      ),
                  ],
                ),
              ),

              // Badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isUnknown
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  isUnknown ? 'NEW' : 'ID',
                  style: GoogleFonts.dmMono(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                    color: isUnknown
                        ? AppTheme.brandRed
                        : const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),

          // ── Memory summaries ────────────────────────────
          if (memoryCue != null &&
              (memoryCue!.firstSummary != null ||
                  memoryCue!.lastSummary != null)) ...[
            const SizedBox(height: 8),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                    top: BorderSide(color: Color(0xFFF1EDE7))),
              ),
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                children: [
                  if (memoryCue!.firstSummary != null)
                    _SummaryRow(
                        tag: 'FIRST',
                        text: memoryCue!.firstSummary!),
                  if (memoryCue!.lastSummary != null)
                    _SummaryRow(
                        tag: 'LAST',
                        text: memoryCue!.lastSummary!),
                ],
              ),
            ),
          ],

          // ── Relationship ────────────────────────────────
          if (person.relationship != null) ...[
            const SizedBox(height: 4),
            Text(
              '• ${person.relationship}',
              style: GoogleFonts.dmMono(
                  fontSize: 10, color: AppTheme.inkLight),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String tag;
  final String text;
  const _SummaryRow({required this.tag, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                tag,
                style: GoogleFonts.dmMono(
                    fontSize: 8,
                    color: AppTheme.inkGhost,
                    letterSpacing: 1.0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.dmMono(
                    fontSize: 10,
                    color: AppTheme.inkLight,
                    height: 1.5),
              ),
            ),
          ],
        ),
      );
}
