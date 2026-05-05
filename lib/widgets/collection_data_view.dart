import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/collections_provider.dart';

class CollectionDataView extends ConsumerWidget {
  final String collectionName;
  final String title;

  const CollectionDataView({
    super.key,
    required this.collectionName,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(collectionDataProvider(collectionName));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Area
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Managing collection: $collectionName',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(collectionDataProvider(collectionName)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Data Table / List
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: dataAsync.when(
              data: (docs) {
                if (docs.isEmpty) {
                  return _buildEmptyState();
                }

                // Get keys from first doc for generic table headers
                final keys = docs.first.keys.where((k) => k != 'id').toList();

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      dataRowMaxHeight: 80,
                      columns: [
                        const DataColumn(label: Text('ID')),
                        ...keys.take(5).map((key) => DataColumn(label: Text(_capitalize(key)))),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: docs.map((doc) {
                        return DataRow(
                          cells: [
                            DataCell(Text(doc['id'].toString().substring(0, 5) + '...')),
                            ...keys.take(5).map((key) {
                              final val = doc[key];
                              return DataCell(
                                SizedBox(
                                  width: 150,
                                  child: Text(
                                    val?.toString() ?? '-',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.visibility_outlined, color: Color(0xFF2563EB)),
                                    onPressed: () {},
                                    tooltip: 'View Details',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                    onPressed: () {},
                                    tooltip: 'Delete Document',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => _buildErrorState(err.toString()),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No documents found',
            style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Error loading data',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
