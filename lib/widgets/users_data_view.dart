import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';

class UsersDataView extends ConsumerStatefulWidget {
  const UsersDataView({super.key});

  @override
  ConsumerState<UsersDataView> createState() => _UsersDataViewState();
}

class _UsersDataViewState extends ConsumerState<UsersDataView> {
  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(paginatedUserProvider);
    final searchQuery = ref.watch(userSearchQueryProvider);
    final selectedCity = ref.watch(userSelectedCityProvider);
    final verifiedOnly = ref.watch(userVerifiedOnlyProvider);
    final dateFilter = ref.watch(userDateFilterProvider);
    final notifier = ref.watch(paginatedUserProvider.notifier);

    // Listen for filter changes and refresh the list
    ref.listen(userSearchQueryProvider, (_, __) => notifier.fetchInitial());
    ref.listen(userSelectedCityProvider, (_, __) => notifier.fetchInitial());
    ref.listen(userVerifiedOnlyProvider, (_, __) => notifier.fetchInitial());
    ref.listen(userDateFilterProvider, (_, __) => notifier.fetchInitial());

    // Listen for filter changes to reset pagination
    ref.listen(
      userSearchQueryProvider,
      (_, __) => ref.read(paginatedUserProvider.notifier).fetchInitial(),
    );
    ref.listen(
      userSelectedCityProvider,
      (_, __) => ref.read(paginatedUserProvider.notifier).fetchInitial(),
    );
    ref.listen(
      userDateFilterProvider,
      (_, __) => ref.read(paginatedUserProvider.notifier).fetchInitial(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verify and manage business/service providers',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
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
                    ref.read(userSearchQueryProvider.notifier).state = '';
                    ref.read(userSelectedCityProvider.notifier).state = null;
                    ref.read(userDateFilterProvider.notifier).state = null;
                    ref.read(paginatedUserProvider.notifier).fetchInitial();
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                  tooltip: 'Reset & Refresh',
                ),
              ),
            ],
          ),
        ),

        // Search & Filter Area
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Search Bar
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged:
                            (value) =>
                                ref
                                    .read(userSearchQueryProvider.notifier)
                                    .state = value,
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              verifiedOnly
                                  ? 'Search by business address...'
                                  : 'Search by phone number...',
                          hintStyle: GoogleFonts.poppins(
                            color: const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Smart City Filter
                  ref
                      .watch(userCitiesProvider)
                      .when(
                        data: (cities) {
                          final Set<String> cityNames = {...cities};
                          if (selectedCity != null) cityNames.add(selectedCity);

                          final dropdownItems = cityNames.toList();
                          dropdownItems.sort();

                          return Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: selectedCity,
                                hint: Text(
                                  'City',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                                onChanged: (value) {
                                  ref
                                      .read(userSelectedCityProvider.notifier)
                                      .state = value;
                                },
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All Cities'),
                                  ),
                                  ...dropdownItems.map(
                                    (item) => DropdownMenuItem<String?>(
                                      value: item,
                                      child: Text(item),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading:
                            () => const SizedBox(
                              width: 100,
                              child: LinearProgressIndicator(),
                            ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                  const SizedBox(width: 16),
                  // Registration Date Filter
                  Container(
                    height: 54,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: dateFilter,
                        hint: Text(
                          'Registration',
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                        onChanged: (value) {
                          ref.read(userDateFilterProvider.notifier).state =
                              value;
                        },
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.date_range_rounded,
                                  size: 18,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'All Time',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'today',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.today_rounded,
                                  size: 18,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Today',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'yesterday',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  size: 18,
                                  color: Color(0xFFEA580C),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Yesterday',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'month',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  size: 18,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Last 1 Month',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Filter Status & Service Provider Count
              Row(
                children: [
                  if (notifier.filteredCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Text(
                        selectedCity != null
                            ? 'Found ${notifier.filteredCount} ${verifiedOnly ? 'providers' : 'users'} in $selectedCity'
                            : searchQuery.isNotEmpty
                            ? 'Found ${notifier.filteredCount} matching ${verifiedOnly ? 'providers' : 'users'}'
                            : verifiedOnly
                            ? 'Total Service Providers: ${notifier.verifiedCount}'
                            : 'Total Users: ${notifier.totalCount}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  // Service Provider Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 14,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${notifier.verifiedCount} Service Providers',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Verified Only Toggle
                  Text(
                    'Verified Only',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Switch(
                    value: ref.watch(userVerifiedOnlyProvider),
                    activeThumbColor: const Color(0xFF16A34A),
                    activeTrackColor: const Color(
                      0xFF16A34A,
                    ).withValues(alpha: 0.5),
                    onChanged: (value) {
                      ref.read(userVerifiedOnlyProvider.notifier).state = value;
                      notifier.fetchInitial();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Data List
        Expanded(
          child: dataAsync.when(
            data: (users) {
              if (users.isEmpty) return _buildEmptyState();
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildUserCard(context, user);
                      },
                    ),
                  ),
                  _buildPaginationFooter(notifier),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationFooter(PaginatedUserNotifier notifier) {
    final int start = (notifier.currentPage * notifier.pageSize) + 1;
    final int end =
        (notifier.currentPage + 1) * notifier.pageSize > notifier.totalCount
            ? notifier.totalCount
            : (notifier.currentPage + 1) * notifier.pageSize;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$start–$end of ${notifier.totalCount}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 24),
          IconButton(
            onPressed:
                notifier.currentPage > 0 ? () => notifier.prevPage() : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            onPressed:
                end < notifier.totalCount ? () => notifier.nextPage() : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, Map<String, dynamic> user) {
    final bool isVerified = user['isverified'] ?? false;
    final String imageUrl = user['businesspic'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BusinessProfilePage(businessData: user),
              ),
            ),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF1F5F9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder:
                          (context, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      errorWidget:
                          (context, url, error) => const Icon(
                            Icons.business,
                            color: Color(0xFF94A3B8),
                          ),
                    )
                    : const Icon(Icons.business, color: Color(0xFF94A3B8)),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                user['businessname'] ??
                    user['firstname'] ??
                    user['name'] ??
                    'Unknown User',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            if (isVerified) const SizedBox(width: 4),
            if (isVerified)
              const Icon(
                Icons.verified_rounded,
                color: Color(0xFF2563EB),
                size: 16,
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user['email'] ?? user['phone']?.toString() ?? 'No Contact Info',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  size: 12,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  getSmartCity(user),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 11,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatRegistrationDate(user['createdAt']),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 48,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            'No users found',
            style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  String? _extractPincode(String? address) {
    if (address == null || address.isEmpty) return null;
    final match = RegExp(r'\d{6}').firstMatch(address);
    return match?.group(0);
  }

  String _formatRegistrationDate(dynamic createdAt) {
    if (createdAt == null) return 'N/A';
    DateTime? dateTime;
    if (createdAt is DateTime) {
      dateTime = createdAt;
    } else if (createdAt is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(createdAt);
    } else if (createdAt is String) {
      dateTime = DateTime.tryParse(createdAt);
    } else {
      try {
        dateTime = createdAt.toDate();
      } catch (_) {}
    }
    if (dateTime == null) return 'N/A';

    final day = dateTime.day.toString().padLeft(2, '0');
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[dateTime.month - 1];
    final year = dateTime.year;

    final hour24 = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$day $month $year, $hour12:$minute $ampm';
  }
}
