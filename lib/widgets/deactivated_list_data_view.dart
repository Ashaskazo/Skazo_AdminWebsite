import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/deactivated_pagination_provider.dart';

class DeactivatedListDataView extends ConsumerStatefulWidget {
  const DeactivatedListDataView({super.key});

  @override
  ConsumerState<DeactivatedListDataView> createState() =>
      _DeactivatedListDataViewState();
}

class _DeactivatedListDataViewState
    extends ConsumerState<DeactivatedListDataView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(deactivatedSearchQueryProvider);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(deactivatedPaginationProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _selectCustomDateRange(BuildContext context) async {
    final currentRange = ref.read(deactivatedCustomDateRangeProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      initialDateRange:
          currentRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFEF4444),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(deactivatedCustomDateRangeProvider.notifier).state = picked;
      ref.read(deactivatedDateFilterProvider.notifier).state = 'custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(deactivatedPaginationProvider);
    final selectedCity = ref.watch(deactivatedSelectedCityProvider);
    final dateFilter = ref.watch(deactivatedDateFilterProvider);
    final customDateRange = ref.watch(deactivatedCustomDateRangeProvider);
    final statusFilter = ref.watch(deactivatedStatusFilterProvider);

    final isSuper = ref.watch(isSuperAdminProvider);
    final assignedCities = ref.watch(currentAdminAssignedCitiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_off_rounded,
                          color: Color(0xFFEF4444),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Deactivated List',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage permanently deactivated businesses & service providers',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () async {
                    _searchController.clear();
                    ref.read(deactivatedSearchQueryProvider.notifier).state =
                        '';
                    ref.read(deactivatedSelectedCityProvider.notifier).state =
                        null;
                    ref.read(deactivatedDateFilterProvider.notifier).state =
                        null;
                    ref
                        .read(deactivatedCustomDateRangeProvider.notifier)
                        .state = null;
                    ref.read(deactivatedStatusFilterProvider.notifier).state =
                        'Deactivated';
                    await ref
                        .read(deactivatedPaginationProvider.notifier)
                        .refresh();
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFFEF4444),
                    size: 22,
                  ),
                  tooltip: 'Reset & Refresh',
                ),
              ),
            ],
          ),
        ),

        // Filter Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search Box
                  Container(
                    width: 320,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF0F172A,
                          ).withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {});
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 250),
                          () {
                            ref
                                .read(deactivatedSearchQueryProvider.notifier)
                                .state = value;
                          },
                        );
                      },
                      style: GoogleFonts.poppins(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search phone, uid, business name...',
                        hintStyle: GoogleFonts.poppins(
                          color: const Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF94A3B8),
                          size: 18,
                        ),
                        suffixIcon:
                            _searchController.text.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    color: Color(0xFF94A3B8),
                                    size: 16,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                    ref
                                        .read(
                                          deactivatedSearchQueryProvider
                                              .notifier,
                                        )
                                        .state = '';
                                  },
                                )
                                : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),

                  // Status Filter Dropdown
                  // Container(
                  //   height: 50,
                  //   padding: const EdgeInsets.symmetric(horizontal: 14),
                  //   decoration: BoxDecoration(
                  //     color: Colors.white,
                  //     borderRadius: BorderRadius.circular(14),
                  //     border: Border.all(color: const Color(0xFFE2E8F0)),
                  //   ),
                  //   child: DropdownButtonHideUnderline(
                  //     child: DropdownButton<String>(
                  //       value: statusFilter,
                  //       onChanged: (val) {
                  //         if (val != null) {
                  //           ref
                  //               .read(deactivatedStatusFilterProvider.notifier)
                  //               .state = val;
                  //         }
                  //       },
                  //       items: const [
                  //         DropdownMenuItem(
                  //           value: 'Deactivated',
                  //           child: Row(
                  //             children: [
                  //               Icon(
                  //                 Icons.block_rounded,
                  //                 size: 16,
                  //                 color: Color(0xFFEF4444),
                  //               ),
                  //               SizedBox(width: 8),
                  //               Text('Deactivated (Only)'),
                  //             ],
                  //           ),
                  //         ),
                  //         DropdownMenuItem(
                  //           value: 'All',
                  //           child: Row(
                  //             children: [
                  //               Icon(
                  //                 Icons.filter_list_rounded,
                  //                 size: 16,
                  //                 color: Color(0xFF64748B),
                  //               ),
                  //               SizedBox(width: 8),
                  //               Text('All Status'),
                  //             ],
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),

                  // City Filter Dropdown
                  ref
                      .watch(userCitiesProvider)
                      .when(
                        data: (cities) {
                          final cityNames = {...cities};
                          if (selectedCity != null) cityNames.add(selectedCity);
                          final dropdownItems = cityNames.toList()..sort();

                          return Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: selectedCity,
                                hint: Text(
                                  'City',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                                onChanged: (value) {
                                  ref
                                      .read(
                                        deactivatedSelectedCityProvider
                                            .notifier,
                                      )
                                      .state = value;
                                },
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      (!isSuper && assignedCities.isNotEmpty)
                                          ? 'My Cities (${assignedCities.join(', ')})'
                                          : 'All Cities',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                  ),
                                  ...dropdownItems.map(
                                    (item) => DropdownMenuItem<String?>(
                                      value: item,
                                      child: Text(
                                        item,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading:
                            () => const SizedBox(
                              width: 80,
                              child: LinearProgressIndicator(),
                            ),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                  // Date Filter on deactivatedAt Dropdown
                  Container(
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: dateFilter,
                        hint: Text(
                          'Deactivated Date',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        onChanged: (value) {
                          if (value == 'custom') {
                            _selectCustomDateRange(context);
                          } else {
                            ref
                                .read(
                                  deactivatedCustomDateRangeProvider.notifier,
                                )
                                .state = null;
                            ref
                                .read(deactivatedDateFilterProvider.notifier)
                                .state = value;
                          }
                        },
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.date_range_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'All Time',
                                  style: GoogleFonts.poppins(fontSize: 13),
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
                                  size: 16,
                                  color: Color(0xFF2563EB),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Today',
                                  style: GoogleFonts.poppins(fontSize: 13),
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
                                  size: 16,
                                  color: Color(0xFFEA580C),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Yesterday',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'week',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.date_range_rounded,
                                  size: 16,
                                  color: Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Last 7 Days',
                                  style: GoogleFonts.poppins(fontSize: 13),
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
                                  size: 16,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Last 30 Days',
                                  style: GoogleFonts.poppins(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: 'custom',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.edit_calendar_rounded,
                                  size: 16,
                                  color: Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Custom Date Range...',
                                  style: GoogleFonts.poppins(fontSize: 13),
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

              // Active Custom Date Range Badge
              if (dateFilter == 'custom' && customDateRange != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Range: ${DateFormat('dd MMM yyyy').format(customDateRange.start)} - ${DateFormat('dd MMM yyyy').format(customDateRange.end)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFEF4444),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              ref
                                  .read(
                                    deactivatedCustomDateRangeProvider.notifier,
                                  )
                                  .state = null;
                              ref
                                  .read(deactivatedDateFilterProvider.notifier)
                                  .state = null;
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Count Banner
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              Text(
                'Total Deactivated Records: ',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                paginationState.filteredCount != null
                    ? '${paginationState.filteredCount}'
                    : (paginationState.loading
                        ? '...'
                        : '${paginationState.users.length}'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFEF4444),
                ),
              ),
              if (paginationState.totalCount != null &&
                  paginationState.filteredCount !=
                      paginationState.totalCount) ...[
                Text(
                  ' (of ${paginationState.totalCount} total)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Main List Content
        Expanded(child: _buildList(paginationState)),
      ],
    );
  }

  Widget _buildList(dynamic paginationState) {
    if (paginationState.loading && paginationState.users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFEF4444)),
      );
    }

    if (paginationState.error != null && paginationState.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(
              'Error loading deactivated list',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${paginationState.error}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed:
                  () =>
                      ref
                          .read(deactivatedPaginationProvider.notifier)
                          .refresh(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (paginationState.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                size: 48,
                color: Color(0xFF10B981),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Deactivated Providers Found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No providers currently match isProviderDeativatedStatus == true with the chosen filters.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final users = paginationState.users;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      itemCount: users.length + (paginationState.loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFEF4444)),
            ),
          );
        }

        final user = users[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    final imageUrl = user.businesspic ?? '';
    final name = user.displayName;
    final city = user.city ?? user.cityCapital ?? 'No City';
    final phone = user.phone?.toString() ?? 'No Phone';
    final deactDate = user.deactivatedAt;
    final formattedDate =
        deactDate != null
            ? DateFormat('dd MMM yyyy, hh:mm a').format(deactDate)
            : 'Date not recorded';
    final reason = user.deactivationReason;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: () {
            // Reusing the EXACT SAME existing BusinessProfilePage!
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) =>
                        BusinessProfilePage(businessData: user.toMap()),
              ),
            );
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Container(
            width: 48,
            height: 48,
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
                            (_, __) => const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (_, __, ___) => const Icon(
                              Icons.business_rounded,
                              color: Color(0xFF94A3B8),
                            ),
                      )
                      : const Icon(
                        Icons.business_rounded,
                        color: Color(0xFF94A3B8),
                      ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pause_circle_filled_rounded,
                      size: 12,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'DEACTIVATED',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.phone_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.location_on_rounded,
                      size: 13,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      city,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deactivated: $formattedDate',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                    if (reason != null && reason.trim().isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Reason: ${reason.replaceAll('_', ' ')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}
