import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/address_search_provider.dart';
import '../../data/models/address_model.dart';
import 'location_picker_screen.dart';

/// Address search screen — searches via LocationRepository (Nominatim → Photon).
///
/// User types a query → debounce → search results → select → LocationPickerScreen.
class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cari Alamat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              context.read<AddressSearchProvider>().clearSearch();
              _searchController.clear();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Input (PRD §6) ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Cari alamat, jalan, tempat...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                context.read<AddressSearchProvider>().searchAddress(value);
              },
            ),
          ),

          // ── Results ──
          Expanded(
            child: Consumer<AddressSearchProvider>(
              builder: (context, provider, child) {
                // Loading state (PRD §32)
                if (provider.isLoading) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Mencari alamat...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Error state (PRD §34)
                if (provider.errorMessage != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            provider.errorMessage!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Coba:\n• Periksa ejaan\n• Masukkan nama jalan\n• Masukkan nomor rumah',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Empty state (PRD §33)
                if (provider.searchResults.isEmpty) {
                  if (_searchController.text.length >= 3) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Alamat tidak ditemukan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Coba:\n• Periksa ejaan\n• Masukkan nama jalan\n• Masukkan nomor rumah\n• Pilih lokasi langsung di peta',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LocationPickerScreen(),
                                  ),
                                );
                                if (result != null && context.mounted) {
                                  Navigator.pop(context, result);
                                }
                              },
                              icon: const Icon(Icons.map),
                              label: const Text('Pilih Lokasi di Peta'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return const Center(
                    child: Text(
                      'Masukkan minimal 3 karakter untuk mulai mencari.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                // Search results (PRD §7)
                return ListView.builder(
                  itemCount: provider.searchResults.length,
                  itemBuilder: (context, index) {
                    final Address address = provider.searchResults[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on,
                        color: Colors.grey,
                      ),
                      title: Text(
                        address.streetName ?? address.formattedAddress,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        [
                          address.district,
                          address.city,
                          address.province,
                        ].where((e) => e != null).join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () async {
                        // Navigate to location picker with selected address (PRD §13)
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationPickerScreen(
                              initialAddress: address,
                            ),
                          ),
                        );
                        if (result != null && context.mounted) {
                          Navigator.pop(context, result);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
