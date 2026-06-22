import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/pages/property_details_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RentalPropertiesDataView extends ConsumerStatefulWidget {
  const RentalPropertiesDataView({super.key});

  @override
  ConsumerState<RentalPropertiesDataView> createState() =>
      _RentalPropertiesDataViewState();
}

class _RentalPropertiesDataViewState
    extends ConsumerState<RentalPropertiesDataView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(paginatedRentalProvider);
    final selectedCity = ref.watch(rentalSelectedCityProvider);
    final selectedType = ref.watch(rentalTypeFilterProvider);
    final selectedTime = ref.watch(rentalTimeFilterProvider);
    final notifier = ref.watch(paginatedRentalProvider.notifier);

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
                    _searchController.clear();
                    ref.read(rentalSearchQueryProvider.notifier).state = '';
                    ref.read(rentalSelectedCityProvider.notifier).state = null;
                    ref.read(rentalTypeFilterProvider.notifier).state = 'All';
                    ref.read(rentalTimeFilterProvider.notifier).state =
                        'All Time';
                    notifier.fetchInitial();
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search
                  Container(
                    width:
                        MediaQuery.of(context).size.width > 800
                            ? 400
                            : double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged:
                          (v) =>
                              ref
                                  .read(rentalSearchQueryProvider.notifier)
                                  .state = v,
                      decoration: InputDecoration(
                        hintText: 'Search properties...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          rentalSearchQueryProvider.notifier,
                                        )
                                        .state = '';
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  // City Filter Dropdown
                  ref
                      .watch(rentalCitiesProvider)
                      .when(
                        data:
                            (cities) => Container(
                              height: 50,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: selectedCity,
                                  hint: const Text('All Cities'),
                                  onChanged:
                                      (v) =>
                                          ref
                                              .read(
                                                rentalSelectedCityProvider
                                                    .notifier,
                                              )
                                              .state = v,
                                  items: <DropdownMenuItem<String?>>[
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('All Cities'),
                                    ),
                                    ...cities.map(
                                      (c) => DropdownMenuItem<String?>(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        loading:
                            () => const SizedBox(
                              width: 50,
                              child: LinearProgressIndicator(),
                            ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                  // Time Filter Dropdown
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedTime,
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(rentalTimeFilterProvider.notifier).state =
                                v;
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'All Time',
                            child: Text('All Time'),
                          ),
                          DropdownMenuItem(
                            value: 'Today',
                            child: Text('Today'),
                          ),
                          DropdownMenuItem(
                            value: 'Yesterday',
                            child: Text('Yesterday'),
                          ),
                          DropdownMenuItem(
                            value: 'Last 7 Days',
                            child: Text('Last 7 Days'),
                          ),
                          DropdownMenuItem(
                            value: 'Last 30 Days',
                            child: Text('Last 30 Days'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildTypeChips(ref, selectedType)),
                  const SizedBox(width: 12),
                  Text(
                    'Showing ${notifier.filteredCount} results',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
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
                      const Icon(
                        Icons.home_work_outlined,
                        size: 48,
                        color: Color(0xFFCBD5E1),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No properties found',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF64748B),
                        ),
                      ),
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

  String? _getPropertyId(Map<String, dynamic> prop) {
    return prop['id']?.toString() ??
        prop['propertyId']?.toString() ??
        prop['docId']?.toString();
  }

  Future<void> _updatePropertyStatus({
    required Map<String, dynamic> prop,
    required bool isVerified,
  }) async {
    final propertyId = _getPropertyId(prop);

    if (propertyId == null || propertyId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Property ID missing')));
      return;
    }

    await FirebaseFirestore.instance
        .collection('rental_properties')
        .doc(propertyId)
        .set({
          'isPropertyVerified': isVerified,
          'status': isVerified ? 'live' : 'unverified',
          'isVisible': isVerified,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    ref.read(paginatedRentalProvider.notifier).fetchInitial();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVerified
              ? 'Property verified & live'
              : 'Property marked unverified',
        ),
      ),
    );
  }

  Future<void> _updatePropertyVisibility({
    required Map<String, dynamic> prop,
    required bool isVisible,
  }) async {
    final propertyId = _getPropertyId(prop);

    if (propertyId == null || propertyId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Property ID missing')));
      return;
    }

    await FirebaseFirestore.instance
        .collection('rental_properties')
        .doc(propertyId)
        .set({
          'isVisible': isVisible,
          'status': isVisible ? 'live' : 'hidden',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    ref.read(paginatedRentalProvider.notifier).fetchInitial();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVisible ? 'Property shown in app' : 'Property hidden from app',
        ),
      ),
    );
  }

  Widget _buildTypeChips(WidgetRef ref, String currentType) {
    final types = ['All', 'Verified', 'Unverified', 'Premium'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children:
            types.map((type) {
              final isActive = currentType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(type),
                  selected: isActive,
                  onSelected: (v) {
                    if (v) {
                      ref.read(rentalTypeFilterProvider.notifier).state = type;
                    }
                  },
                  selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  checkmarkColor: const Color(0xFF2563EB),
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color:
                        isActive
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  ),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color:
                          isActive
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildPropertyCard(BuildContext context, Map<String, dynamic> prop) {
    final price = prop['rentAmount'] ?? prop['price'] ?? prop['rent'] ?? 'N/A';
    final title =
        prop['propertyName'] ??
        prop['title'] ??
        prop['name'] ??
        'Unnamed Property';
    final location = prop['location'] ?? prop['address'] ?? 'No address';
    final isVerified = prop['isPropertyVerified'] == true;
    final plan = prop['ownerPlan']?.toString().toLowerCase() ?? '';
    final isBoosted = prop['isBoosted'] == true;
    final isPremium = prop['isPremium'] == true;
    final isPremiumProperty =
        plan.contains('premium') ||
        plan == 'paid' ||
        plan == '599' ||
        isBoosted ||
        isPremium;

    // Robust image logic using our new helper
    final List<String> imageUrls = extractPropertyImageUrls(prop);
    final String? imageUrl = imageUrls.isNotEmpty ? imageUrls.first : null;

    final bool isVisible = prop['isVisible'] == true;
    final String statusRaw = prop['status']?.toString().toLowerCase() ?? '';
    final String statusLabel =
        statusRaw.isNotEmpty
            ? statusRaw.replaceFirst(statusRaw[0], statusRaw[0].toUpperCase())
            : (isVerified ? 'Live' : 'Unverified');
    final Color statusColor =
        statusRaw == 'hidden' || !isVisible
            ? const Color(0xFFF59E0B)
            : statusRaw == 'unverified'
            ? const Color(0xFFEF4444)
            : statusRaw == 'rented'
            ? const Color(0xFF6B7280)
            : const Color(0xFF22C55E);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color:
                isPremiumProperty
                    ? const Color(0xFFFBBF24).withValues(alpha: 0.4)
                    : const Color(0xFFF1F5F9),
            width: isPremiumProperty ? 1.5 : 1.0,
          ),
        ),
        elevation: isPremiumProperty ? 1.5 : 0,
        child: ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PropertyDetailsPage(propertyData: prop),
              ),
            );
          },
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
              child:
                  imageUrl != null
                      ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder:
                            (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey,
                            ),
                      )
                      : const Icon(
                        Icons.home_outlined,
                        color: Color(0xFF2563EB),
                      ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              if (isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified, size: 16, color: Color(0xFF2563EB)),
              ],
              if (isPremiumProperty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PREMIUM',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
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
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
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
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildStatusBadge(statusLabel, statusColor),
                  _buildStatusBadge(
                    isVisible ? 'Visible' : 'Hidden',
                    isVisible
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFF59E0B),
                  ),
                ],
              ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Color(0xFF64748B)),
            onSelected: (value) {
              if (value == 'verify') {
                _updatePropertyStatus(prop: prop, isVerified: true);
              } else if (value == 'unverify') {
                _updatePropertyStatus(prop: prop, isVerified: false);
              } else if (value == 'show') {
                _updatePropertyVisibility(prop: prop, isVisible: true);
              } else if (value == 'hide') {
                _updatePropertyVisibility(prop: prop, isVisible: false);
              }
            },
            itemBuilder: (context) {
              final items = <PopupMenuEntry<String>>[];
              if (!isVerified) {
                items.add(
                  const PopupMenuItem(
                    value: 'verify',
                    child: Text('Verify & Make Live'),
                  ),
                );
              } else {
                items.add(
                  const PopupMenuItem(
                    value: 'unverify',
                    child: Text('Mark Unverified'),
                  ),
                );
              }
              if (isVisible) {
                items.add(
                  const PopupMenuItem(
                    value: 'hide',
                    child: Text('Hide from App'),
                  ),
                );
              } else {
                items.add(
                  const PopupMenuItem(
                    value: 'show',
                    child: Text('Show in App'),
                  ),
                );
              }
              return items;
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(PaginatedRentalNotifier notifier) {
    if (notifier.filteredCount == 0) return const SizedBox.shrink();

    final int start = (notifier.currentPage * notifier.pageSize) + 1;
    final int end =
        (notifier.currentPage + 1) * notifier.pageSize > notifier.filteredCount
            ? notifier.filteredCount
            : (notifier.currentPage + 1) * notifier.pageSize;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$start–$end of ${notifier.filteredCount}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed:
                notifier.currentPage > 0 ? () => notifier.prevPage() : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed:
                end < notifier.filteredCount ? () => notifier.nextPage() : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
