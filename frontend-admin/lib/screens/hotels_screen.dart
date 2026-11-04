import 'package:flutter/material.dart';
import '../api_client.dart';
import '../widgets/dialog_helpers.dart';
import '../widgets/empty_state.dart';
import 'hotel_detail_screen.dart';

class HotelsScreen extends StatefulWidget {
  final String vendorId;
  final String vendorName;
  const HotelsScreen({super.key, required this.vendorId, required this.vendorName});

  @override
  State<HotelsScreen> createState() => _HotelsScreenState();
}

class _HotelsScreenState extends State<HotelsScreen> {
  List<dynamic> _hotels = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hotels = await ApiClient.instance.listHotels(vendorId: widget.vendorId);
      setState(() => _hotels = hotels);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _addHotel() async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add hotel'),
        content: dialogForm([
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Hotel name'), autofocus: true),
          TextField(controller: addressController, decoration: const InputDecoration(labelText: 'Address (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (result != true || nameController.text.trim().isEmpty) return;
    try {
      await ApiClient.instance.createHotel(
        vendorId: widget.vendorId,
        name: nameController.text.trim(),
        address: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
      );
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('🏢  ${widget.vendorName}')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHotel,
        icon: const Icon(Icons.add),
        label: const Text('Add hotel'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _hotels.isEmpty
                  ? const EmptyState(
                      emoji: '🏨',
                      title: 'No hotels yet',
                      subtitle: 'Add this vendor\'s first hotel branch to start\n'
                          'creating its manager login and QR tags.',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _hotels.length,
                        itemBuilder: (context, index) {
                          final hotel = _hotels[index] as Map<String, dynamic>;
                          final count = hotel['_count'] as Map<String, dynamic>?;
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                child: const Text('🏨'),
                              ),
                              title: Text(hotel['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                '🎫 ${count?['qrCodes'] ?? 0} QR tag(s)   ·   👤 ${count?['managers'] ?? 0} manager login(s)',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HotelDetailScreen(
                                    hotelId: hotel['id'],
                                    hotelName: hotel['name'],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
