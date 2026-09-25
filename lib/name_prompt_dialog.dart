import 'package:flutter/material.dart';
import 'api_service.dart';

class NamePromptDialog extends StatefulWidget {
  final String sessionId;
  final VoidCallback? onSaved;

  const NamePromptDialog({
    super.key,
    required this.sessionId,
    this.onSaved,
  });

  static Future<void> show(BuildContext context, {required String sessionId, VoidCallback? onSaved}) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => NamePromptDialog(sessionId: sessionId, onSaved: onSaved),
    );
  }

  @override
  State<NamePromptDialog> createState() => _NamePromptDialogState();
}

class _NamePromptDialogState extends State<NamePromptDialog> {
  final _nameController = TextEditingController();
  String _selectedRelationship = 'Friend';
  bool _isNewPerson = true;
  bool _isLoading = false;
  List<Map<String, dynamic>> _existingPeople = [];
  String? _selectedPersonId;

  final List<String> _relationships = [
    'Daughter',
    'Son',
    'Spouse',
    'Grandchild',
    'Sibling',
    'Friend',
    'Neighbor',
    'Caregiver',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final people = await ApiService.instance.getPeople();
    if (mounted) {
      setState(() {
        _existingPeople = people;
        if (_existingPeople.isNotEmpty) {
          _selectedPersonId = _existingPeople.first['id']?.toString();
        }
      });
    }
  }

  Future<void> _save() async {
    if (_isNewPerson) {
      final name = _nameController.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a name first.')),
        );
        return;
      }

      setState(() => _isLoading = true);
      final res = await ApiService.instance.finalizePerson(
        sessionId: widget.sessionId,
        name: name,
        relationship: _selectedRelationship,
        useSessionFace: true,
      );
      setState(() => _isLoading = false);

      if (res != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $name')),
        );
        if (widget.onSaved != null) widget.onSaved!();
        Navigator.pop(context);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save person.')),
        );
      }
    } else {
      if (_selectedPersonId == null) return;
      setState(() => _isLoading = true);
      final res = await ApiService.instance.finalizePerson(
        sessionId: widget.sessionId,
        personId: _selectedPersonId,
      );
      setState(() => _isLoading = false);

      if (res != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session linked successfully')),
        );
        if (widget.onSaved != null) widget.onSaved!();
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A28);
    final secondaryText = isDark ? Colors.white70 : const Color(0xFF666680);

    return AlertDialog(
      title: Text('Who was that?', style: TextStyle(color: primaryText, fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attach this voice encounter to a person so they are recognized next time.',
                style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),

            if (_existingPeople.isNotEmpty) ...[
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('New Person'),
                    selected: _isNewPerson,
                    onSelected: (val) => setState(() => _isNewPerson = true),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Someone I know'),
                    selected: !_isNewPerson,
                    onSelected: (val) => setState(() => _isNewPerson = false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (_isNewPerson) ...[
              TextField(
                controller: _nameController,
                style: TextStyle(color: primaryText),
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Alex, Sarah',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRelationship,
                decoration: const InputDecoration(
                  labelText: 'Relationship',
                  border: OutlineInputBorder(),
                ),
                items: _relationships
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRelationship = val);
                },
              ),
            ] else ...[
              DropdownButtonFormField<String>(
                value: _selectedPersonId,
                decoration: const InputDecoration(
                  labelText: 'Choose who this was',
                  border: OutlineInputBorder(),
                ),
                items: _existingPeople
                    .map((p) => DropdownMenuItem(
                          value: p['id'].toString(),
                          child: Text(p['name'] ?? 'Unnamed'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPersonId = val);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Save'),
        ),
      ],
    );
  }
}
