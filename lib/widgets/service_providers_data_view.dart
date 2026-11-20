
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/models/service_provider_overview_model.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/service_providers_provider.dart';
import 'package:skazo_admin/utils/responsive.dart';

/// Root data view for the Star Service Providers entity.
/// Seamlessly displays the category-wise/area-wise overview or drills down into a specific category or area provider list.
class ServiceProvidersDataView extends ConsumerWidget {
  const ServiceProvidersDataView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(starServiceProvidersActiveTabProvider);
    final drilldownArea = ref.watch(
      serviceProvidersDrilldownAreaGroupProvider,
    );
    final drilldownCategory = ref.watch(
      serviceProvidersDrilldownCategoryProvider,
    );

    Widget child;
    if (activeTab == StarServiceProvidersTab.emptySlots) {
      child = const _EmptySlotsView(key: ValueKey('empty_slots_view'));
    } else if (drilldownArea != null) {
      child = _AreaProviderListView(
        key: ValueKey('area_list_${drilldownArea.displayName}'),
        areaGroup: drilldownArea,
      );
    } else if (drilldownCategory != null) {
      child = _CategoryProviderListView(
        key: ValueKey('category_list_$drilldownCategory'),
        category: drilldownCategory,
      );
    } else {
      child = const _ServiceProvidersOverviewView(
        key: ValueKey('service_providers_overview'),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: child,
    );
  }
}

/// Tab switcher between Star Providers overview and Empty Slots analysis
Widget _buildEntityTabSwitcher(
  WidgetRef ref, {
  required StarServiceProvidersTab activeTab,
}) {
  return Container(
    key: const ValueKey('star_service_providers_tab_switcher'),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    padding: const EdgeInsets.all(3),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEntityTabButton(
            key: const ValueKey('tab_star_providers'),
            title: 'Star Providers',
            icon: Icons.stars_rounded,
            isSelected: activeTab == StarServiceProvidersTab.starProviders,
            onTap: () {
              if (activeTab != StarServiceProvidersTab.starProviders) {
                ref.read(starServiceProvidersActiveTabProvider.notifier).state =
                    StarServiceProvidersTab.starProviders;
              }
            },
          ),
          const SizedBox(width: 4),
          _buildEntityTabButton(
            key: const ValueKey('tab_empty_slots'),
            title: 'Empty Slots',
            icon: Icons.grid_view_rounded,
            isSelected: activeTab == StarServiceProvidersTab.emptySlots,
            onTap: () {
              if (activeTab != StarServiceProvidersTab.emptySlots) {
                ref.read(starServiceProvidersActiveTabProvider.notifier).state =
                    StarServiceProvidersTab.emptySlots;
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget _buildEntityTabButton({
  Key? key,
  required String title,
  required IconData icon,
  required bool isSelected,
  required VoidCallback onTap,
}) {
  return InkWell(
    key: key,
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: isSelected ? Colors.white : Colors.white70,
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.white70,
            ),
          ),
        ],
      ),
    ),
  );
}

/// ---------------------------------------------------------------------------
/// OVERVIEW SCREEN: Instant category-wise breakdown for selected City.
/// ---------------------------------------------------------------------------
class _ServiceProvidersOverviewView extends ConsumerStatefulWidget {
  const _ServiceProvidersOverviewView({super.key});

  @override
  ConsumerState<_ServiceProvidersOverviewView> createState() =>
      _ServiceProvidersOverviewViewState();
}

class _ServiceProvidersOverviewViewState
    extends ConsumerState<_ServiceProvidersOverviewView> {
  final ScrollController _cityScrollController = ScrollController();
  final ScrollController _zoneScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();

  @override
  void dispose() {
    _cityScrollController.dispose();
    _zoneScrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overviewAsync = ref.watch(serviceProvidersOverviewProvider);
    final selectedCity = ref.watch(serviceProvidersSelectedCityProvider);
    final selectedZone = ref.watch(serviceProvidersSelectedZoneProvider);
    final activeHorizontalFilter = ref.watch(
      serviceProvidersHorizontalFilterProvider,
    );
    final isSuper = ref.watch(isSuperAdminProvider);
    final assignedCities = ref.watch(currentAdminAssignedCitiesProvider);
    final allowedCitiesAsync = ref.watch(allowedCitiesProvider);

    final cityDisplay =
        selectedCity ??
        (!isSuper && assignedCities.isNotEmpty
            ? assignedCities.join(', ')
            : 'All Cities');

    final isHyderabad = isCityHyderabad(selectedCity);
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 32 : 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header & Summary Banner
            _buildTopHeader(
              context,
              ref,
              cityDisplay: cityDisplay,
              overviewAsync: overviewAsync,
            ),
            const SizedBox(height: 20),

            // Primary Filter Bar: City (Horizontally Scrollable)
            _buildFilterBar(
              context,
              ref,
              selectedCity: selectedCity,
              isSuper: isSuper,
              assignedCities: assignedCities,
              allowedCitiesAsync: allowedCitiesAsync,
              scrollController: _cityScrollController,
            ),

            // Zone Filter Bar — only for Hyderabad
            if (isHyderabad) ...[
              const SizedBox(height: 14),
              _buildZoneFilterBar(
                ref,
                selectedZone: selectedZone,
                scrollController: _zoneScrollController,
              ),
            ],
            const SizedBox(height: 24),

            // Horizontal Category Quick Bar (Horizontally Scrollable)
            overviewAsync.maybeWhen(
              data:
                  (data) => _buildHorizontalCategoryBar(
                    ref,
                    data: data,
                    activeFilter: activeHorizontalFilter,
                    scrollController: _categoryScrollController,
                  ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),

            // Category Overview Chess Grid
            overviewAsync.when(
              data:
                  (data) => _buildCategoryGrid(
                    context,
                    ref,
                    data: data,
                    activeFilter: activeHorizontalFilter,
                    cityDisplay: cityDisplay,
                  ),
              loading: () => _buildLoadingGrid(context),
              error: (err, _) => _buildErrorState(ref, err.toString()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(
    BuildContext context,
    WidgetRef ref, {
    required String cityDisplay,
    required AsyncValue<ServiceProvidersOverviewData> overviewAsync,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final refreshBtn = IconButton(
      onPressed: () => ref.invalidate(serviceProvidersOverviewProvider),
      icon: const Icon(
        Icons.refresh_rounded,
        color: Colors.white70,
      ),
      tooltip: 'Refresh Overview',
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.handyman_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'SERVICE PROVIDERS',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  _buildEntityTabSwitcher(
                    ref,
                    activeTab: StarServiceProvidersTab.starProviders,
                  ),
                ],
              ),
            ),
            if (isMobile) refreshBtn,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                cityDisplay,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );

    final statsSection = overviewAsync.maybeWhen(
      data: (data) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildHeaderStatChip(
            label: 'Total Providers',
            value: '${data.totalProviders}',
            color: const Color(0xFF38BDF8),
          ),
          _buildHeaderStatChip(
            label: 'Categories',
            value: '${data.totalCategories}',
            color: const Color(0xFFA78BFA),
          ),
          if (!isMobile) refreshBtn,
        ],
      ),
      orElse: () => isMobile ? const SizedBox.shrink() : refreshBtn,
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                statsSection,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              statsSection,
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(
    BuildContext context,
    WidgetRef ref, {
    required String? selectedCity,
    required bool isSuper,
    required List<String> assignedCities,
    required AsyncValue<List<String>> allowedCitiesAsync,
    required ScrollController scrollController,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text(
          //   'City:',
          //   style: GoogleFonts.poppins(
          //     fontSize: 13,
          //     fontWeight: FontWeight.w700,
          //     color: const Color(0xFF475569),
          //   ),
          // ),
          // const SizedBox(height: 8),

          allowedCitiesAsync.when(
            data: (cities) {
              final uniqueCities = cities.toSet().toList()..sort();

              return SizedBox(
                width: double.infinity,
                // Extra 18px below pills for the scrollbar track
                height: 60,
                child: Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent) {
                      final delta = event.scrollDelta.dy;
                      final newOffset = (scrollController.offset + delta).clamp(
                        scrollController.position.minScrollExtent,
                        scrollController.position.maxScrollExtent,
                      );
                      scrollController.jumpTo(newOffset);
                    }
                  },
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: true,
                    notificationPredicate: (n) => n.depth == 0,
                    child: SingleChildScrollView(
                      controller: scrollController,
                      scrollDirection: Axis.horizontal,
                      physics: const AlwaysScrollableScrollPhysics(),
                      // Bottom padding reserves space for the scrollbar track
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // All Cities / My Cities
                          _buildCityPill(
                            label:
                                (!isSuper && assignedCities.isNotEmpty)
                                    ? 'My Cities'
                                    : 'All Cities',
                            isSelected: selectedCity == null,
                            onTap: () {
                              ref
                                  .read(
                                    serviceProvidersSelectedCityProvider
                                        .notifier,
                                  )
                                  .state = null;
                              // Reset zone when leaving Hyderabad
                              ref
                                  .read(
                                    serviceProvidersSelectedZoneProvider
                                        .notifier,
                                  )
                                  .state = null;
                            },
                          ),
                          const SizedBox(width: 8),

                          // Individual Cities
                          ...uniqueCities.map(
                            (city) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildCityPill(
                                label: city,
                                isSelected: selectedCity == city,
                                onTap: () {
                                  ref
                                      .read(
                                        serviceProvidersSelectedCityProvider
                                            .notifier,
                                      )
                                      .state = city;
                                  // Reset zone when switching cities
                                  if (selectedCity != city) {
                                    ref
                                        .read(
                                          serviceProvidersSelectedZoneProvider
                                              .notifier,
                                        )
                                        .state = null;
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading:
                () => const SizedBox(
                  height: 42,
                  width: 120,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// Builds the Hyderabad Zone filter bar.
  /// Shown only when City = Hyderabad.
  /// Selecting a zone pre-filters providers by exact pincode before category aggregation.
  Widget _buildZoneFilterBar(
    WidgetRef ref, {
    required ServiceProviderAreaGroup? selectedZone,
    required ScrollController scrollController,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_searching_rounded,
                size: 14,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                'Zone',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              if (selectedZone != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selectedZone.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  final delta = event.scrollDelta.dy;
                  final newOffset = (scrollController.offset + delta).clamp(
                    scrollController.position.minScrollExtent,
                    scrollController.position.maxScrollExtent,
                  );
                  scrollController.jumpTo(newOffset);
                }
              },
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                notificationPredicate: (n) => n.depth == 0,
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // All Zones pill
                      _buildZonePill(
                        label: 'All Zones',
                        isSelected: selectedZone == null,
                        onTap: () {
                          ref
                              .read(
                                serviceProvidersSelectedZoneProvider.notifier,
                              )
                              .state = null;
                        },
                      ),
                      const SizedBox(width: 8),
                      // Individual zone pills
                      ...kHyderabadAreaGroups.map((zone) {
                        final isSelected =
                            selectedZone?.displayName == zone.displayName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildZonePill(
                            label: zone.displayName,
                            isSelected: isSelected,
                            onTap: () {
                              ref
                                  .read(
                                    serviceProvidersSelectedZoneProvider
                                        .notifier,
                                  )
                                  .state = isSelected ? null : zone;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF059669)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF059669)
                    : const Color(0xFFCBD5E1),
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCategoryBar(
    WidgetRef ref, {
    required ServiceProvidersOverviewData data,
    required String? activeFilter,
    required ScrollController scrollController,
  }) {
    final categories = data.categories;
    if (categories.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      // Extra 18px below pills for the scrollbar track
      height: 60,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            final delta = event.scrollDelta.dy;
            final newOffset = (scrollController.offset + delta).clamp(
              scrollController.position.minScrollExtent,
              scrollController.position.maxScrollExtent,
            );
            scrollController.jumpTo(newOffset);
          }
        },
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          notificationPredicate: (n) => n.depth == 0,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            // Bottom padding reserves space for the scrollbar track
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "All" Filter Button
                _buildCategoryPill(
                  label: 'All (${data.totalProviders})',
                  isSelected: activeFilter == null,
                  onTap:
                      () =>
                          ref
                              .read(
                                serviceProvidersHorizontalFilterProvider
                                    .notifier,
                              )
                              .state = null,
                ),
                const SizedBox(width: 8),
                ...categories.map((cat) {
                  final isSelected = activeFilter == cat.categoryName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildCategoryPill(
                      label: '${cat.categoryName} (${cat.totalCount})',
                      isSelected: isSelected,
                      onTap: () {
                        ref
                            .read(
                              serviceProvidersHorizontalFilterProvider
                                  .notifier,
                            )
                            .state = isSelected ? null : cat.categoryName;
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context,
    WidgetRef ref, {
    required ServiceProvidersOverviewData data,
    required String? activeFilter,
    required String cityDisplay,
  }) {

    var displayCategories = data.categories;

    if (activeFilter != null) {
      displayCategories =
          displayCategories
              .where((c) => c.categoryName == activeFilter)
              .toList();
    }

    if (displayCategories.isEmpty) {
      return _buildEmptyState(cityDisplay);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'CATEGORY OVERVIEW',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            Text(
              'Click any card to view provider list',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // LayoutBuilder gives us the *actual* available column width after
        // padding, so cross-axis count and aspect ratio are always correct.
        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;

            // Breakpoints: mobile < 480, tablet 480-799, desktop-sm 800-1099,
            // desktop-md 1100-1399, desktop-lg ≥ 1400
            final int crossAxisCount;
            final double childAspectRatio;

            if (w < 480) {
              // Single column — card fills the full width; ensure safe height
              crossAxisCount = 1;
              childAspectRatio = 2.15;
            } else if (w < 800) {
              crossAxisCount = 2;
              childAspectRatio = 1.4;
            } else if (w < 1100) {
              crossAxisCount = 3;
              childAspectRatio = 1.5;
            } else if (w < 1400) {
              crossAxisCount = 4;
              childAspectRatio = 1.4;
            } else {
              crossAxisCount = 5;
              childAspectRatio = 1.35;
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: childAspectRatio,
              ),
              itemCount: displayCategories.length,
              itemBuilder: (context, index) {
                final stats = displayCategories[index];
                return _CategoryOverviewCard(
                  stats: stats,
                  onTap: () {
                    ref
                        .read(serviceProvidersDrilldownCategoryProvider.notifier)
                        .state = stats.categoryName;
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildLoadingGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount;
        final double childAspectRatio;

        if (w < 480) {
          crossAxisCount = 1;
          childAspectRatio = 2.15;
        } else if (w < 800) {
          crossAxisCount = 2;
          childAspectRatio = 1.4;
        } else if (w < 1100) {
          crossAxisCount = 3;
          childAspectRatio = 1.5;
        } else if (w < 1400) {
          crossAxisCount = 4;
          childAspectRatio = 1.4;
        } else {
          crossAxisCount = 5;
          childAspectRatio = 1.35;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: 8,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String cityDisplay) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.engineering_rounded,
              size: 44,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Star Service Providers Found',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No star service providers found in $cityDisplay.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFEE2E2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            'Unable to load service providers',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(serviceProvidersOverviewProvider),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// CATEGORY OVERVIEW CARD COMPONENT (CHESS-GRID ITEM)
/// ---------------------------------------------------------------------------
class _CategoryOverviewCard extends StatefulWidget {
  final ServiceProviderCategoryStats stats;
  final VoidCallback onTap;

  const _CategoryOverviewCard({required this.stats, required this.onTap});

  @override
  State<_CategoryOverviewCard> createState() => _CategoryOverviewCardState();
}

class _CategoryOverviewCardState extends State<_CategoryOverviewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform:
              _isHovered
                  ? Matrix4.translationValues(0, -3, 0)
                  : Matrix4.identity(),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  _isHovered
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    _isHovered
                        ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                        : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: _isHovered ? 14 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Category Name + Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stats.categoryName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getCategoryIcon(stats.categoryName),
                      color: const Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                ],
              ),

              // Middle: Large Provider Count
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${stats.totalCount}',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    stats.totalCount == 1 ? 'Provider' : 'Providers',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // Bottom: View Providers link & arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View Providers',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          _isHovered
                              ? const Color(0xFF0284C7)
                              : const Color(0xFF64748B),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color:
                        _isHovered
                            ? const Color(0xFF0284C7)
                            : const Color(0xFFCBD5E1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// HYDERABAD AREA OVERVIEW CARD COMPONENT (GRID ITEM)
/// ---------------------------------------------------------------------------
class _AreaOverviewCard extends StatefulWidget {
  final ServiceProviderAreaStats stats;
  final VoidCallback onTap;

  const _AreaOverviewCard({required this.stats, required this.onTap});

  @override
  State<_AreaOverviewCard> createState() => _AreaOverviewCardState();
}

class _AreaOverviewCardState extends State<_AreaOverviewCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform:
              _isHovered
                  ? Matrix4.translationValues(0, -3, 0)
                  : Matrix4.identity(),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  _isHovered
                      ? const Color(0xFF0284C7)
                      : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    _isHovered
                        ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                        : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: _isHovered ? 14 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Area Display Name + Location Pin Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      stats.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                ],
              ),

              // Middle: Large Provider Count
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${stats.totalCount}',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    stats.totalCount == 1 ? 'Provider' : 'Providers',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),

              // Bottom: Pincodes badge & View Providers arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${stats.pincodes.length} PIN Codes',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'View Providers',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              _isHovered
                                  ? const Color(0xFF0284C7)
                                  : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color:
                            _isHovered
                                ? const Color(0xFF0284C7)
                                : const Color(0xFFCBD5E1),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// DRILL-DOWN SCREEN: Server-side paginated category provider list.
/// ---------------------------------------------------------------------------
class _CategoryProviderListView extends ConsumerStatefulWidget {
  final String category;
  const _CategoryProviderListView({super.key, required this.category});

  @override
  ConsumerState<_CategoryProviderListView> createState() =>
      _CategoryProviderListViewState();
}

class _CategoryProviderListViewState
    extends ConsumerState<_CategoryProviderListView> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(
      serviceProvidersCategorySearchQueryProvider,
    );
    _searchController.text = initialQuery;
    _hasSearchText = initialQuery.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(
      categoryProvidersPaginationProvider(widget.category),
    );
    final selectedCity = ref.watch(serviceProvidersSelectedCityProvider);
    final selectedZone = ref.watch(serviceProvidersSelectedZoneProvider);
    final isSuper = ref.watch(isSuperAdminProvider);
    final assignedCities = ref.watch(currentAdminAssignedCitiesProvider);

    final cityDisplay =
        selectedCity ??
        (!isSuper && assignedCities.isNotEmpty
            ? assignedCities.join(', ')
            : 'All Cities');

    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 32 : 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation & Header
            _buildHeader(
              context,
              ref,
              cityDisplay: cityDisplay,
              selectedZone: selectedZone,
              paginationState: paginationState,
            ),
            const SizedBox(height: 20),

            // Search Filter Bar
            _buildSearchBar(ref),
            const SizedBox(height: 20),

            // Server-Paginated Providers List / Table
            _buildProvidersContent(context, ref, paginationState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref, {
    required String cityDisplay,
    required ServiceProviderAreaGroup? selectedZone,
    required CategoryProvidersPaginationState paginationState,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          InkWell(
            onTap: () {
              ref
                  .read(serviceProvidersDrilldownCategoryProvider.notifier)
                  .state = null;
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Back to Service Providers Overview',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title & Scope Row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.category.toUpperCase()} PROVIDERS',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cityDisplay,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      // Zone badge — shown when a specific zone is active
                      if (selectedZone != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_searching_rounded,
                                size: 10,
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                selectedZone.displayName,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'STAR PROVIDERS',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (paginationState.totalCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${paginationState.totalCount} Total',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          final hasText = value.isNotEmpty;
          if (_hasSearchText != hasText) {
            setState(() {
              _hasSearchText = hasText;
            });
          }
          ref.read(serviceProvidersCategorySearchQueryProvider.notifier).state =
              value;
        },
        style: GoogleFonts.poppins(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search provider by name, phone, business name, UID...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          suffixIcon:
              _hasSearchText
                  ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _hasSearchText = false;
                      });
                      ref
                          .read(
                            serviceProvidersCategorySearchQueryProvider
                                .notifier,
                          )
                          .state = '';
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildProvidersContent(
    BuildContext context,
    WidgetRef ref,
    CategoryProvidersPaginationState state,
  ) {
    if (state.loading && state.providers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      );
    }

    if (state.error != null && state.providers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Error: ${state.error}',
                style: GoogleFonts.poppins(color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    () =>
                        ref
                            .read(
                              categoryProvidersPaginationProvider(
                                widget.category,
                              ).notifier,
                            )
                            .refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.providers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              'No Star Service Providers found in this category',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Column(
      children: [
        isDesktop ? _buildDesktopTable(state) : _buildMobileCardsList(state),
        const SizedBox(height: 16),
        if (state.hasMore)
          Center(
            child: ElevatedButton.icon(
              onPressed:
                  state.loadingMore
                      ? null
                      : () =>
                          ref
                              .read(
                                categoryProvidersPaginationProvider(
                                  widget.category,
                                ).notifier,
                              )
                              .loadMore(),
              icon:
                  state.loadingMore
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.expand_more_rounded),
              label: Text(
                state.loadingMore ? 'Loading...' : 'Load More Providers',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopTable(CategoryProvidersPaginationState state) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 850),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dataRowMaxHeight: 64,
              columnSpacing: 20,
              horizontalMargin: 16,
              columns: const [
                DataColumn(label: Text('S.No')),
                DataColumn(label: Text('Provider / Business')),
                DataColumn(label: Text('Phone')),
                DataColumn(label: Text('City / Address')),
                DataColumn(label: Text('Registered Date')),
                DataColumn(label: Text('Action')),
              ],
              rows: List.generate(state.providers.length, (index) {
                final UserModel user = state.providers[index];
                final sn = index + 1;

                return DataRow(
                  cells: [
                    // 1. S.No
                    DataCell(
                      Text(
                        '$sn',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // 2. Provider Name & Pic
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFF1F5F9),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  user.businesspic?.isNotEmpty == true
                                      ? CachedNetworkImage(
                                        imageUrl: user.businesspic!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 100,
                                        memCacheHeight: 100,
                                        placeholder:
                                            (_, __) => const Center(
                                              child: SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                            ),
                                        errorWidget:
                                            (_, __, ___) => const Icon(
                                              Icons.business,
                                              size: 18,
                                              color: Color(0xFF94A3B8),
                                            ),
                                      )
                                      : const Icon(
                                        Icons.business,
                                        size: 18,
                                        color: Color(0xFF94A3B8),
                                      ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Text(
                              user.displayName,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Phone
                    DataCell(
                      Text(
                        user.phone != null ? '${user.phone}' : '--',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),

                    // 4. City / Address
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          user.city ??
                              user.businessaddress ??
                              user.address ??
                              '--',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // 5. Registered Date
                    DataCell(
                      Text(
                        user.createdAt != null
                            ? dateFormat.format(user.createdAt!)
                            : '--',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // 6. Action: View Profile
                    DataCell(
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_rounded,
                          size: 20,
                          color: Color(0xFF0284C7),
                        ),
                        tooltip: 'View Profile',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => BusinessProfilePage(
                                    businessData: user.toMap(),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardsList(CategoryProvidersPaginationState state) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.providers.length,
      itemBuilder: (context, index) {
        final UserModel user = state.providers[index];
        final sn = index + 1;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF1F5F9),
              child: Text(
                '#$sn',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ),
            title: Text(
              user.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              '${user.phone ?? 'No Phone'} • ${user.city ?? 'No City'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(
                Icons.visibility_rounded,
                color: Color(0xFF0284C7),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (_) => BusinessProfilePage(businessData: user.toMap()),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// ---------------------------------------------------------------------------
/// DRILL-DOWN SCREEN: Server-side paginated Hyderabad area provider list.
/// ---------------------------------------------------------------------------
class _AreaProviderListView extends ConsumerStatefulWidget {
  final ServiceProviderAreaGroup areaGroup;
  const _AreaProviderListView({super.key, required this.areaGroup});

  @override
  ConsumerState<_AreaProviderListView> createState() =>
      _AreaProviderListViewState();
}

class _AreaProviderListViewState
    extends ConsumerState<_AreaProviderListView> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(
      serviceProvidersCategorySearchQueryProvider,
    );
    _searchController.text = initialQuery;
    _hasSearchText = initialQuery.isNotEmpty;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paginationState = ref.watch(
      areaProvidersPaginationProvider(widget.areaGroup.displayName),
    );
    final selectedCity = ref.watch(serviceProvidersSelectedCityProvider);
    final isSuper = ref.watch(isSuperAdminProvider);
    final assignedCities = ref.watch(currentAdminAssignedCitiesProvider);

    final cityDisplay =
        selectedCity ??
        (!isSuper && assignedCities.isNotEmpty
            ? assignedCities.join(', ')
            : 'Hyderabad');

    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 32 : 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Navigation & Header
            _buildHeader(
              context,
              ref,
              cityDisplay: cityDisplay,
              paginationState: paginationState,
            ),
            const SizedBox(height: 20),

            // Search Filter Bar
            _buildSearchBar(ref),
            const SizedBox(height: 20),

            // Server-Paginated Providers List / Table
            _buildProvidersContent(context, ref, paginationState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref, {
    required String cityDisplay,
    required CategoryProvidersPaginationState paginationState,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back Button
          InkWell(
            onTap: () {
              ref
                  .read(serviceProvidersDrilldownAreaGroupProvider.notifier)
                  .state = null;
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_back_rounded,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Back to Service Providers Overview',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Title & Scope Row
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.areaGroup.displayName.toUpperCase()} PROVIDERS',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          cityDisplay,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'STAR PROVIDERS',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0284C7),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          'PINs: ${widget.areaGroup.pincodes.join(', ')}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (paginationState.totalCount != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${paginationState.totalCount} Total',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(WidgetRef ref) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          final hasText = value.isNotEmpty;
          if (_hasSearchText != hasText) {
            setState(() {
              _hasSearchText = hasText;
            });
          }
          ref.read(serviceProvidersCategorySearchQueryProvider.notifier).state =
              value;
        },
        style: GoogleFonts.poppins(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search provider by name, phone, business name, UID...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          suffixIcon:
              _hasSearchText
                  ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: Color(0xFF94A3B8),
                      size: 18,
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _hasSearchText = false;
                      });
                      ref
                          .read(
                            serviceProvidersCategorySearchQueryProvider
                                .notifier,
                          )
                          .state = '';
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildProvidersContent(
    BuildContext context,
    WidgetRef ref,
    CategoryProvidersPaginationState state,
  ) {
    if (state.loading && state.providers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      );
    }

    if (state.error != null && state.providers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 40,
              ),
              const SizedBox(height: 8),
              Text(
                'Error: ${state.error}',
                style: GoogleFonts.poppins(color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed:
                    () =>
                        ref
                            .read(
                              areaProvidersPaginationProvider(
                                widget.areaGroup.displayName,
                              ).notifier,
                            )
                            .refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.providers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 12),
            Text(
              'No Star Service Providers found in ${widget.areaGroup.displayName}',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Column(
      children: [
        isDesktop ? _buildDesktopTable(state) : _buildMobileCardsList(state),
        const SizedBox(height: 16),
        if (state.hasMore)
          Center(
            child: ElevatedButton.icon(
              onPressed:
                  state.loadingMore
                      ? null
                      : () =>
                          ref
                              .read(
                                areaProvidersPaginationProvider(
                                  widget.areaGroup.displayName,
                                ).notifier,
                              )
                              .loadMore(),
              icon:
                  state.loadingMore
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.expand_more_rounded),
              label: Text(
                state.loadingMore ? 'Loading...' : 'Load More Providers',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDesktopTable(CategoryProvidersPaginationState state) {
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 900),
            child: DataTable(
              headingRowHeight: 52,
              dataRowMinHeight: 68,
              dataRowMaxHeight: 68,
              horizontalMargin: 20,
              columnSpacing: 24,
              headingRowColor: WidgetStateProperty.all(
                const Color(0xFFF8FAFC),
              ),
              columns: [
                DataColumn(
                  label: Text(
                    'BUSINESS NAME',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CATEGORIES',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PHONE',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CITY / ADDRESS',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'REGISTERED DATE',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACTIONS',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
              rows: List.generate(state.providers.length, (index) {
                final UserModel user = state.providers[index];
                final isEven = index % 2 == 0;

                final rawCat = user.category;
                final cats = <String>[];
                if (rawCat is List) {
                  for (final item in rawCat) {
                    if (item != null && item.toString().trim().isNotEmpty) {
                      cats.add(item.toString().trim());
                    }
                  }
                } else if (rawCat is String && rawCat.trim().isNotEmpty) {
                  cats.add(rawCat.trim());
                }

                return DataRow(
                  color: WidgetStateProperty.all(
                    isEven ? Colors.white : const Color(0xFFFAFAFA),
                  ),
                  cells: [
                    // 1. Business Name & Avatar
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child:
                                user.businesspic != null &&
                                        user.businesspic!.isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: user.businesspic!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorWidget:
                                          (_, __, ___) => Container(
                                            width: 40,
                                            height: 40,
                                            color: const Color(0xFFE2E8F0),
                                            child: const Icon(
                                              Icons.business_rounded,
                                              size: 20,
                                              color: Color(0xFF94A3B8),
                                            ),
                                          ),
                                    )
                                    : Container(
                                      width: 40,
                                      height: 40,
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(
                                        Icons.business_rounded,
                                        size: 20,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                          ),
                          const SizedBox(width: 12),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 180),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  user.businessname?.trim().isNotEmpty == true
                                      ? user.businessname!
                                      : user.displayName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'UID: ${user.uid ?? user.id}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 2. Categories
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children:
                              cats.isEmpty
                                  ? [
                                    Text(
                                      '--',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ]
                                  : cats
                                      .take(2)
                                      .map(
                                        (c) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            c,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: const Color(0xFF475569),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                        ),
                      ),
                    ),

                    // 3. Phone
                    DataCell(
                      Text(
                        user.phone != null ? '${user.phone}' : '--',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),

                    // 4. City / Address
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          user.city ??
                              user.businessaddress ??
                              user.address ??
                              '--',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // 5. Registered Date
                    DataCell(
                      Text(
                        user.createdAt != null
                            ? dateFormat.format(user.createdAt!)
                            : '--',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // 6. Action: View Profile
                    DataCell(
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_rounded,
                          size: 20,
                          color: Color(0xFF0284C7),
                        ),
                        tooltip: 'View Profile',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => BusinessProfilePage(
                                    businessData: user.toMap(),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCardsList(CategoryProvidersPaginationState state) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: state.providers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final UserModel user = state.providers[index];

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (_) => BusinessProfilePage(businessData: user.toMap()),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child:
                          user.businesspic != null &&
                                  user.businesspic!.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl: user.businesspic!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget:
                                    (_, __, ___) => Container(
                                      width: 44,
                                      height: 44,
                                      color: const Color(0xFFE2E8F0),
                                      child: const Icon(
                                        Icons.business_rounded,
                                        size: 20,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                              )
                              : Container(
                                width: 44,
                                height: 44,
                                color: const Color(0xFFE2E8F0),
                                child: const Icon(
                                  Icons.business_rounded,
                                  size: 20,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.businessname?.trim().isNotEmpty == true
                                ? user.businessname!
                                : user.displayName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            user.phone != null ? '${user.phone}' : '--',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF0284C7),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        user.city ?? user.businessaddress ?? '--',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    if (user.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(user.createdAt!),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Helper function to match categories to meaningful Material icons
IconData _getCategoryIcon(String category) {
  final lower = category.toLowerCase();
  if (lower.contains('clean')) return Icons.cleaning_services_rounded;
  if (lower.contains('electr')) return Icons.electrical_services_rounded;
  if (lower.contains('plumb')) return Icons.plumbing_rounded;
  if (lower.contains('ac') || lower.contains('air')) {
    return Icons.ac_unit_rounded;
  }
  if (lower.contains('paint')) return Icons.format_paint_rounded;
  if (lower.contains('carpent') || lower.contains('wood')) {
    return Icons.carpenter_rounded;
  }
  if (lower.contains('mover') || lower.contains('packer')) {
    return Icons.local_shipping_rounded;
  }
  if (lower.contains('appliance') ||
      lower.contains('repair') ||
      lower.contains('fridge') ||
      lower.contains('tv') ||
      lower.contains('wash')) {
    return Icons.home_repair_service_rounded;
  }
  if (lower.contains('pest')) return Icons.pest_control_rounded;
  if (lower.contains('cctv') || lower.contains('secur')) {
    return Icons.videocam_rounded;
  }
  if (lower.contains('design') || lower.contains('interior')) {
    return Icons.design_services_rounded;
  }
  if (lower.contains('tile') || lower.contains('ceiling')) {
    return Icons.grid_view_rounded;
  }
  if (lower.contains('wedding') ||
      lower.contains('event') ||
      lower.contains('cater') ||
      lower.contains('photo') ||
      lower.contains('makeup') ||
      lower.contains('beauty')) {
    return Icons.celebration_rounded;
  }
  if (lower.contains('mechanic') ||
      lower.contains('driver') ||
      lower.contains('car') ||
      lower.contains('bike') ||
      lower.contains('auto')) {
    return Icons.directions_car_rounded;
  }
  if (lower.contains('build') ||
      lower.contains('contract') ||
      lower.contains('weld')) {
    return Icons.construction_rounded;
  }
  if (lower.contains('medic') ||
      lower.contains('ambulan') ||
      lower.contains('health')) {
    return Icons.medical_services_rounded;
  }
  return Icons.handyman_rounded;
}

/// ---------------------------------------------------------------------------
/// EMPTY SLOTS VIEW: Tab displaying categories with vacant Star Service Provider slots (< 4).
/// ---------------------------------------------------------------------------
class _EmptySlotsView extends ConsumerStatefulWidget {
  const _EmptySlotsView({super.key});

  @override
  ConsumerState<_EmptySlotsView> createState() => _EmptySlotsViewState();
}

class _EmptySlotsViewState extends ConsumerState<_EmptySlotsView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _cityScrollController = ScrollController();
  final ScrollController _zoneScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  bool _hasSearchText = false;
  bool _isTableView = false;

  @override
  void initState() {
    super.initState();
    // Intelligent auto-population:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentCity = ref.read(emptySlotsSelectedCityProvider);
      if (currentCity != null && currentCity.isNotEmpty) return;

      final isSuper = ref.read(isSuperAdminProvider);
      final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
      final overviewCity = ref.read(serviceProvidersSelectedCityProvider);

      if (!isSuper && assignedCities.isNotEmpty) {
        ref.read(emptySlotsSelectedCityProvider.notifier).state =
            assignedCities.first;
      } else if (overviewCity != null &&
          overviewCity.isNotEmpty &&
          overviewCity != 'All' &&
          overviewCity != 'All Cities') {
        ref.read(emptySlotsSelectedCityProvider.notifier).state = overviewCity;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityScrollController.dispose();
    _zoneScrollController.dispose();
    _categoryScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCity = ref.watch(emptySlotsSelectedCityProvider);
    final selectedZone = ref.watch(emptySlotsSelectedZoneProvider);
    final allowedCitiesAsync = ref.watch(allowedCitiesProvider);
    final isSuper = ref.watch(isSuperAdminProvider);
    final assignedCities = ref.watch(currentAdminAssignedCitiesProvider);
    final emptySlotsAsync = ref.watch(emptySlotsDataProvider);
    final filteredCategories = ref.watch(emptySlotsFilteredCategoriesProvider);
    final searchQuery = ref.watch(emptySlotsCategorySearchProvider);
    final activeCategoryFilter = ref.watch(emptySlotsSelectedCategoryFilterProvider);

    final isHyderabad = isCityHyderabad(selectedCity);
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final cityDisplay = selectedCity ??
        (!isSuper && assignedCities.isNotEmpty
            ? assignedCities.join(', ')
            : 'Select City');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 16 : 28,
          isMobile ? 32 : 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header matching Star Service Providers design
            _buildEmptySlotsHeader(
              context,
              ref,
              cityDisplay: cityDisplay,
              selectedZone: selectedZone,
              emptySlotsAsync: emptySlotsAsync,
            ),
            const SizedBox(height: 20),

            // City Selection & Search Bar Card (with horizontally scrollable cities bar)
            _buildCityAndSearchCard(
              context,
              ref,
              selectedCity: selectedCity,
              isSuper: isSuper,
              assignedCities: assignedCities,
              allowedCitiesAsync: allowedCitiesAsync,
            ),

            // Zone Filter Bar — only for Hyderabad (identical to Star Service Providers)
            if (isHyderabad) ...[
              const SizedBox(height: 14),
              _buildZoneFilterBar(
                ref,
                selectedZone: selectedZone,
                scrollController: _zoneScrollController,
              ),
            ],
            const SizedBox(height: 20),

            // Content Area: Prompt, Loading, Error, or Category Slots
            if (selectedCity == null ||
                selectedCity.trim().isEmpty ||
                selectedCity == 'All' ||
                selectedCity == 'All Cities')
              _buildCityPromptCard()
            else
              emptySlotsAsync.when(
                data: (items) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Horizontal Category Quick Bar matching Star Service Providers design
                      _buildHorizontalCategoryBar(
                        ref,
                        allItems: items,
                        activeFilter: activeCategoryFilter,
                        scrollController: _categoryScrollController,
                      ),
                      const SizedBox(height: 20),

                      // Category Overview Header with View Mode Switcher
                      _buildCategorySectionHeader(
                        displayCount: filteredCategories.length,
                        totalCount: items.length,
                      ),
                      const SizedBox(height: 14),

                      // Category Content: Chess Grid (Default) or Table View
                      if (filteredCategories.isEmpty)
                        _buildEmptyState(
                          isSearch: searchQuery.isNotEmpty || activeCategoryFilter != null,
                          searchQuery: searchQuery.isNotEmpty ? searchQuery : activeCategoryFilter ?? '',
                          city: selectedCity,
                        )
                      else if (_isTableView)
                        isMobile
                            ? _buildMobileCategoryList(
                                filteredCategories,
                                selectedCity: selectedCity,
                                selectedZone: selectedZone,
                              )
                            : _buildDesktopTable(
                                filteredCategories,
                                selectedCity: selectedCity,
                                selectedZone: selectedZone,
                              )
                      else
                        _buildCategoryGrid(
                          context,
                          ref,
                          categories: filteredCategories,
                          selectedCity: selectedCity,
                          selectedZone: selectedZone,
                        ),
                    ],
                  );
                },
                loading: () => _buildLoadingSlots(selectedCity),
                error: (err, _) => _buildErrorState(ref, err.toString()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlotsHeader(
    BuildContext context,
    WidgetRef ref, {
    required String cityDisplay,
    required ServiceProviderAreaGroup? selectedZone,
    required AsyncValue<List<EmptySlotCategoryItem>> emptySlotsAsync,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final refreshBtn = IconButton(
      onPressed: () => ref.invalidate(emptySlotsDataProvider),
      icon: const Icon(
        Icons.refresh_rounded,
        color: Colors.white70,
      ),
      tooltip: 'Refresh Empty Slots',
    );

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'SERVICE PROVIDERS',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  _buildEntityTabSwitcher(
                    ref,
                    activeTab: StarServiceProvidersTab.emptySlots,
                  ),
                ],
              ),
            ),
            if (isMobile) refreshBtn,
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.location_on_rounded,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                cityDisplay == 'Select City'
                    ? 'Select a city below to view vacant categories'
                    : selectedZone != null
                        ? 'Viewing Empty Slots in $cityDisplay (${selectedZone.displayName})'
                        : 'Viewing Empty Slots in $cityDisplay',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFFE2E8F0),
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );

    final statsSection = emptySlotsAsync.maybeWhen(
      data: (items) {
        final totalEmptySlots = items.fold<int>(
          0,
          (sum, item) => sum + item.availableSlots,
        );
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildStatChip(
              label: 'Vacant Categories',
              value: '${items.length}',
              color: const Color(0xFF38BDF8),
            ),
            _buildStatChip(
              label: 'Available Slots',
              value: '$totalEmptySlots',
              color: const Color(0xFF34D399),
            ),
            if (!isMobile) refreshBtn,
          ],
        );
      },
      orElse: () => isMobile ? const SizedBox.shrink() : refreshBtn,
    );

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 720) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleBlock,
                const SizedBox(height: 14),
                statsSection,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleBlock),
              const SizedBox(width: 16),
              statsSection,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityAndSearchCard(
    BuildContext context,
    WidgetRef ref, {
    required String? selectedCity,
    required bool isSuper,
    required List<String> assignedCities,
    required AsyncValue<List<String>> allowedCitiesAsync,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        //   Wrap(
        //     spacing: 16,
        //     runSpacing: 14,
        //     crossAxisAlignment: WrapCrossAlignment.center,
        //     children: [
        //       // 1. City Dropdown Selector
        //       ConstrainedBox(
        //         constraints: const BoxConstraints(minWidth: 220, maxWidth: 300),
        //         child: allowedCitiesAsync.when(
        //           data: (cities) {
        //             final validCities = cities.toSet().toList()..sort();
        //             final currentValue = (selectedCity != null && validCities.contains(selectedCity))
        //                 ? selectedCity
        //                 : null;

        //             return DropdownButtonFormField<String?>(
        //               key: ValueKey('empty_slots_city_dropdown_${currentValue ?? "none"}'),
        //               initialValue: currentValue,
        //               isDense: true,
        //               isExpanded: true,
        //               decoration: InputDecoration(
        //                 labelText: 'Select City',
        //                 hintText: 'Choose a city...',
        //                 prefixIcon: const Icon(
        //                   Icons.location_city_rounded,
        //                   color: Color(0xFF0284C7),
        //                   size: 20,
        //                 ),
        //                 contentPadding: const EdgeInsets.symmetric(
        //                   horizontal: 14,
        //                   vertical: 12,
        //                 ),
        //                 border: OutlineInputBorder(
        //                   borderRadius: BorderRadius.circular(10),
        //                   borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        //                 ),
        //                 enabledBorder: OutlineInputBorder(
        //                   borderRadius: BorderRadius.circular(10),
        //                   borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        //                 ),
        //                 focusedBorder: OutlineInputBorder(
        //                   borderRadius: BorderRadius.circular(10),
        //                   borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        //                 ),
        //               ),
        //               items: validCities.map((c) {
        //                 return DropdownMenuItem<String?>(
        //                   value: c,
        //                   child: Text(
        //                     c,
        //                     style: GoogleFonts.poppins(
        //                       fontSize: 13,
        //                       fontWeight: FontWeight.w600,
        //                       color: const Color(0xFF1E293B),
        //                     ),
        //                   ),
        //                 );
        //               }).toList(),
        //               onChanged: (newCity) {
        //                 if (newCity != null) {
        //                   if (selectedCity != newCity) {
        //                     ref.read(emptySlotsSelectedZoneProvider.notifier).state = null;
        //                   }
        //                   ref.read(emptySlotsSelectedCityProvider.notifier).state = newCity;
        //                 }
        //               },
        //             );
        //           },
        //           loading: () => Container(
        //             height: 48,
        //             padding: const EdgeInsets.symmetric(horizontal: 14),
        //             alignment: Alignment.centerLeft,
        //             decoration: BoxDecoration(
        //               color: const Color(0xFFF8FAFC),
        //               borderRadius: BorderRadius.circular(10),
        //               border: Border.all(color: const Color(0xFFE2E8F0)),
        //             ),
        //             child: Text(
        //               'Loading cities...',
        //               style: GoogleFonts.poppins(
        //                 fontSize: 12,
        //                 color: const Color(0xFF94A3B8),
        //               ),
        //             ),
        //           ),
        //           error: (_, __) => Container(
        //             height: 48,
        //             padding: const EdgeInsets.symmetric(horizontal: 14),
        //             alignment: Alignment.centerLeft,
        //             decoration: BoxDecoration(
        //               color: const Color(0xFFFEF2F2),
        //               borderRadius: BorderRadius.circular(10),
        //               border: Border.all(color: const Color(0xFFFECACA)),
        //             ),
        //             child: Text(
        //               'Error loading cities',
        //               style: GoogleFonts.poppins(
        //                 fontSize: 12,
        //                 color: const Color(0xFFDC2626),
        //               ),
        //             ),
        //           ),
        //         ),
        //       ),

        //       // 2. Category Search Field
        //       ConstrainedBox(
        //         constraints: const BoxConstraints(minWidth: 260, maxWidth: 360),
        //         child: SizedBox(
        //           height: 48,
        //           child: TextField(
        //             controller: _searchController,
        //             onChanged: (value) {
        //               final hasText = value.isNotEmpty;
        //               if (_hasSearchText != hasText) {
        //                 setState(() {
        //                   _hasSearchText = hasText;
        //                 });
        //               }
        //               ref.read(emptySlotsCategorySearchProvider.notifier).state = value;
        //             },
        //             style: GoogleFonts.poppins(fontSize: 13),
        //             decoration: InputDecoration(
        //               hintText: 'Filter categories (e.g. Electrician, AC...)',
        //               hintStyle: GoogleFonts.poppins(
        //                 fontSize: 12.5,
        //                 color: const Color(0xFF94A3B8),
        //               ),
        //               prefixIcon: const Icon(
        //                 Icons.search_rounded,
        //                 color: Color(0xFF94A3B8),
        //                 size: 20,
        //               ),
        //               suffixIcon: _hasSearchText
        //                   ? IconButton(
        //                       icon: const Icon(
        //                         Icons.clear_rounded,
        //                         color: Color(0xFF94A3B8),
        //                         size: 18,
        //                       ),
        //                       onPressed: () {
        //                         _searchController.clear();
        //                         setState(() {
        //                           _hasSearchText = false;
        //                         });
        //                         ref.read(emptySlotsCategorySearchProvider.notifier).state = '';
        //                       },
        //                     )
        //                   : null,
        //               contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        //               border: OutlineInputBorder(
        //                 borderRadius: BorderRadius.circular(10),
        //                 borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        //               ),
        //               enabledBorder: OutlineInputBorder(
        //                 borderRadius: BorderRadius.circular(10),
        //                 borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        //               ),
        //               focusedBorder: OutlineInputBorder(
        //                 borderRadius: BorderRadius.circular(10),
        //                 borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
        //               ),
        //             ),
        //           ),
        //         ),
        //       ),
        //     ],
        //   ),

        //   // Quick City Pills bar below dropdown for fast 1-click access (horizontally scrollable)
          allowedCitiesAsync.when(
            data: (cities) {
              final uniqueCities = cities.toSet().toList()..sort();
              if (uniqueCities.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SizedBox(
                  width: double.infinity,
                  // Extra 18px below pills for the scrollbar track
                  height: 60,
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        if (!_cityScrollController.hasClients) return;
                        final delta = event.scrollDelta.dy;
                        final newOffset = (_cityScrollController.offset + delta).clamp(
                          _cityScrollController.position.minScrollExtent,
                          _cityScrollController.position.maxScrollExtent,
                        );
                        _cityScrollController.jumpTo(newOffset);
                      }
                    },
                    child: Scrollbar(
                      controller: _cityScrollController,
                      thumbVisibility: true,
                      notificationPredicate: (n) => n.depth == 0,
                      child: SingleChildScrollView(
                        controller: _cityScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        // Bottom padding reserves space for the scrollbar track
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...uniqueCities.map(
                              (city) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildCityPill(
                                  label: city,
                                  isSelected: selectedCity?.toLowerCase() == city.toLowerCase(),
                                  onTap: () {
                                    if (selectedCity != city) {
                                      ref.read(emptySlotsSelectedZoneProvider.notifier).state = null;
                                    }
                                    ref.read(emptySlotsSelectedCityProvider.notifier).state = city;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const SizedBox(
              height: 42,
              width: 120,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 12),
          // Info Notice Banner
    //       Container(
    //         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    //         decoration: BoxDecoration(
    //           color: const Color(0xFFF0F9FF),
    //           borderRadius: BorderRadius.circular(8),
    //           border: Border.all(color: const Color(0xFFBAE6FD)),
    //         ),
    //         child: Row(
    //           children: [
    //             const Icon(
    //               Icons.info_outline_rounded,
    //               size: 16,
    //               color: Color(0xFF0284C7),
    //             ),
    //             // const SizedBox(width: 8),
    //             // Expanded(
    //             //   child: Text(
    //             //     'Each category allows a maximum of 4 Star Service Providers. Available Slots = 4 - eligible existing Star Providers. Only categories with available slots > 0 are displayed.',
    //             //     style: GoogleFonts.poppins(
    //             //       fontSize: 11.5,
    //             //       fontWeight: FontWeight.w500,
    //             //       color: const Color(0xFF0369A1),
    //             //     ),
    //             //   ),
    //             // ),
    //           ],
    //         ),
    //       ),
        ],
      ),
    );
  }

  Widget _buildCityPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  /// Builds the Hyderabad Zone filter bar for Empty Slots.
  /// Shown only when City = Hyderabad.
  /// Selecting a zone pre-filters providers by exact pincode before category aggregation.
  Widget _buildZoneFilterBar(
    WidgetRef ref, {
    required ServiceProviderAreaGroup? selectedZone,
    required ScrollController scrollController,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_searching_rounded,
                size: 14,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                'Zone',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
              if (selectedZone != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selectedZone.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Listener(
              onPointerSignal: (event) {
                if (event is PointerScrollEvent) {
                  if (!scrollController.hasClients) return;
                  final delta = event.scrollDelta.dy;
                  final newOffset = (scrollController.offset + delta).clamp(
                    scrollController.position.minScrollExtent,
                    scrollController.position.maxScrollExtent,
                  );
                  scrollController.jumpTo(newOffset);
                }
              },
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                notificationPredicate: (n) => n.depth == 0,
                child: SingleChildScrollView(
                  controller: scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // All Zones pill
                      _buildZonePill(
                        label: 'All Zones',
                        isSelected: selectedZone == null,
                        onTap: () {
                          ref
                              .read(
                                emptySlotsSelectedZoneProvider.notifier,
                              )
                              .state = null;
                        },
                      ),
                      const SizedBox(width: 8),
                      // Individual zone pills
                      ...kHyderabadAreaGroups.map((zone) {
                        final isSelected =
                            selectedZone?.displayName == zone.displayName;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildZonePill(
                            label: zone.displayName,
                            isSelected: isSelected,
                            onTap: () {
                              ref
                                  .read(
                                    emptySlotsSelectedZoneProvider
                                        .notifier,
                                  )
                                  .state = isSelected ? null : zone;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZonePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFF059669)
                  : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF059669)
                    : const Color(0xFFCBD5E1),
          ),
          boxShadow:
              isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF059669).withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildCityPromptCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F9FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_city_rounded,
              size: 42,
              color: Color(0xFF0284C7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Please select a city',
            style: GoogleFonts.poppins(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              'Choose a city from the dropdown above to view category slot availability and vacant opportunities for the sales team.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSlots(String city) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: Color(0xFF0284C7),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Calculating available slots for $city...',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WidgetRef ref, String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            'Error loading slot availability',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(emptySlotsDataProvider),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required bool isSearch,
    required String searchQuery,
    required String city,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Icon(
            isSearch ? Icons.search_off_rounded : Icons.check_circle_outline_rounded,
            size: 44,
            color: isSearch ? const Color(0xFF94A3B8) : const Color(0xFF059669),
          ),
          const SizedBox(height: 14),
          Text(
            isSearch
                ? 'No categories match "$searchQuery"'
                : 'All Star Provider slots in $city are full!',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isSearch
                ? 'Try searching with a different category name.'
                : 'All categories in $city currently have the maximum 4 Star Service Providers assigned.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable(
    List<EmptySlotCategoryItem> items, {
    required String selectedCity,
    required ServiceProviderAreaGroup? selectedZone,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 850),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dataRowMaxHeight: 64,
              columnSpacing: 24,
              horizontalMargin: 20,
              columns: const [
                DataColumn(label: Text('S.No')),
                DataColumn(label: Text('Category')),
                DataColumn(label: Text('Occupied Slots')),
                DataColumn(label: Text('Available Slots')),
                DataColumn(label: Text('Slot Capacity')),
                DataColumn(label: Text('Action')),
              ],
              rows: List.generate(items.length, (index) {
                final item = items[index];
                final sn = index + 1;

                return DataRow(
                  cells: [
                    // 1. S.No
                    DataCell(
                      Text(
                        '$sn',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // 2. Category
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _getCategoryIcon(item.categoryName),
                              size: 18,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            item.categoryName,
                            style: GoogleFonts.poppins(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 3. Occupied Slots
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${item.occupiedSlots} / ${item.totalSlots}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),

                    // 4. Available Slots
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Color(0xFF059669),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.availableSlots} Available',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Slot Capacity Indicator
                    DataCell(
                      _buildSlotCapacityIndicator(
                        occupied: item.occupiedSlots,
                        total: item.totalSlots,
                      ),
                    ),

                    // 6. Action
                    DataCell(
                      ElevatedButton.icon(
                        onPressed: () {
                          // Drilldown to this category on Star Providers view
                          ref.read(serviceProvidersSelectedCityProvider.notifier).state =
                              selectedCity;
                          ref.read(serviceProvidersSelectedZoneProvider.notifier).state =
                              selectedZone;
                          ref.read(serviceProvidersDrilldownCategoryProvider.notifier).state =
                              item.categoryName;
                          ref.read(starServiceProvidersActiveTabProvider.notifier).state =
                              StarServiceProvidersTab.starProviders;
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: Text(
                          'View Providers',
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0284C7),
                          side: const BorderSide(color: Color(0xFFBAE6FD)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSlotCapacityIndicator({required int occupied, required int total}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final isOccupied = i < occupied;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isOccupied ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
            border: Border.all(
              color: isOccupied ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          child: isOccupied
              ? const Icon(Icons.star_rounded, size: 8, color: Colors.white)
              : null,
        );
      }),
    );
  }

  Widget _buildMobileCategoryList(
    List<EmptySlotCategoryItem> items, {
    required String selectedCity,
    required ServiceProviderAreaGroup? selectedZone,
  }) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(item.categoryName),
                      size: 16,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.categoryName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '${item.availableSlots} Slots',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Capacity: ',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      _buildSlotCapacityIndicator(
                        occupied: item.occupiedSlots,
                        total: item.totalSlots,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${item.occupiedSlots}/4)',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      ref.read(serviceProvidersSelectedCityProvider.notifier).state =
                          selectedCity;
                      ref.read(serviceProvidersSelectedZoneProvider.notifier).state =
                          selectedZone;
                      ref.read(serviceProvidersDrilldownCategoryProvider.notifier).state =
                          item.categoryName;
                      ref.read(starServiceProvidersActiveTabProvider.notifier).state =
                          StarServiceProvidersTab.starProviders;
                    },
                    child: Text(
                      'View Providers →',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontalCategoryBar(
    WidgetRef ref, {
    required List<EmptySlotCategoryItem> allItems,
    required String? activeFilter,
    required ScrollController scrollController,
  }) {
    if (allItems.isEmpty) return const SizedBox.shrink();

    final totalAvailableSlots = allItems.fold<int>(
      0,
      (sum, item) => sum + item.availableSlots,
    );

    return SizedBox(
      width: double.infinity,
      // Extra 18px below pills for the scrollbar track
      height: 60,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            if (!scrollController.hasClients) return;
            final delta = event.scrollDelta.dy;
            final newOffset = (scrollController.offset + delta).clamp(
              scrollController.position.minScrollExtent,
              scrollController.position.maxScrollExtent,
            );
            scrollController.jumpTo(newOffset);
          }
        },
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: true,
          notificationPredicate: (n) => n.depth == 0,
          child: SingleChildScrollView(
            controller: scrollController,
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "All" Filter Button
                _buildCategoryPill(
                  label: 'All ($totalAvailableSlots Slots)',
                  isSelected: activeFilter == null,
                  onTap: () {
                    ref.read(emptySlotsSelectedCategoryFilterProvider.notifier).state = null;
                  },
                ),
                const SizedBox(width: 8),
                ...allItems.map((cat) {
                  final isSelected = activeFilter == cat.categoryName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildCategoryPill(
                      label: '${cat.categoryName} (${cat.availableSlots})',
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(emptySlotsSelectedCategoryFilterProvider.notifier).state =
                            isSelected ? null : cat.categoryName;
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySectionHeader({
    required int displayCount,
    required int totalCount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'CATEGORY OVERVIEW',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$displayCount of $totalCount Categories Vacant',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    key: const ValueKey('empty_slots_view_mode_grid'),
                    onTap: () {
                      if (_isTableView) setState(() => _isTableView = false);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: !_isTableView ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: !_isTableView
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.grid_view_rounded,
                            size: 14,
                            color: !_isTableView ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Grid',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: !_isTableView ? FontWeight.w700 : FontWeight.w500,
                              color: !_isTableView ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    key: const ValueKey('empty_slots_view_mode_table'),
                    onTap: () {
                      if (!_isTableView) setState(() => _isTableView = true);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isTableView ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _isTableView
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.table_chart_rounded,
                            size: 14,
                            color: _isTableView ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Table',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight: _isTableView ? FontWeight.w700 : FontWeight.w500,
                              color: _isTableView ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Click any card to view provider list',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryGrid(
    BuildContext context,
    WidgetRef ref, {
    required List<EmptySlotCategoryItem> categories,
    required String selectedCity,
    required ServiceProviderAreaGroup? selectedZone,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount;
        final double childAspectRatio;

        if (w < 480) {
          crossAxisCount = 1;
          childAspectRatio = 2.15;
        } else if (w < 800) {
          crossAxisCount = 2;
          childAspectRatio = 1.35;
        } else if (w < 1100) {
          crossAxisCount = 3;
          childAspectRatio = 1.45;
        } else if (w < 1400) {
          crossAxisCount = 4;
          childAspectRatio = 1.35;
        } else {
          crossAxisCount = 5;
          childAspectRatio = 1.30;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final item = categories[index];
            return _EmptySlotCategoryCard(
              key: ValueKey('empty_slot_card_${item.categoryName}'),
              item: item,
              onTap: () {
                // Drill down into category providers on Star Providers tab
                ref.read(serviceProvidersSelectedCityProvider.notifier).state = selectedCity;
                ref.read(serviceProvidersSelectedZoneProvider.notifier).state = selectedZone;
                ref.read(serviceProvidersDrilldownCategoryProvider.notifier).state = item.categoryName;
                ref.read(starServiceProvidersActiveTabProvider.notifier).state = StarServiceProvidersTab.starProviders;
              },
            );
          },
        );
      },
    );
  }
}

/// Category overview card for Empty Slots matching the exact design and interaction of _CategoryOverviewCard
class _EmptySlotCategoryCard extends StatefulWidget {
  final EmptySlotCategoryItem item;
  final VoidCallback onTap;

  const _EmptySlotCategoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  State<_EmptySlotCategoryCard> createState() => _EmptySlotCategoryCardState();
}

class _EmptySlotCategoryCardState extends State<_EmptySlotCategoryCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _isHovered
              ? Matrix4.translationValues(0, -3, 0)
              : Matrix4.identity(),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _isHovered
                  ? const Color(0xFF0284C7)
                  : const Color(0xFFE2E8F0),
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                    : const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: _isHovered ? 14 : 8,
                offset: Offset(0, _isHovered ? 6 : 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Row: Category Name + Icon (matching _CategoryOverviewCard)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.categoryName.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getCategoryIcon(item.categoryName),
                      color: const Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                ],
              ),

              // Middle: Large Available Count + Slots Available Label
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${item.availableSlots}',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF059669),
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.availableSlots == 1 ? 'Slot Available' : 'Slots Available',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),

              // Slot dots indicator + occupied count badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(item.totalSlots, (i) {
                      final isOccupied = i < item.occupiedSlots;
                      return Container(
                        margin: const EdgeInsets.only(right: 3),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOccupied
                              ? const Color(0xFF0284C7)
                              : const Color(0xFFF1F5F9),
                          border: Border.all(
                            color: isOccupied
                                ? const Color(0xFF0284C7)
                                : const Color(0xFFCBD5E1),
                            width: 1.2,
                          ),
                        ),
                        child: isOccupied
                            ? const Icon(
                                Icons.star_rounded,
                                size: 8,
                                color: Colors.white,
                              )
                            : null,
                      );
                    }),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${item.occupiedSlots}/${item.totalSlots} filled',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom: View Providers link & arrow (exact same as Star Providers)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'View Providers',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _isHovered
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: _isHovered
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
