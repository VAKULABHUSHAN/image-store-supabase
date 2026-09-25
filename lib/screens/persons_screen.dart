import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../models/person_model.dart';
import '../providers/persons_provider.dart';

class PersonsScreen extends ConsumerWidget {
  const PersonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personsAsync = ref.watch(personsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/dashboard'),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: AppTheme.inkLight),
                ),
                const SizedBox(width: 12),
                Text('PERSONS', style: AppTheme.brandText),
                const Spacer(),
                Text(
                  personsAsync.valueOrNull != null
                      ? '${personsAsync.value!.length} TOTAL'
                      : '',
                  style: AppTheme.monoLabel,
                ),
              ],
            ),
          ),

          // ── List ─────────────────────────────────────────
          Expanded(
            child: personsAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.brandBlue)),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: AppTheme.monoSmall
                        .copyWith(color: AppTheme.brandRed)),
              ),
              data: (persons) {
                if (persons.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('◎',
                            style: TextStyle(
                                fontSize: 32, color: AppTheme.inkGhost)),
                        const SizedBox(height: 10),
                        Text('No persons yet',
                            style: AppTheme.monoSmall),
                        const SizedBox(height: 6),
                        Text('Scan faces using the camera',
                            style: AppTheme.monoLabel),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(personsProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: persons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        _PersonRow(person: persons[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final PersonModel person;
  const _PersonRow({required this.person});

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.avatarColors(person.name);
    return GestureDetector(
      onTap: () => context.go('/persons/${person.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border.all(color: AppTheme.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
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
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.displayName, style: AppTheme.cardName),
                  if (person.relationship != null)
                    Text(person.relationship!,
                        style: AppTheme.monoSmall),
                ],
              ),
            ),
            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: person.isKnown
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                person.isKnown ? 'ID' : 'NEW',
                style: GoogleFonts.dmMono(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  color: person.isKnown
                      ? const Color(0xFF15803D)
                      : AppTheme.brandRed,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right,
                size: 16, color: AppTheme.inkGhost),
          ],
        ),
      ),
    );
  }
}
