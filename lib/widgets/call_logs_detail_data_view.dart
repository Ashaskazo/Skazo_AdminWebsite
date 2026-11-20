import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/constants/business_categories.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/models/call_logs_detail_item.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/call_logs_detail_provider.dart';
import 'package:skazo_admin/repositories/call_logs_detail_repository.dart';
import 'package:skazo_admin/utils/responsive.dart';

/// Root data view for the Call Logs Details entity.
/// Displays call logs city-wise and category-wise with consistent UI,
/// filtering, search, pagination, and strict city-wise authorization.
class CallLogsDetailDataView extends ConsumerStatefulWidget {
  const CallLogsDetailDataView({super.key});

  @override
  ConsumerState<CallLogsDetailDataView> createState() => _CallLogsDetailDataViewState();
}

class _CallLogsDetailDataViewState extends ConsumerState<CallLogsDetailDataView> {
  final ScrollController _cityScrollController = ScrollController();
  final ScrollController _zoneScrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearchText = false;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(callLogsDetailSearchQueryProvider);
    _searchController.text = initialQuery;
    _hasSearchText = initialQuery.isNotEmpty;
  }

  @override
  void dispose() {
    _cityScrollController.dispose();
    _zoneScrollController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawDataAsync = ref.watch(callLogsDetailRawDataProvider);
    final summaryStats = ref.watch(callLogsDetailSummaryStatsProvider);
    final pagination = ref.watch(callLogsDetailPaginationProvider);
    final selectedCity = ref.watch(callLogsDetailSelectedCityProvider);
    final selectedZone = ref.watch(callLogsDetailSelectedZoneProvider);
    final selectedCategory = ref.watch(callLogsDetailSelectedCategoryProvider);
    final dateOption = ref.watch(callLogsDetailDateOptionProvider);
    final customDateRange = ref.watch(callLogsDetailCustomDateRangeProvider);
    final selectedFeedback = ref.watch(callLogsDetailFeedbackStatusFilterProvider);
    final allowedCitiesAsync = ref.watch(allowedCitiesProvider);
    final isSuper = ref.watch(isSuperAdminProvider);
    final assignedCities = ref.watch(currentAdminAssignedCitiesProvider);

    final isHyderabad = isCityHyderabad(selectedCity);

    final cityDisplay = selectedCity ??
        (!isSuper && assignedCities.isNotEmpty ? assignedCities.join(', ') : 'All Cities');

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
            // 1. Top Header Banner & Summary Stats
            _buildTopHeader(
              context,
              ref,
              cityDisplay: cityDisplay,
              summaryStats: summaryStats,
              rawDataAsync: rawDataAsync,
              filteredCount: pagination.totalItems,
            ),
            const SizedBox(height: 20),

            // 2. City Filter Bar (Horizontally Scrollable)
            _buildCityFilterBar(
              ref,
              selectedCity: selectedCity,
              isSuper: isSuper,
              assignedCities: assignedCities,
              allowedCitiesAsync: allowedCitiesAsync,
              scrollController: _cityScrollController,
            ),
            const SizedBox(height: 16),

            // Zone Filter Bar — shown ONLY for Hyderabad (consistent with Star Service Providers)
            if (isHyderabad) ...[
              _buildZoneFilterBar(
                ref,
                selectedZone: selectedZone,
                scrollController: _zoneScrollController,
              ),
              const SizedBox(height: 16),
            ],

            // 3. Horizontal Category Quick-Bar
            _buildHorizontalCategoryBar(
              ref,
              summaryStats: summaryStats,
              selectedCategory: selectedCategory,
              scrollController: _categoryScrollController,
            ),
            const SizedBox(height: 16),

            // 4. Secondary Filters & Date Filter Row
            _buildSecondaryFilterRow(
              context,
              ref,
              selectedCity: selectedCity,
              selectedZone: selectedZone,
              selectedCategory: selectedCategory,
              dateOption: dateOption,
              customDateRange: customDateRange,
              selectedFeedback: selectedFeedback,
              summaryStats: summaryStats,
            ),
            const SizedBox(height: 16),

            // 5. Search Bar
            _buildSearchBar(ref),
            const SizedBox(height: 20),

            // 6. Data Content (Loading / Error / Empty / Table / Mobile Cards)
            _buildDataContent(
              context,
              ref,
              rawDataAsync: rawDataAsync,
              pagination: pagination,
              cityDisplay: cityDisplay,
              selectedCategory: selectedCategory,
            ),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// 1. TOP HEADER BANNER
  /// ---------------------------------------------------------------------------
  Widget _buildTopHeader(
    BuildContext context,
    WidgetRef ref, {
    required String cityDisplay,
    required CallLogsDetailSummaryStats summaryStats,
    required AsyncValue<List<CallLogsDetailItem>> rawDataAsync,
    required int filteredCount,
  }) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final refreshBtn = IconButton(
      onPressed: () => ref.invalidate(callLogsDetailRawDataProvider),
      icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
      tooltip: 'Refresh Call Logs',
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
                Icons.phone_in_talk_rounded,
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
                    'CALL LOGS DETAILS',
                    style: GoogleFonts.poppins(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'CITY & CATEGORY WISE',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
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

    final statsSection = rawDataAsync.maybeWhen(
      data: (_) => Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildHeaderStatChip(
            label: 'Total Calls',
            value: '${summaryStats.totalCalls}',
            color: const Color(0xFF38BDF8),
          ),
          _buildHeaderStatChip(
            label: 'Today Calls',
            value: '${summaryStats.todayCalls}',
            color: const Color(0xFF34D399),
          ),
          _buildHeaderStatChip(
            label: 'Filtered',
            value: '$filteredCount',
            color: const Color(0xFFA78BFA),
          ),
          _buildHeaderStatChip(
            label: 'Converted',
            value: '${summaryStats.convertedCalls}',
            color: const Color(0xFFFBBF24),
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

  /// ---------------------------------------------------------------------------
  /// 2. CITY FILTER BAR
  /// ---------------------------------------------------------------------------
  Widget _buildCityFilterBar(
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
          Row(
            children: [
              const Icon(
                Icons.location_city_rounded,
                size: 15,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 6),
              Text(
                'City:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          allowedCitiesAsync.when(
            data: (cities) {
              final uniqueCities = cities.toSet().toList()..sort();

              return SizedBox(
                width: double.infinity,
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
                          // All Cities / My Cities pill
                          _buildCityPill(
                            label: (!isSuper && assignedCities.isNotEmpty) ? 'My Cities' : 'All Cities',
                            isSelected: selectedCity == null,
                            onTap: () {
                              ref.read(callLogsDetailSelectedCityProvider.notifier).state = null;
                              ref.read(callLogsDetailSelectedZoneProvider.notifier).state = null;
                              ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
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
                                  ref.read(callLogsDetailSelectedCityProvider.notifier).state = city;
                                  if (selectedCity != city) {
                                    ref.read(callLogsDetailSelectedZoneProvider.notifier).state = null;
                                  }
                                  ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
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
            loading: () => const SizedBox(
              height: 42,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
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

  /// ---------------------------------------------------------------------------
  /// HYDERABAD ZONE FILTER BAR (Shown only when City = Hyderabad)
  /// Reuses exact visual design, zones, and behavior from Star Service Providers.
  /// ---------------------------------------------------------------------------
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
                              .read(callLogsDetailSelectedZoneProvider.notifier)
                              .state = null;
                          ref
                              .read(callLogsDetailCurrentPageProvider.notifier)
                              .state = 0;
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
                                    callLogsDetailSelectedZoneProvider.notifier,
                                  )
                                  .state = isSelected ? null : zone;
                              ref
                                  .read(
                                    callLogsDetailCurrentPageProvider.notifier,
                                  )
                                  .state = 0;
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

  /// ---------------------------------------------------------------------------
  /// 3. HORIZONTAL CATEGORY QUICK-BAR
  /// ---------------------------------------------------------------------------
  Widget _buildHorizontalCategoryBar(
    WidgetRef ref, {
    required CallLogsDetailSummaryStats summaryStats,
    required String? selectedCategory,
    required ScrollController scrollController,
  }) {
    final catCounts = summaryStats.categoryCounts;
    if (catCounts.isEmpty) return const SizedBox.shrink();

    final sortedCategories = catCounts.keys.toList()..sort();

    return SizedBox(
      width: double.infinity,
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
                // "All" Category Pill
                _buildCategoryPill(
                  label: 'All (${summaryStats.totalCalls})',
                  isSelected: selectedCategory == null || selectedCategory == 'All',
                  onTap: () {
                    ref.read(callLogsDetailSelectedCategoryProvider.notifier).state = null;
                    ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
                  },
                ),
                const SizedBox(width: 8),

                // Individual Category Pills
                ...sortedCategories.map((cat) {
                  final isSelected = selectedCategory == cat;
                  final count = catCounts[cat] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildCategoryPill(
                      label: '$cat ($count)',
                      isSelected: isSelected,
                      onTap: () {
                        ref.read(callLogsDetailSelectedCategoryProvider.notifier).state =
                            isSelected ? null : cat;
                        ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
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
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
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

  /// ---------------------------------------------------------------------------
  /// 4. SECONDARY FILTERS & DATE FILTER ROW
  /// ---------------------------------------------------------------------------
  Widget _buildSecondaryFilterRow(
    BuildContext context,
    WidgetRef ref, {
    required String? selectedCity,
    required ServiceProviderAreaGroup? selectedZone,
    required String? selectedCategory,
    required CallLogsDetailDateOption dateOption,
    required DateTimeRange? customDateRange,
    required String? selectedFeedback,
    required CallLogsDetailSummaryStats summaryStats,
  }) {
    // Combine standard categories and detected categories
    final allCategories = <String>{
      ...kBusinessCategories,
      ...summaryStats.categoryCounts.keys,
    }.toList()
      ..sort();

    final isHyderabad = isCityHyderabad(selectedCity);

    final hasActiveFilters = selectedCategory != null ||
        (isHyderabad && selectedZone != null) ||
        dateOption != CallLogsDetailDateOption.last7Days ||
        selectedFeedback != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Hyderabad Zone Dropdown — visible ONLY when City is Hyderabad
          if (isHyderabad)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
              child: DropdownButtonFormField<ServiceProviderAreaGroup?>(
                key: ValueKey('hyderabad_zone_dropdown_${selectedZone?.displayName}'),
                initialValue: selectedZone,
                isDense: true,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Zone',
                  labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
                items: [
                  DropdownMenuItem<ServiceProviderAreaGroup?>(
                    value: null,
                    child: Text('All Zones', style: GoogleFonts.poppins(fontSize: 12.5)),
                  ),
                  ...kHyderabadAreaGroups.map(
                    (zone) => DropdownMenuItem<ServiceProviderAreaGroup?>(
                      value: zone,
                      child: Text(zone.displayName, style: GoogleFonts.poppins(fontSize: 12.5)),
                    ),
                  ),
                ],
                onChanged: (val) {
                  ref.read(callLogsDetailSelectedZoneProvider.notifier).state = val;
                  ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
                },
              ),
            ),

          // Category Selector Dropdown
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
            child: DropdownButtonFormField<String?>(
              initialValue: selectedCategory,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Category',
                labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Categories', style: GoogleFonts.poppins(fontSize: 12.5)),
                ),
                ...allCategories.map(
                  (cat) => DropdownMenuItem<String?>(
                    value: cat,
                    child: Text(cat, style: GoogleFonts.poppins(fontSize: 12.5)),
                  ),
                ),
              ],
              onChanged: (val) {
                ref.read(callLogsDetailSelectedCategoryProvider.notifier).state = val;
                ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
              },
            ),
          ),

          // Date Filter Dropdown
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 200),
            child: DropdownButtonFormField<CallLogsDetailDateOption>(
              initialValue: dateOption,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Date Range',
                labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              items: CallLogsDetailDateOption.values.map((opt) {
                return DropdownMenuItem<CallLogsDetailDateOption>(
                  value: opt,
                  child: Text(opt.label, style: GoogleFonts.poppins(fontSize: 12.5)),
                );
              }).toList(),
              onChanged: (val) async {
                if (val == null) return;
                if (val == CallLogsDetailDateOption.custom) {
                  final initialDateRange = customDateRange ??
                      DateTimeRange(
                        start: DateTime.now().subtract(const Duration(days: 7)),
                        end: DateTime.now(),
                      );
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2022),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                    initialDateRange: initialDateRange,
                  );
                  if (picked != null) {
                    ref.read(callLogsDetailCustomDateRangeProvider.notifier).state = picked;
                    ref.read(callLogsDetailDateOptionProvider.notifier).state =
                        CallLogsDetailDateOption.custom;
                    ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
                  }
                } else {
                  ref.read(callLogsDetailDateOptionProvider.notifier).state = val;
                  ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
                }
              },
            ),
          ),

          // Feedback Status Dropdown
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 160, maxWidth: 200),
            child: DropdownButtonFormField<String?>(
              initialValue: selectedFeedback,
              isDense: true,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Feedback Status',
                labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Statuses', style: GoogleFonts.poppins(fontSize: 12.5)),
                ),
                ...summaryStats.distinctFeedbackStatuses.map(
                  (st) => DropdownMenuItem<String?>(
                    value: st,
                    child: Text(st, style: GoogleFonts.poppins(fontSize: 12.5)),
                  ),
                ),
              ],
              onChanged: (val) {
                ref.read(callLogsDetailFeedbackStatusFilterProvider.notifier).state = val;
                ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
              },
            ),
          ),

          // Reset / Clear Filters button
          if (hasActiveFilters)
            TextButton.icon(
              onPressed: () {
                ref.read(callLogsDetailSelectedCategoryProvider.notifier).state = null;
                ref.read(callLogsDetailSelectedZoneProvider.notifier).state = null;
                ref.read(callLogsDetailDateOptionProvider.notifier).state =
                    CallLogsDetailDateOption.last7Days;
                ref.read(callLogsDetailCustomDateRangeProvider.notifier).state = null;
                ref.read(callLogsDetailFeedbackStatusFilterProvider.notifier).state = null;
                ref.read(callLogsDetailSearchQueryProvider.notifier).state = '';
                _searchController.clear();
                setState(() => _hasSearchText = false);
                ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
              },
              icon: const Icon(Icons.clear_all_rounded, size: 16, color: Color(0xFFEF4444)),
              label: Text(
                'Reset Filters',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// 5. SEARCH BAR
  /// ---------------------------------------------------------------------------
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
          ref.read(callLogsDetailSearchQueryProvider.notifier).state = value;
          ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
        },
        style: GoogleFonts.poppins(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search by business name, phone number, provider UID / business ID...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 20,
          ),
          suffixIcon: _hasSearchText
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _hasSearchText = false;
                    });
                    ref.read(callLogsDetailSearchQueryProvider.notifier).state = '';
                    ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// 6. DATA CONTENT (TABLE / MOBILE CARDS / LOADING / EMPTY)
  /// ---------------------------------------------------------------------------
  Widget _buildDataContent(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<CallLogsDetailItem>> rawDataAsync,
    required CallLogsDetailPaginationData pagination,
    required String cityDisplay,
    required String? selectedCategory,
  }) {
    // Loading State
    if (rawDataAsync.isLoading && !rawDataAsync.hasValue) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: Color(0xFF0284C7)),
        ),
      );
    }

    // Error State
    if (rawDataAsync.hasError && (!rawDataAsync.hasValue || rawDataAsync.value!.isEmpty)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
              const SizedBox(height: 12),
              Text(
                'Error loading call logs: ${rawDataAsync.error}',
                style: GoogleFonts.poppins(color: const Color(0xFF0F172A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(callLogsDetailRawDataProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Empty State
    if (pagination.pageItems.isEmpty) {
      final categoryLabel = selectedCategory != null ? ' in $selectedCategory' : '';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.phone_disabled_rounded,
              size: 44,
              color: Color(0xFF94A3B8),
            ),
            const SizedBox(height: 14),
            Text(
              'No Call Logs Found',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No call logs found for $cityDisplay$categoryLabel with current filters.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(callLogsDetailSelectedCategoryProvider.notifier).state = null;
                ref.read(callLogsDetailSelectedZoneProvider.notifier).state = null;
                ref.read(callLogsDetailDateOptionProvider.notifier).state =
                    CallLogsDetailDateOption.last7Days;
                ref.read(callLogsDetailCustomDateRangeProvider.notifier).state = null;
                ref.read(callLogsDetailFeedbackStatusFilterProvider.notifier).state = null;
                ref.read(callLogsDetailSearchQueryProvider.notifier).state = '';
                _searchController.clear();
                setState(() => _hasSearchText = false);
                ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
              },
              icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
              label: const Text('Reset All Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF1F5F9),
                foregroundColor: const Color(0xFF334155),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 1024;

    return Column(
      children: [
        isDesktop
            ? _buildDesktopTable(context, ref, pagination)
            : _buildMobileCardsList(context, pagination),
        const SizedBox(height: 16),
        _buildPaginationBar(ref, pagination),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// DESKTOP DATA TABLE (11 REQUIRED COLUMNS)
  /// ---------------------------------------------------------------------------
  Widget _buildDesktopTable(
    BuildContext context,
    WidgetRef ref,
    CallLogsDetailPaginationData pagination,
  ) {
    final sortColumn = ref.watch(callLogsDetailSortColumnProvider);
    final sortAscending = ref.watch(callLogsDetailSortAscendingProvider);

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
            constraints: const BoxConstraints(minWidth: 1200),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dataRowMaxHeight: 64,
              columnSpacing: 18,
              horizontalMargin: 16,
              sortColumnIndex: _getSortColumnIndex(sortColumn),
              sortAscending: sortAscending,
              columns: [
                // 1. Sl. No.
                const DataColumn(label: Text('Sl. No.')),
                // 2. Business Name
                DataColumn(
                  label: const Text('Business Name'),
                  onSort: (columnIndex, ascending) {
                    ref.read(callLogsDetailSortColumnProvider.notifier).state =
                        CallLogsDetailSortColumn.businessName;
                    ref.read(callLogsDetailSortAscendingProvider.notifier).state = ascending;
                  },
                ),
                // 3. Business Phone Number
                const DataColumn(label: Text('Business Phone')),
                // 4. City
                DataColumn(
                  label: const Text('City'),
                  onSort: (columnIndex, ascending) {
                    ref.read(callLogsDetailSortColumnProvider.notifier).state =
                        CallLogsDetailSortColumn.city;
                    ref.read(callLogsDetailSortAscendingProvider.notifier).state = ascending;
                  },
                ),
                // 5. Category
                DataColumn(
                  label: const Text('Category'),
                  onSort: (columnIndex, ascending) {
                    ref.read(callLogsDetailSortColumnProvider.notifier).state =
                        CallLogsDetailSortColumn.category;
                    ref.read(callLogsDetailSortAscendingProvider.notifier).state = ascending;
                  },
                ),
                // 6. Provider UID / Business ID
                const DataColumn(label: Text('Provider UID / Business ID')),
                // 7. Call Date
                DataColumn(
                  label: const Text('Call Date'),
                  onSort: (columnIndex, ascending) {
                    ref.read(callLogsDetailSortColumnProvider.notifier).state =
                        CallLogsDetailSortColumn.callDate;
                    ref.read(callLogsDetailSortAscendingProvider.notifier).state = ascending;
                  },
                ),
                // 8. Call Time
                const DataColumn(label: Text('Call Time')),
                // 9. Calls After Payment
                DataColumn(
                  label: const Text('Calls After Payment'),
                  onSort: (columnIndex, ascending) {
                    ref.read(callLogsDetailSortColumnProvider.notifier).state =
                        CallLogsDetailSortColumn.callsAfterPayment;
                    ref.read(callLogsDetailSortAscendingProvider.notifier).state = ascending;
                  },
                ),
                // 10. Call Status
                const DataColumn(label: Text('Call Status')),
                // 11. Feedback Status
                const DataColumn(label: Text('Feedback Status')),
              ],
              rows: List.generate(pagination.pageItems.length, (index) {
                final item = pagination.pageItems[index];
                final slNo = (pagination.currentPage * pagination.pageSize) + index + 1;

                return DataRow(
                  cells: [
                    // 1. Sl. No.
                    DataCell(
                      Text(
                        '$slNo',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // 2. Business Name
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          item.businessName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // 3. Business Phone Number
                    DataCell(
                      Text(
                        item.businessPhone,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF334155),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // 4. City
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.city,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ),

                    // 5. Category
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: Text(
                          item.category,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF0284C7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),

                    // 6. Provider UID / Business ID
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 140),
                            child: Text(
                              item.businessId,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
                            tooltip: 'Copy UID',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: item.businessId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied UID: ${item.businessId}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 7. Call Date
                    DataCell(
                      Text(
                        item.formattedCallDate,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    ),

                    // 8. Call Time
                    DataCell(
                      Text(
                        item.formattedCallTime,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),

                    // 9. Calls After Payment
                    DataCell(
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.callsAfterPayment > 5
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.formattedCallsAfterPayment,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: item.callsAfterPayment > 5
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 10. Call Status (if available)
                    DataCell(
                      _buildCallStatusBadge(item.displayCallStatus),
                    ),

                    // 11. Feedback Status (if available)
                    DataCell(
                      _buildFeedbackStatusBadge(item.displayFeedbackStatus),
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

  int? _getSortColumnIndex(CallLogsDetailSortColumn column) {
    switch (column) {
      case CallLogsDetailSortColumn.businessName:
        return 1;
      case CallLogsDetailSortColumn.city:
        return 3;
      case CallLogsDetailSortColumn.category:
        return 4;
      case CallLogsDetailSortColumn.callDate:
        return 6;
      case CallLogsDetailSortColumn.callsAfterPayment:
        return 8;
      default:
        return null;
    }
  }

  Widget _buildCallStatusBadge(String status) {
    if (status == '--') {
      return Text(
        '--',
        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
      );
    }
    final norm = status.toLowerCase();
    Color color = const Color(0xFF64748B);
    if (norm.contains('complete') || norm.contains('connected') || norm.contains('success')) {
      color = const Color(0xFF10B981);
    } else if (norm.contains('missed') || norm.contains('failed')) {
      color = const Color(0xFFEF4444);
    } else if (norm.contains('busy')) {
      color = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFeedbackStatusBadge(String status) {
    if (status == '--') {
      return Text(
        '--',
        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
      );
    }
    final norm = status.toLowerCase();
    Color color = const Color(0xFF64748B);
    if (norm == 'converted') {
      color = const Color(0xFF10B981);
    } else if (norm.contains('interested')) {
      color = const Color(0xFF0284C7);
    } else if (norm.contains('follow')) {
      color = const Color(0xFFF59E0B);
    } else if (norm.contains('not') || norm.contains('rejected')) {
      color = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// MOBILE / TABLET CARDS LIST (< 1024px)
  /// ---------------------------------------------------------------------------
  Widget _buildMobileCardsList(
    BuildContext context,
    CallLogsDetailPaginationData pagination,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: pagination.pageItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = pagination.pageItems[index];
        final slNo = (pagination.currentPage * pagination.pageSize) + index + 1;

        return Container(
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
              // Header Row: Sl No + Business Name + Phone
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$slNo',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.businessName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          item.businessPhone,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Badges Row: City + Category
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 12, color: Color(0xFF475569)),
                        const SizedBox(width: 3),
                        Text(
                          item.city,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),

              // Grid of Call Details
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Call Date & Time',
                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                      Text(
                        '${item.formattedCallDate}, ${item.formattedCallTime}',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Calls After Payment',
                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                      Text(
                        item.formattedCallsAfterPayment,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: item.callsAfterPayment > 5
                              ? const Color(0xFFD97706)
                              : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Statuses & UID Row
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildCallStatusBadge(item.displayCallStatus),
                      _buildFeedbackStatusBadge(item.displayFeedbackStatus),
                    ],
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: item.businessId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied UID: ${item.businessId}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Copy UID',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
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

  /// ---------------------------------------------------------------------------
  /// 7. PAGINATION BAR
  /// ---------------------------------------------------------------------------
  Widget _buildPaginationBar(WidgetRef ref, CallLogsDetailPaginationData pagination) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          // Range Text
          Text(
            'Showing ${pagination.startIndex}–${pagination.endIndex} of ${pagination.totalItems} records',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),

          // Paging controls & page size selector
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Page size dropdown
                Text(
                  'Rows: ',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                DropdownButton<int>(
                  value: pagination.pageSize,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(callLogsDetailPageSizeProvider.notifier).state = val;
                      ref.read(callLogsDetailCurrentPageProvider.notifier).state = 0;
                    }
                  },
                ),
                const SizedBox(width: 12),

                // Previous Page
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: pagination.hasPreviousPage
                      ? () {
                          ref.read(callLogsDetailCurrentPageProvider.notifier).state =
                              pagination.currentPage - 1;
                        }
                      : null,
                  tooltip: 'Previous Page',
                ),

                // Page Indicator
                Text(
                  'Page ${pagination.currentPage + 1} of ${pagination.totalPages}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),

                // Next Page
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: pagination.hasNextPage
                      ? () {
                          ref.read(callLogsDetailCurrentPageProvider.notifier).state =
                              pagination.currentPage + 1;
                        }
                      : null,
                  tooltip: 'Next Page',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
