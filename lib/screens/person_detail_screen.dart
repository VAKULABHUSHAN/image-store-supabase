import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../providers/persons_provider.dart';
import '../providers/interactions_provider.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;
  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() =>
      _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref
        .read(interactionsProvider.notifier)
        .fetchForPerson(widget.personId));
  }

  @override
  Widget build(BuildContext context) {
    final personsAsync     = ref.watch(personsProvider);
    final interactionsAsync = ref.watch(interactionsProvider);

    final person = personsAsync.valueOrNull
        ?.where((p) => p.id == widget.personId)
        .firstOrNull;
    final interaction =
        interactionsAsync.valueOrNull?[widget.personId];

    if (person == null && personsAsync.isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
            child: CircularProgressIndicator(color: AppTheme.brandBlue)),
      );
    }

    if (person == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Person not found', style: AppTheme.monoSmall),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.go('/persons'),
                child: const Text('BACK'),
              ),
            ],
          ),
        ),
      );
    }

    final colors = AppTheme.avatarColors(person.name);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/persons'),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: AppTheme.inkLight),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      context.go('/persons/${widget.personId}/edit'),
                  child: Text('EDIT',
                      style: AppTheme.monoLabel.copyWith(
                          color: AppTheme.brandBlue, fontSize: 10)),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Person card ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: Border.all(color: AppTheme.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colors[0],
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            person.initials,
                            style: GoogleFonts.syne(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: colors[1],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(person.displayName,
                                  style: GoogleFonts.syne(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.ink,
                                  )),
                              if (person.relationship != null)
                                Text(person.relationship!,
                                    style: AppTheme.monoSmall),
                              const SizedBox(height: 6),
                              _Badge(person.isKnown),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Interaction log ──────────────────────
                  _SectionLabel('INTERACTION LOG'),
                  const SizedBox(height: 8),
                  if (interaction == null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        border: Border.all(color: AppTheme.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text('No interactions yet',
                            style: AppTheme.monoSmall),
                      ),
                    )
                  else ...[
                    if (interaction.firstSummary != null)
                      _LogBlock(
                          tag: 'FIRST',
                          text: interaction.firstSummary!,
                          date: interaction.firstOccurredAt),
                    if (interaction.lastSummary != null) ...[
                      const SizedBox(height: 8),
                      _LogBlock(
                          tag: 'LAST',
                          text: interaction.lastSummary!,
                          date: interaction.lastOccurredAt),
                    ],
                    if (interaction.lastTranscript != null) ...[
                      const SizedBox(height: 16),
                      _SectionLabel('LAST TRANSCRIPT'),
                      const SizedBox(height: 8),
                      _LogBlock(
                          tag: 'TRANSCRIPT',
                          text: interaction.lastTranscript!,
                          date: null),
                    ],
                  ],

                  const SizedBox(height: 24),

                  // ── Danger zone ──────────────────────────
                  _SectionLabel('DANGER ZONE'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _confirmDelete(context, ref),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppTheme.brandRed.withOpacity(0.3)),
                        foregroundColor: AppTheme.brandRed,
                        textStyle: GoogleFonts.dmMono(
                            fontSize: 11, letterSpacing: 1),
                      ),
                      child: const Text('DELETE PERSON'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('Delete Person',
            style: GoogleFonts.syne(
                fontWeight: FontWeight.w700, color: AppTheme.ink)),
        content: Text('This action cannot be undone.',
            style: AppTheme.monoSmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL',
                style: AppTheme.monoLabel
                    .copyWith(color: AppTheme.inkLight, fontSize: 10)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE',
                style: AppTheme.monoLabel.copyWith(
                    color: AppTheme.brandRed, fontSize: 10)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(personsProvider.notifier)
          .deletePerson(widget.personId);
      if (mounted) context.go('/persons');
    }
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTheme.sectionLabel);
}

class _Badge extends StatelessWidget {
  final bool isKnown;
  const _Badge(this.isKnown);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isKnown
              ? const Color(0xFFDCFCE7)
              : const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          isKnown ? 'IDENTIFIED' : 'UNIDENTIFIED',
          style: GoogleFonts.dmMono(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: isKnown
                ? const Color(0xFF15803D)
                : AppTheme.brandRed,
          ),
        ),
      );
}

class _LogBlock extends StatelessWidget {
  final String tag;
  final String text;
  final DateTime? date;
  const _LogBlock({required this.tag, required this.text, this.date});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.borderLight),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tag, style: AppTheme.monoLabel),
                const Spacer(),
                if (date != null)
                  Text(
                    '${date!.day}/${date!.month}/${date!.year}',
                    style: AppTheme.monoLabel,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(text,
                style: GoogleFonts.dmMono(
                    fontSize: 11,
                    color: AppTheme.inkLight,
                    height: 1.6)),
          ],
        ),
      );
}
