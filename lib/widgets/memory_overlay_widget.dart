import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/memory_cue.dart';

class MemoryOverlayWidget extends StatelessWidget {
  final MemoryCue cue;
  const MemoryOverlayWidget({super.key, required this.cue});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.avatarColors(cue.name);

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Name row ──────────────────────────────────────
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colors[0],
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  cue.name?.isNotEmpty == true
                      ? cue.name![0].toUpperCase()
                      : '?',
                  style: GoogleFonts.syne(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colors[1],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cue.name ?? 'Unknown',
                      style: AppTheme.cardName,
                    ),
                    if (cue.relationship != null)
                      Text(cue.relationship!,
                          style: AppTheme.monoSmall),
                  ],
                ),
              ),
              if (cue.matchDistance != null)
                Text(
                  '${((1 - cue.matchDistance!) * 100).round()}%',
                  style: GoogleFonts.dmMono(
                    fontSize: 10,
                    color: AppTheme.inkFaint,
                  ),
                ),
            ],
          ),

          // ── Summaries ─────────────────────────────────────
          if (cue.firstSummary != null || cue.lastSummary != null) ...[
            const SizedBox(height: 10),
            const Divider(color: Color(0xFFF1EDE7), height: 1),
            const SizedBox(height: 10),
            if (cue.firstSummary != null)
              _MemoryRow(tag: 'FIRST', text: cue.firstSummary!),
            if (cue.lastSummary != null)
              _MemoryRow(tag: 'LAST', text: cue.lastSummary!),
          ],
        ],
      ),
    );
  }
}

class _MemoryRow extends StatelessWidget {
  final String tag;
  final String text;
  const _MemoryRow({required this.tag, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              child: Text(tag, style: AppTheme.monoLabel),
            ),
            const SizedBox(width: 6),
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
