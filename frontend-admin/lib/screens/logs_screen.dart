import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/empty_state.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final logs = await ApiClient.instance.listInvalidLogs();
      setState(() => _logs = logs);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('⚠️  Invalid scan / message log')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const EmptyState(
                  emoji: '✨',
                  title: 'Nothing to see here',
                  subtitle: 'Scans or WhatsApp messages with an unknown or\n'
                      'already-in-use QR code will show up here for review.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index] as Map<String, dynamic>;
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFE0B2),
                            child: Text('⚠️'),
                          ),
                          title: Text(log['reason'] ?? 'unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('code: ${log['rawCode'] ?? '-'}   ·   source: ${log['source']}'),
                          trailing: Text(
                            log['createdAt']?.toString().substring(0, 19) ?? '',
                            style: const TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
