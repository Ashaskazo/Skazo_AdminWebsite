import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/models/user_pagination_state.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/user_pagination_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'dart:async';

class UsersDataView extends ConsumerStatefulWidget {
  const UsersDataView({super.key});

  @override
  ConsumerState<UsersDataView> createState() => _UsersDataViewState();
}

class _UsersDataViewState extends ConsumerState<UsersDataView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(userSearchQueryProvider);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(userPaginationProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Widget _buildTypeChips(WidgetRef ref, String currentType) {
    const types = ['All', 'Customers', 'Service Providers'];
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
                      ref.read(userTypeFilterProvider.notifier).state = type;
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

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(userPaginationProvider);
    final notifier = ref.read(userPaginationProvider.notifier);
    final searchQuery = ref.watch(userSearchQueryProvider);
    final selectedCity = ref.watch(userSelectedCityProvider);
    final verifiedOnly = ref.watch(userVerifiedOnlyProvider);
    final dateFilter = ref.watch(userDateFilterProvider);
    final selectedType = ref.watch(userTypeFilterProvider);

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
                  onPressed: () async {
                    _searchController.clear();
                    ref.read(userSearchQueryProvider.notifier).state = '';
                    ref.read(userSelectedCityProvider.notifier).state = null;
                    ref.read(userVerifiedOnlyProvider.notifier).state = false;
                    ref.read(userDateFilterProvider.notifier).state = null;
                    ref.read(userTypeFilterProvider.notifier).state = 'All';
                    await ref.read(userPaginationProvider.notifier).refresh();
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

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {});
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(
                            const Duration(milliseconds: 250),
                            () {
                              ref.read(userSearchQueryProvider.notifier).state =
                                  value;
                            },
                          );
                        },
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText:
                              selectedType == 'Service Providers'
                                  ? 'Search phone, uid, username, business name...'
                                  : 'Search phone, uid, username, business name...',
                          hintStyle: GoogleFonts.poppins(
                            color: const Color(0xFF94A3B8),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          suffixIcon:
                              _searchController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      color: Color(0xFF94A3B8),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                      ref
                                          .read(
                                            userSearchQueryProvider.notifier,
                                          )
                                          .state = '';
                                    },
                                  )
                                  : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ref
                      .watch(userCitiesProvider)
                      .when(
                        data: (cities) {
                          final cityNames = {...cities};
                          if (selectedCity != null) cityNames.add(selectedCity);
                          final dropdownItems = cityNames.toList()..sort();

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
                            value: 'week',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.date_range_rounded,
                                  size: 18,
                                  color: Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Last 7 Days',
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
                                  'Last 30 Days',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: '3months',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_view_month_rounded,
                                  size: 18,
                                  color: Color(0xFF0284C7),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Last 3 Months',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: '6months',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.event_note_rounded,
                                  size: 18,
                                  color: Color(0xFF9333EA),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Last 6 Months',
                                  style: GoogleFonts.poppins(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem<String?>(
                            value: '1year',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.event_available_rounded,
                                  size: 18,
                                  color: Color(0xFFCA8A04),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Last 1 Year',
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
              Row(
                children: [
                  Expanded(child: _buildTypeChips(ref, selectedType)),
                  const SizedBox(width: 16),
                  if (selectedType != 'Customers') ...[
                    Text(
                      'Verified Only',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Switch(
                      value: verifiedOnly,
                      activeThumbColor: const Color(0xFF16A34A),
                      activeTrackColor: const Color(
                        0xFF16A34A,
                      ).withValues(alpha: 0.5),
                      onChanged: (value) {
                        ref.read(userVerifiedOnlyProvider.notifier).state =
                            value;
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
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
                            ? 'Found ${notifier.filteredCount} ${selectedType == 'Service Providers'
                                ? 'providers'
                                : selectedType == 'Customers'
                                ? 'customers'
                                : 'accounts'} in $selectedCity'
                            : searchQuery.isNotEmpty
                            ? 'Found ${notifier.filteredCount} matching ${selectedType == 'Service Providers'
                                ? 'providers'
                                : selectedType == 'Customers'
                                ? 'customers'
                                : 'accounts'}'
                            : selectedType == 'Service Providers'
                            ? 'Total Service Providers: ${notifier.serviceProviderCount}'
                            : selectedType == 'Customers'
                            ? 'Total Customers: ${notifier.filteredCount}'
                            : 'Total Accounts: ${notifier.totalCount}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  const SizedBox(width: 12),
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
                          '${notifier.serviceProviderCount} Service Providers',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Expanded(child: _buildUserList(paginationState)),
      ],
    );
  }

  Widget _buildUserList(UserPaginationState state) {
    if (state.loading && state.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: ${state.error}', style: GoogleFonts.poppins()),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  () => ref.read(userPaginationProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.users.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(userPaginationProvider.notifier).refresh(),
      child: ListView.builder(
        key: const PageStorageKey('users_list'),
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount:
            state.users.length + (state.loadingMore || state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.users.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _UserListTile(
            key: ValueKey(state.users[index].id),
            user: state.users[index],
          );
        },
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
}

class _UserListTile extends StatefulWidget {
  final UserModel user;
  const _UserListTile({super.key, required this.user});

  @override
  State<_UserListTile> createState() => _UserListTileState();
}

class _UserListTileState extends State<_UserListTile>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = widget.user;
    final imageUrl = user.businesspic ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap:
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                          BusinessProfilePage(businessData: user.toMap()),
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
                        memCacheWidth: 200,
                        memCacheHeight: 200,
                        maxWidthDiskCache: 400,
                        placeholder:
                            (_, __) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (_, __, ___) => const Icon(
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
                  user.displayName,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
              if (user.isverified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2563EB),
                  size: 16,
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.email ?? user.phone?.toString() ?? 'No Contact Info',
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
                    getSmartCity(user.toMap()),
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
                    _formatRegistrationDate(user.createdAt),
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
      ),
    );
  }

  String _formatRegistrationDate(DateTime? dateTime) {
    if (dateTime == null) return 'N/A';

    const monthNames = [
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
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = monthNames[dateTime.month - 1];
    final year = dateTime.year;
    final hour24 = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;

    return '$day $month $year, $hour12:$minute $ampm';
  }
}
