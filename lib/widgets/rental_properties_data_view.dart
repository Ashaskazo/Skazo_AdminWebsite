import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/pages/property_details_page.dart';

class RentalPropertiesDataView extends ConsumerWidget {
  const RentalPropertiesDataView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(paginatedRentalProvider);
    final searchQuery = ref.watch(rentalSearchQueryProvider);
    final selectedCity = ref.watch(rentalSelectedCityProvider);
    final unverifiedOnly = ref.watch(rentalUnverifiedOnlyProvider);
    final todayOnly = ref.watch(rentalTodayOnlyProvider);
    final notifier = ref.watch(paginatedRentalProvider.notifier);

    // Listen for filter changes
    ref.listen(rentalSearchQueryProvider, (_, __) => notifier.fetchInitial());
    ref.listen(rentalSelectedCityProvider, (_, __) => notifier.fetchInitial());
    ref.listen(rentalUnverifiedOnlyProvider, (_, __) => notifier.fetchInitial());
    ref.listen(rentalTodayOnlyProvider, (_, __) => notifier.fetchInitial());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rental Properties',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage real estate and rental listings.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    ref.read(rentalSearchQueryProvider.notifier).state = '';
                    ref.read(rentalSelectedCityProvider.notifier).state = null;
                    ref.read(rentalUnverifiedOnlyProvider.notifier).state = false;
                    ref.read(rentalTodayOnlyProvider.notifier).state = false;
                    notifier.fetchInitial();
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                children: [
                  // Search
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (v) => ref.read(rentalSearchQueryProvider.notifier).state = v,
                        decoration: InputDecoration(
                          hintText: 'Search properties...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // City Filter
                  ref.watch(rentalCitiesProvider).when(
                    data: (cities) => Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedCity,
                          hint: const Text('All Cities'),
                          onChanged: (v) => ref.read(rentalSelectedCityProvider.notifier).state = v,
                          items: <DropdownMenuItem<String?>>[
                            const DropdownMenuItem<String?>(value: null, child: Text('All Cities')),
                            ...cities.map((c) => DropdownMenuItem<String?>(value: c, child: Text(c))),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const SizedBox(width: 50, child: LinearProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildFilterChip(
                    ref,
                    'Unverified',
                    unverifiedOnly,
                    (v) => ref.read(rentalUnverifiedOnlyProvider.notifier).state = v,
                  ),
                  const SizedBox(width: 12),
                  _buildFilterChip(
                    ref,
                    'Today',
                    todayOnly,
                    (v) => ref.read(rentalTodayOnlyProvider.notifier).state = v,
                  ),
                  const Spacer(),
                  Text(
                    'Showing ${notifier.filteredCount} results',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // List View
        Expanded(
          child: dataAsync.when(
            data: (properties) {
              if (properties.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.home_work_outlined, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      Text('No properties found', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        final prop = properties[index];
                        return _buildPropertyCard(context, prop);
                      },
                    ),
                  ),
                  _buildPaginationFooter(notifier),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, bool isActive, Function(bool) onToggle) {
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: onToggle,
      selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFF2563EB),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Map<String, dynamic> prop) {
    final price = prop['rentAmount'] ?? prop['price'] ?? prop['rent'] ?? 'N/A';
    final title = prop['propertyName'] ?? prop['title'] ?? prop['name'] ?? 'Unnamed Property';
    final location = prop['location'] ?? prop['address'] ?? 'No address';
    final isVerified = prop['isPropertyVerified'] == true;

    // Robust image logic
    String? imageUrl;
    final List? photoUrls = prop['photoUrls'] as List?;
    if (photoUrls != null && photoUrls.isNotEmpty) {
      imageUrl = photoUrls.first.toString();
    } else if (prop['image'] != null) {
      imageUrl = prop['image'].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PropertyDetailsPage(propertyData: prop),
            ),
          );
        },
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
                  )
                : const Icon(Icons.home_outlined, color: Color(0xFF2563EB)),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
            if (isVerified) ...[
              const SizedBox(width: 6),
              const Icon(Icons.verified, size: 16, color: Color(0xFF2563EB)),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            Text(
              '₹$price',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildPaginationFooter(PaginatedRentalNotifier notifier) {
    final int start = (notifier.currentPage * notifier.pageSize) + 1;
    final int end = (notifier.currentPage + 1) * notifier.pageSize > notifier.filteredCount
        ? notifier.filteredCount
        : (notifier.currentPage + 1) * notifier.pageSize;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$start–$end of ${notifier.filteredCount}',
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: notifier.currentPage > 0 ? () => notifier.prevPage() : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: end < notifier.filteredCount ? () => notifier.nextPage() : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
