import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const ServerSettingsDialog(),
    );
  }

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  final _hostController = TextEditingController();
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('serverHost') ?? '192.168.137.43';
    _hostController.text = host;
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    final ok = await ApiService.instance.checkHealth();

    if (mounted) {
      setState(() {
        _testing = false;
        _testResult = ok
            ? '✅ Connection successful (HTTP 200 OK)'
            : '❌ Connection failed. Check IP & port 8120.';
      });
    }
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('serverHost', host);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Server host set to $host')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A28);

    return AlertDialog(
      title: Text('Server Settings', style: TextStyle(color: primaryText, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter the IP address of the machine running the PersonaLens backend and Supabase:', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            style: TextStyle(color: primaryText),
            decoration: const InputDecoration(
              labelText: 'Server Host IP',
              hintText: 'e.g. 192.168.137.43',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_testResult != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _testResult!,
                style: TextStyle(
                  color: _testResult!.startsWith('✅') ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering_rounded, size: 18),
            label: const Text('Test Connection (GET /health)'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
