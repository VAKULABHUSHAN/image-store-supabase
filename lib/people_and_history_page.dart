import 'package:flutter/material.dart';
import 'api_service.dart';
import 'name_prompt_dialog.dart';

class PeopleAndHistoryPage extends StatefulWidget {
  final int initialTabIndex;

  const PeopleAndHistoryPage({super.key, this.initialTabIndex = 0});

  @override
  State<PeopleAndHistoryPage> createState() => _PeopleAndHistoryPageState();
}

class _PeopleAndHistoryPageState extends State<PeopleAndHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _people = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _loadingPeople = true;
  bool _loadingSessions = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _loadPeople();
    _loadSessions();
  }

  Future<void> _loadPeople() async {
    setState(() => _loadingPeople = true);
    final list = await ApiService.instance.getPeople();
    if (mounted) {
      setState(() {
        _people = list;
        _loadingPeople = false;
      });
    }
  }

  Future<void> _loadSessions() async {
    setState(() => _loadingSessions = true);
    final list = await ApiService.instance.getSessions();
    if (mounted) {
      setState(() {
        _sessions = list;
        _loadingSessions = false;
      });
    }
  }

  void _showPersonDetail(Map<String, dynamic> person) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final name = person['name'] ?? 'Unknown';
        final relation = person['relation'] ?? 'Not specified';
        final firstSum = person['firstSummary'] ?? 'No summary yet.';
        final lastSum = person['lastSummary'] ?? 'No summary yet.';
        final sessionCount = person['sessions'] ?? 0;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFF6C63FF),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('$relation • $sessionCount sessions', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 30),

              const Text('First met:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6C63FF))),
              const SizedBox(height: 4),
              Text(firstSum, style: const TextStyle(fontSize: 14, height: 1.4)),

              const SizedBox(height: 16),
              const Text('Most recent encounter:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF6C63FF))),
              const SizedBox(height: 4),
              Text(lastSum, style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF1A1A28);
    final secondaryText = isDark ? Colors.white60 : const Color(0xFF666680);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('People & Memory History', style: TextStyle(color: primaryText, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: primaryText),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: secondaryText,
          indicatorColor: const Color(0xFF6C63FF),
          tabs: const [
            Tab(text: 'People'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 👥 PEOPLE TAB
          _loadingPeople
              ? const Center(child: CircularProgressIndicator())
              : (_people.isEmpty
                  ? Center(child: Text('No people added yet.', style: TextStyle(color: secondaryText)))
                  : RefreshIndicator(
                      onRefresh: _loadPeople,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _people.length,
                        itemBuilder: (context, index) {
                          final p = _people[index];
                          final name = p['name'] ?? 'Unnamed';
                          final relation = p['relation'] ?? 'Not specified';
                          final sessions = p['sessions'] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF6C63FF),
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('$relation · $sessions sessions'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => _showPersonDetail(p),
                            ),
                          );
                        },
                      ),
                    )),

          // 📜 HISTORY TAB
          _loadingSessions
              ? const Center(child: CircularProgressIndicator())
              : (_sessions.isEmpty
                  ? Center(child: Text('No conversation history yet.', style: TextStyle(color: secondaryText)))
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final s = _sessions[index];
                          final name = s['personName'] ?? 'Unnamed';
                          final summary = s['summary'] ?? 'No summary generated.';
                          final isUnnamedEnded = s['personId'] == null && s['status'] == 'ended';
                          final hostPct = (s['hostPct'] as num?)?.toDouble();

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isUnnamedEnded ? Colors.amber : primaryText,
                                        ),
                                      ),
                                      Text(
                                        s['date'] ?? '',
                                        style: TextStyle(color: secondaryText, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    summary,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
                                  ),
                                  if (hostPct != null) ...[
                                    const SizedBox(height: 10),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: hostPct / 100.0,
                                        backgroundColor: Colors.amber.withOpacity(0.4),
                                        color: const Color(0xFF6C63FF),
                                        minHeight: 5,
                                      ),
                                    ),
                                  ],
                                  if (isUnnamedEnded) ...[
                                    const SizedBox(height: 10),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () {
                                          NamePromptDialog.show(
                                            context,
                                            sessionId: s['id'].toString(),
                                            onSaved: _loadData,
                                          );
                                        },
                                        icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.amber),
                                        label: const Text('Name this person', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    )),
        ],
      ),
    );
  }
}
