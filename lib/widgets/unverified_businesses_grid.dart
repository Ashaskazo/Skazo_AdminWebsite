import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/constants/business_categories.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';

class UnverifiedBusinessesGrid extends ConsumerWidget {
  const UnverifiedBusinessesGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedCategory = ref.watch(dashboardSelectedCategoryProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child:
          selectedCategory != null
              ? _UserListView(category: selectedCategory)
              : const _CategoryGridView(),
    );
  }
}

class _CategoryGridView extends ConsumerWidget {
  const _CategoryGridView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryCountsAsync = ref.watch(categoryCountsProvider);

    return categoryCountsAsync.when(
      data: (categoryCounts) {
        const categories = kBusinessCategories;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:
                MediaQuery.of(context).size.width > 1200
                    ? 8
                    : (MediaQuery.of(context).size.width > 800 ? 4 : 2),
            childAspectRatio: 1.0,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final count = categoryCounts[category] ?? 0;

            return InkWell(
              onTap: () {
                ref.read(dashboardSelectedCategoryProvider.notifier).state =
                    category;
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient:
                      count > 0
                          ? const LinearGradient(
                            colors: [Color(0xFFFFFFFF), Color(0xFFEFF6FF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                          : null,
                  color: count > 0 ? null : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color:
                          count > 0
                              ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color:
                        count > 0
                            ? const Color(0xFF3B82F6).withValues(alpha: 0.4)
                            : const Color(0xFFE2E8F0),
                    width: count > 0 ? 1.8 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            count > 0
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.1)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        size: 28,
                        color:
                            count > 0
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        category,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight:
                              count > 0 ? FontWeight.w700 : FontWeight.w600,
                          color:
                              count > 0
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            count > 0
                                ? const Color(0xFF2563EB)
                                : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow:
                            count > 0
                                ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ]
                                : null,
                      ),
                      child: Text(
                        count > 0 ? '$count PENDING 🛡️' : 'CLEAN ✨',
                        style: GoogleFonts.poppins(
                          color:
                              count > 0
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading:
          () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
      error:
          (error, _) => Center(child: Text('Error loading categories: $error')),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'house cleaning':
      case 'pest control':
      case 'tank cleaning':
        return Icons.cleaning_services;
      case 'electricians':
      case 'plumbers':
        return Icons.electrical_services;
      case 'ac repair':
      case 'fridge repair':
      case 'washing machine repair':
      case 'cctv installation':
      case 'water purifier repair':
      case 'kitchen appliances repair':
      case 'tv repair':
      case 'phone & system repairs':
        return Icons.build;
      case 'wood works':
      case 'glass design works':
      case 'interior designers':
        return Icons.carpenter;
      case 'ceiling':
      case 'tiles':
        return Icons.home_repair_service;
      case 'painters':
        return Icons.format_paint;
      case 'purohith':
      case 'wedding halls':
      case 'photographers':
      case 'catering':
      case 'shamiyana':
      case 'bridal and groom makeup':
      case 'beauty services':
      case 'mehandi artists':
      case 'other event services':
        return Icons.celebration;
      case 'astrologers':
        return Icons.psychology;
      case 'packers and movers':
        return Icons.local_shipping;
      case 'car mechanic':
      case 'bike mechanic':
        return Icons.two_wheeler;
      case 'car drivers':
      case 'car travels':
      case 'autos':
        return Icons.directions_car;
      case 'welders':
        return Icons.hardware;
      case 'builders & contractors':
        return Icons.construction;
      case 'ambulance':
      case 'diagnostic centers':
        return Icons.medical_services;
      default:
        return Icons.category;
    }
  }
}

class _UserListView extends ConsumerStatefulWidget {
  final String category;
  const _UserListView({required this.category});

  @override
  ConsumerState<_UserListView> createState() => _UserListViewState();
}

class _UserListViewState extends ConsumerState<_UserListView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref
          .read(unverifiedPaginationProvider(widget.category).notifier)
          .loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(unverifiedPaginationProvider(widget.category));
    final citiesAsync = ref.watch(unverifiedCitiesProvider);
    final selectedCity = ref.watch(dashboardSelectedCityProvider);
    final listHeight = MediaQuery.of(context).size.height * 0.6;

    return Column(
      children: [
        // Header with Back button and City Filter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed:
                      () =>
                          ref
                              .read(dashboardSelectedCategoryProvider.notifier)
                              .state = null,
                ),
                Text(
                  widget.category,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            // City Filter
            citiesAsync.when(
              data:
                  (cities) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: DropdownButton<String?>(
                      value: selectedCity,
                      hint: const Text('All Cities'),
                      underline: const SizedBox(),
                      icon: const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Cities'),
                        ),
                        ...cities.map(
                          (city) =>
                              DropdownMenuItem(value: city, child: Text(city)),
                        ),
                      ],
                      onChanged:
                          (v) =>
                              ref
                                  .read(dashboardSelectedCityProvider.notifier)
                                  .state = v,
                    ),
                  ),
              loading:
                  () => const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              error: (_, __) => const SizedBox(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: listHeight,
          child: _buildPaginatedList(context, paginationState),
        ),
      ],
    );
  }

  Widget _buildPaginatedList(
    BuildContext context,
    UnverifiedPaginationState state,
  ) {
    if (state.loading && state.users.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error: ${state.error}',
              style: GoogleFonts.poppins(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref
                  .read(unverifiedPaginationProvider(widget.category).notifier)
                  .refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.users.isEmpty) {
      return Center(
        child: Text(
          'No unverified users found',
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(unverifiedPaginationProvider(widget.category).notifier).refresh(),
      child: ListView.builder(
        key: PageStorageKey('unverified_users_${widget.category}'),
        controller: _scrollController,
        itemCount: state.users.length + (state.loadingMore || state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.users.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final user = state.users[index];
          return _UnverifiedUserTile(user: user);
        },
      ),
    );
  }
}

class _UnverifiedUserTile extends ConsumerWidget {
  final UserModel user;

  const _UnverifiedUserTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final imageUrl = user.businesspic ?? '';
    final address = user.businessaddress ?? user.address ?? 'No Address';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFF1F5F9)),
      ),
      elevation: 0,
      borderOnForeground: true,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF1F5F9),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 200,
                    memCacheHeight: 200,
                    maxWidthDiskCache: 400,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.business,
                      color: Color(0xFF94A3B8),
                    ),
                  )
                : const Icon(Icons.business, color: Color(0xFF94A3B8)),
          ),
        ),
        title: Text(
          user.displayName,
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.email ?? user.phone?.toString() ?? 'No Email',
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            Text(
              address,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.visibility,
                color: Color(0xFF2563EB),
              ),
              tooltip: 'View Profile',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BusinessProfilePage(
                    businessData: user.toMap(),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.check_circle,
                color: Colors.green,
              ),
              tooltip: 'Verify & Activate',
              onPressed: () => _confirmVerify(
                context,
                ref,
                user.id,
                user.businessname,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.block_flipped,
                color: Colors.red,
              ),
              tooltip: 'Deactivate',
              onPressed: () => _confirmDeactivate(
                context,
                ref,
                user.id,
                user.businessname,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmVerify(
    BuildContext context,
    WidgetRef ref,
    String id,
    String? name,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Business'),
        content: Text(
          'Verify $name and allow them to take service requests?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(userVerificationProvider.notifier).verifyUser(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    String id,
    String? name,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deactivate Business'),
        content: Text(
          'Are you sure you want to deactivate $name? They will not be able to offer services.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(userVerificationProvider.notifier).deactivateUser(id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text(
              'Deactivate',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
