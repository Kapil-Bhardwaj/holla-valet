import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class QrInventoryScreen extends StatefulWidget {
  const QrInventoryScreen({super.key});

  @override
  State<QrInventoryScreen> createState() => _QrInventoryScreenState();
}

class _QrInventoryScreenState extends State<QrInventoryScreen> {
  List<dynamic> _qrCodes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final qrCodes = await ApiClient.instance.listQrCodes();
      setState(() => _qrCodes = qrCodes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ASSIGNED_FREE':
        return Colors.green;
      case 'ASSIGNED_LOCKED':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _statusEmoji(String status) {
    switch (status) {
      case 'ASSIGNED_FREE':
        return '✅';
      case 'ASSIGNED_LOCKED':
        return '🚗';
      default:
        return '🚫';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ASSIGNED_FREE':
        return 'Free';
      case 'ASSIGNED_LOCKED':
        return 'In use';
      default:
        return 'Off';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎫  QR Tag Inventory')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _qrCodes.isEmpty
              ? const EmptyState(
                  emoji: '🎫',
                  title: 'No QR tags assigned to this hotel yet.\nAsk the admin to assign a batch.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: _qrCodes.length,
                    itemBuilder: (context, index) {
                      final qr = _qrCodes[index] as Map<String, dynamic>;
                      return Card(
                        color: Colors.white,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('#${qr['hotelLocalNumber']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                              const SizedBox(height: 8),
                              StatusBadge(
                                emoji: _statusEmoji(qr['status']),
                                label: _statusLabel(qr['status']),
                                color: _statusColor(qr['status']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
