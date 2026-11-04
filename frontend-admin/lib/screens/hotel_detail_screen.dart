import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/status_badge.dart';

class HotelDetailScreen extends StatefulWidget {
  final String hotelId;
  final String hotelName;
  const HotelDetailScreen({super.key, required this.hotelId, required this.hotelName});

  @override
  State<HotelDetailScreen> createState() => _HotelDetailScreenState();
}

class _HotelDetailScreenState extends State<HotelDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('🏨  ${widget.hotelName}'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Text('👤', style: TextStyle(fontSize: 18)), text: 'Managers'),
              Tab(icon: Text('🎫', style: TextStyle(fontSize: 18)), text: 'QR Tags'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ManagersTab(hotelId: widget.hotelId),
            _QrTagsTab(hotelId: widget.hotelId),
          ],
        ),
      ),
    );
  }
}

class _ManagersTab extends StatefulWidget {
  final String hotelId;
  const _ManagersTab({required this.hotelId});

  @override
  State<_ManagersTab> createState() => _ManagersTabState();
}

class _ManagersTabState extends State<_ManagersTab> {
  List<dynamic> _managers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final managers = await ApiClient.instance.listManagers(widget.hotelId);
      setState(() => _managers = managers);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addManager() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add manager login'),
        content: dialogForm([
          TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email'), autofocus: true),
          TextField(controller: passwordController, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (result != true) return;
    try {
      await ApiClient.instance.createManager(
        hotelId: widget.hotelId,
        email: emailController.text.trim(),
        password: passwordController.text,
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _resetPassword(String managerId) async {
    final controller = TextEditingController();
    final newPassword = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: dialogForm([
          TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'New password'),
            obscureText: true,
            autofocus: true,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Reset')),
        ],
      ),
    );
    if (newPassword == null || newPassword.isEmpty) return;
    try {
      await ApiClient.instance.resetManagerPassword(
        hotelId: widget.hotelId,
        managerId: managerId,
        newPassword: newPassword,
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManager,
        icon: const Icon(Icons.add),
        label: const Text('Add manager'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _managers.isEmpty
              ? const EmptyState(
                  emoji: '👤',
                  title: 'No manager login yet',
                  subtitle: 'This hotel\'s valet manager needs a login to see\n'
                      'the live dashboard. Add one to get started.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _managers.length,
                  itemBuilder: (context, index) {
                    final manager = _managers[index] as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
                          child: const Text('👤'),
                        ),
                        title: Text(manager['email'], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: const Text('Valet manager login'),
                        trailing: TextButton.icon(
                          icon: const Icon(Icons.lock_reset, size: 18),
                          onPressed: () => _resetPassword(manager['id']),
                          label: const Text('Reset password'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _QrTagsTab extends StatefulWidget {
  final String hotelId;
  const _QrTagsTab({required this.hotelId});

  @override
  State<_QrTagsTab> createState() => _QrTagsTabState();
}

class _QrTagsTabState extends State<_QrTagsTab> {
  List<dynamic> _qrCodes = [];
  bool _loading = true;
  final _countController = TextEditingController(text: '20');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final qrCodes = await ApiClient.instance.listQrCodes(widget.hotelId);
      setState(() => _qrCodes = qrCodes);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _assign() async {
    final count = int.tryParse(_countController.text.trim());
    if (count == null || count <= 0) return;
    try {
      await ApiClient.instance.assignQrCodes(hotelId: widget.hotelId, count: count);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _toggleStatus(Map<String, dynamic> qr) async {
    final newStatus = qr['status'] == 'DISABLED' ? 'ASSIGNED_FREE' : 'DISABLED';
    try {
      await ApiClient.instance.setQrStatus(qrId: qr['id'], status: newStatus);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _showQrImage(Map<String, dynamic> qr) async {
    try {
      final bytes = await ApiClient.instance.fetchQrImageBytes(qr['id']);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🎫  Tag #${qr['hotelLocalNumber']}'),
          content: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(Uint8List.fromList(bytes)),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Print this and attach it to the keychain tag.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
        return 'Disabled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('🎫  ', style: TextStyle(fontSize: 20)),
                Expanded(
                  child: Text(
                    'Assign a new batch of permanent QR tags to this hotel',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _countController,
                    decoration: const InputDecoration(labelText: 'Count'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _assign, child: const Text('Assign')),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _qrCodes.isEmpty
                  ? const EmptyState(
                      emoji: '🎫',
                      title: 'No QR tags yet',
                      subtitle: 'Choose how many tags this hotel needs (e.g. 20, 50,\n'
                          '100) and tap "Assign" above to generate the batch.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _qrCodes.length,
                      itemBuilder: (context, index) {
                        final qr = _qrCodes[index] as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                              child: const Text('🎫'),
                            ),
                            title: Text('Tag #${qr['hotelLocalNumber']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: StatusBadge(
                                emoji: _statusEmoji(qr['status']),
                                label: _statusLabel(qr['status']),
                                color: _statusColor(qr['status']),
                              ),
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.qr_code),
                                  tooltip: 'View / print',
                                  onPressed: () => _showQrImage(qr),
                                ),
                                IconButton(
                                  icon: Icon(qr['status'] == 'DISABLED' ? Icons.check_circle : Icons.block),
                                  tooltip: qr['status'] == 'DISABLED' ? 'Re-enable' : 'Disable (lost/damaged)',
                                  onPressed: qr['status'] == 'ASSIGNED_LOCKED' ? null : () => _toggleStatus(qr),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
