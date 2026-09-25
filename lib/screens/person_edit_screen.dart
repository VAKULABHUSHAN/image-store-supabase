import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme.dart';
import '../providers/persons_provider.dart';

class PersonEditScreen extends ConsumerStatefulWidget {
  final String personId;
  const PersonEditScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonEditScreen> createState() => _PersonEditScreenState();
}

class _PersonEditScreenState extends ConsumerState<PersonEditScreen> {
  final _nameCtrl         = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final person = ref.read(personsProvider).valueOrNull
        ?.where((p) => p.id == widget.personId)
        .firstOrNull;
    if (person != null) {
      _nameCtrl.text         = person.name ?? '';
      _relationshipCtrl.text = person.relationship ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(personsProvider.notifier).confirmPerson(
            widget.personId,
            _nameCtrl.text.trim(),
            _relationshipCtrl.text.trim().isEmpty
                ? null
                : _relationshipCtrl.text.trim(),
          );
      if (mounted) context.go('/persons/${widget.personId}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 14),
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              border:
                  Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      context.go('/persons/${widget.personId}'),
                  child: const Icon(Icons.arrow_back,
                      size: 18, color: AppTheme.inkLight),
                ),
                const SizedBox(width: 12),
                Text('EDIT PERSON', style: AppTheme.brandText),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  border: Border.all(color: AppTheme.border),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Identify this person',
                      style: GoogleFonts.syne(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Fill in what you know',
                      style: AppTheme.monoSmall,
                    ),
                    const SizedBox(height: 24),

                    _FieldLabel('NAME'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameCtrl,
                      style: GoogleFonts.dmMono(
                          fontSize: 12, color: AppTheme.ink),
                      decoration:
                          const InputDecoration(hintText: 'Full name…'),
                    ),
                    const SizedBox(height: 16),

                    _FieldLabel('RELATIONSHIP'),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _relationshipCtrl,
                      style: GoogleFonts.dmMono(
                          fontSize: 12, color: AppTheme.ink),
                      decoration: const InputDecoration(
                          hintText: 'Friend, colleague, family…'),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: AppTheme.avRedBg,
                          border: Border.all(
                              color: AppTheme.brandRed.withOpacity(0.18)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!,
                            style: GoogleFonts.dmMono(
                                fontSize: 11,
                                color: AppTheme.brandRed)),
                      ),
                    ],

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _save,
                        child: _loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('SAVE'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTheme.monoLabel);
}
