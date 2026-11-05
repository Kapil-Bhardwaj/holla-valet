import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api_client.dart';
import '../widgets/empty_state.dart';
import 'login_screen.dart';
import 'qr_inventory_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _checkedIn = [];
  List<dynamic> _requested = [];
  List<dynamic> _recentlyCompleted = [];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  Set<String> _knownRequestedIds = {};
  bool _alertActive = false;
  bool _firstLoadDone = false;

  @override
  void initState() {
    super.initState();
    _poll();
    // Live board: polling every 4s is simple and plenty responsive for this
    // scale. Swap for a websocket later if you want sub-second updates.
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final data = await ApiClient.instance.getTickets();
      final active = (data['active'] as List?) ?? [];
      final checkedIn = active.where((t) => t['status'] == 'CHECKED_IN').toList();
      final requested = active.where((t) => t['status'] == 'REQUESTED').toList();

      final newRequestedIds = requested.map((t) => t['id'] as String).toSet();
      // Only treat this as a fresh alert after the first successful load -
      // otherwise a "Requested" ticket that was already there when you
      // opened the dashboard would wrongly play the alert sound once.
      final hasNewRequest = _firstLoadDone && newRequestedIds.difference(_knownRequestedIds).isNotEmpty;
      if (hasNewRequest) {
        // Best-effort audible alert - some browsers restrict autoplay sound,
        // so the visual banner below is the alert you can actually rely on.
        SystemSound.play(SystemSoundType.alert);
      }

      setState(() {
        _checkedIn = checkedIn;
        _requested = requested;
        _recentlyCompleted = (data['recentlyCompleted'] as List?) ?? [];
        _knownRequestedIds = newRequestedIds;
        _alertActive = requested.isNotEmpty;
        _loading = false;
        _error = null;
        _firstLoadDone = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markArrived(String ticketId) async {
    try {
      await ApiClient.instance.markArrived(ticketId);
      _poll();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _logout() async {
    await ApiClient.instance.logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🚗  Valet Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'QR tag inventory',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QrInventoryScreen())),
          ),
          IconButton(icon: const Icon(Icons.logout), tooltip: 'Log out', onPressed: _logout),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('⚠️  $_error', style: const TextStyle(color: Colors.red)))
              : Column(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _alertActive
                          ? Container(
                              key: const ValueKey('alert'),
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              color: const Color(0xFFD32F2F),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text('🔔  ', style: TextStyle(fontSize: 20)),
                                  Text(
                                    '${_requested.length} car${_requested.length == 1 ? '' : 's'} requested - tell the runner now!',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('no-alert')),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildColumn(
                                emoji: '🅿️',
                                title: 'Checked In',
                                tickets: _checkedIn,
                                color: Colors.blue,
                                emptyMessage: 'No cars checked in right now.\nScan a tag to start a visit.',
                              ),
                            ),
                            Expanded(
                              child: _buildColumn(
                                emoji: '🔔',
                                title: 'Requested',
                                tickets: _requested,
                                color: Colors.red,
                                showArrivedButton: true,
                                emptyMessage: 'No requests waiting.\nYou\'ll be alerted the moment one comes in.',
                              ),
                            ),
                            Expanded(child: _buildHistoryColumn()),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildColumn({
    required String emoji,
    required String title,
    required List<dynamic> tickets,
    required Color color,
    required String emptyMessage,
    bool showArrivedButton = false,
  }) {
    return Card(
      margin: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: color,
                  child: Text('${tickets.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: tickets.isEmpty
                ? EmptyState(emoji: showArrivedButton ? '😌' : '🚗', title: emptyMessage)
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = tickets[index] as Map<String, dynamic>;
                      final tagNumber = ticket['qrCode']?['hotelLocalNumber'];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: color.withValues(alpha: 0.2),
                                child: Text('🚗'),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Tag #$tagNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(
                                      '🕒 ${_formatTime(ticket['checkedInAt'])}',
                                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                              if (showArrivedButton)
                                FilledButton.icon(
                                  onPressed: () => _markArrived(ticket['id']),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text('Arrived'),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryColumn() {
    return Card(
      margin: const EdgeInsets.all(6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Colors.grey.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✅', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text('Recently Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Expanded(
            child: _recentlyCompleted.isEmpty
                ? const EmptyState(emoji: '🕓', title: 'Nothing completed yet today.')
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _recentlyCompleted.length,
                    itemBuilder: (context, index) {
                      final ticket = _recentlyCompleted[index] as Map<String, dynamic>;
                      final tagNumber = ticket['qrCode']?['hotelLocalNumber'];
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(backgroundColor: Color(0xFFC8E6C9), child: Text('✅')),
                          title: Text('Tag #$tagNumber', style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text('🕒 ${_formatTime(ticket['completedAt'])}'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
