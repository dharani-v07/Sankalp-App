import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Local base URL logic duplicated here to avoid depending on private _AuthService in main.dart
String get _baseUrl {
  const fromDefine = String.fromEnvironment('API_BASE_URL');
  if (fromDefine.isNotEmpty) return fromDefine;
  if (Platform.isAndroid) return 'http://10.0.2.2:3000';
  return 'http://localhost:3000';
}

class AuthorityDashboardTabX extends StatelessWidget {
  final String schoolName;
  const AuthorityDashboardTabX({super.key, required this.schoolName});

  Future<Map<String, dynamic>> _load() async {
    final uri = Uri.parse('$_baseUrl/dashboard/authority?schoolName=${Uri.encodeQueryComponent(schoolName)}');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load dashboard');
    return json.decode(res.body) as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final data = snap.data ?? {};
        final users = (data['users'] as List?) ?? [];
        final drillsCount = data['drills'] ?? 0;
        final quizzes = (data['quizzes'] as List?) ?? [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('School: $schoolName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _metricCard('Drills Scheduled', drillsCount.toString(), Icons.campaign_rounded, Colors.orange),
                  _metricCard('Roles', users.length.toString(), Icons.people_alt_rounded, Colors.blue),
                  _metricCard('Quiz Types', quizzes.length.toString(), Icons.quiz_rounded, Colors.purple),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Users by Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...users.map((u) {
                final role = (u['_id']?['role'] ?? '').toString();
                final count = (u['count'] ?? 0).toString();
                return ListTile(leading: const Icon(Icons.badge), title: Text(role), trailing: Text(count));
              }),
              const SizedBox(height: 16),
              const Text('Quiz Averages', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...quizzes.map((q) {
                final type = (q['_id'] ?? '').toString();
                final avg = (q['avgScore'] is num) ? (q['avgScore'] as num).toStringAsFixed(1) : '0.0';
                final attempts = (q['attempts'] ?? 0).toString();
                return ListTile(
                  leading: const Icon(Icons.assessment),
                  title: Text(type),
                  subtitle: Text('Avg: $avg'),
                  trailing: Text('Attempts: $attempts'),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 18)),
            ])
          ],
        ),
      ),
    );
  }
}

class AuthoritySchoolsTabX extends StatelessWidget {
  final String schoolName;
  const AuthoritySchoolsTabX({super.key, required this.schoolName});

  Future<List<dynamic>> _load() async {
    final uri = Uri.parse('$_baseUrl/activities?schoolName=${Uri.encodeQueryComponent(schoolName)}');
    final res = await http.get(uri);
    if (res.statusCode != 200) throw Exception('Failed to load activities');
    return json.decode(res.body) as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _load(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final items = snap.data ?? [];
        if (items.isEmpty) return const Center(child: Text('No recent activities'));

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final it = items[i] as Map<String, dynamic>;
            final action = (it['action'] ?? '').toString();
            final role = (it['role'] ?? '').toString();
            final when = (it['createdAt'] ?? '').toString();
            return ListTile(
              leading: const Icon(Icons.event_note),
              title: Text(action),
              subtitle: Text('$role  •  $when'),
            );
          },
        );
      },
    );
  }
}

class AuthorityProblemsTabX extends StatefulWidget {
  final String? userId;
  const AuthorityProblemsTabX({super.key, required this.userId});
  @override
  State<AuthorityProblemsTabX> createState() => _AuthorityProblemsTabXState();
}

class _AuthorityProblemsTabXState extends State<AuthorityProblemsTabX> {
  final _title = TextEditingController();
  final _type = TextEditingController();
  final _before = TextEditingController();
  final _while = TextEditingController();
  final _after = TextEditingController();
  bool _loading = false;
  List<dynamic> _materials = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final res = await http.get(Uri.parse('$_baseUrl/materials'));
    if (res.statusCode == 200) {
      setState(() => _materials = json.decode(res.body) as List<dynamic>);
    }
  }

  Future<void> _create() async {
    if (widget.userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID missing'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _loading = true);
    final body = {
      'disasterType': _type.text.trim(),
      'title': _title.text.trim(),
      'sections': [
        {'heading': 'Before', 'body': _before.text.trim()},
        {'heading': 'While', 'body': _while.text.trim()},
        {'heading': 'After', 'body': _after.text.trim()},
      ],
      'publishedBy': widget.userId,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/materials'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );
    setState(() => _loading = false);
    if (!mounted) return;
    if (res.statusCode == 201) {
      _title.clear(); _type.clear(); _before.clear(); _while.clear(); _after.clear();
      await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Problem statement added'), backgroundColor: Colors.green));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _title.dispose(); _type.dispose(); _before.dispose(); _while.dispose(); _after.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Post Problem Statement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          _field(_type, 'Disaster Type (e.g., earthquake)'),
          const SizedBox(height: 8),
          _field(_title, 'Title'),
          const SizedBox(height: 8),
          _field(_before, 'Precautions Before'),
          const SizedBox(height: 8),
          _field(_while, 'Precautions While'),
          const SizedBox(height: 8),
          _field(_after, 'Precautions After'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _create,
            child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create'),
          ),
          const SizedBox(height: 16),
          const Text('Existing Materials', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._materials.map((m) {
            final mm = m as Map<String, dynamic>;
            final title = (mm['title'] ?? '').toString();
            final dt = (mm['disasterType'] ?? '').toString();
            return Card(child: ListTile(title: Text(title), subtitle: Text(dt)));
          })
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        labelText: label,
        border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
