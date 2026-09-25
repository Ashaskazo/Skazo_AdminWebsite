import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/constants/business_categories.dart';
import 'package:skazo_admin/models/payment_record.dart';
import 'package:skazo_admin/models/revenue_analytics_model.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/revenue_providers.dart';
import 'package:skazo_admin/utils/csv_export_helper.dart';

/// Complete Payments & Revenue Analytics Command Center.
/// Matches the Star Service Providers UI layout, styling, typography, and interaction patterns.
class PaymentsDataView extends ConsumerStatefulWidget {
  const PaymentsDataView({super.key});

  @override
  ConsumerState<PaymentsDataView> createState() => _PaymentsDataViewState();
}

class _PaymentsDataViewState extends ConsumerState<PaymentsDataView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _hScrollController = ScrollController();
  final ScrollController _vScrollController = ScrollController();
  final ScrollController _filterBarScrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _hScrollController.dispose();
    _vScrollController.dispose();
    _filterBarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(revenueActiveTabProvider);
    final analyticsAsync = ref.watch(revenueAnalyticsDataProvider);
    final currentFilter = ref.watch(revenueFilterProvider);
    final selectedRecordForDrawer = ref.watch(
      revenueSelectedRecordForDrawerProvider,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _vScrollController,
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header & Action Banner
                _buildTopHeader(context, analyticsAsync),
                const SizedBox(height: 20),

                // Navigation Tabs
                _buildTabsBar(activeTab),
                const SizedBox(height: 20),

                // Data Architecture & Quality Notice
                // _buildDataArchitectureBanner(analyticsAsync),
                // const SizedBox(height: 20),

                // Global Filter Bar (shown on analytics tabs)
                if (activeTab != RevenueDashboardTab.linkSender) ...[
                  _buildGlobalFilterBar(currentFilter),
                  const SizedBox(height: 24),
                ],

                // Tab Content Switcher
                switch (activeTab) {
                  RevenueDashboardTab.overview => _buildOverviewTab(
                    analyticsAsync,
                  ),
                  RevenueDashboardTab.streams => _buildStreamsTab(
                    analyticsAsync,
                  ),
                  RevenueDashboardTab.cities => _buildCitiesTab(analyticsAsync),
                  RevenueDashboardTab.categories => _buildCategoriesTab(
                    analyticsAsync,
                  ),
                  RevenueDashboardTab.transactions => _buildTransactionsTab(
                    analyticsAsync,
                  ),
                  RevenueDashboardTab.reconciliation => _buildReconciliationTab(
                    analyticsAsync,
                  ),
                  RevenueDashboardTab.linkSender => _buildLinkOperationsTab(),
                },
              ],
            ),
          ),

          // Slide-in Transaction Details Drawer
          if (selectedRecordForDrawer != null)
            _buildDetailDrawer(selectedRecordForDrawer),
        ],
      ),
    );
  }

  // =========================================================================
  // TOP HEADER & NAVIGATION
  // =========================================================================

  Widget _buildTopHeader(
    BuildContext context,
    AsyncValue<RevenueAnalyticsData> analyticsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'PAYMENTS & REVENUE',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'AUDITED LEDGER',
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
                const SizedBox(height: 8),
                Text(
                  'Canonical payment streams, outstanding separation, city attribution & reconciliation.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          analyticsAsync.maybeWhen(
            data:
                (data) => Row(
                  children: [
                    _buildHeaderStatChip(
                      label: 'Total Collected',
                      value:
                          '₹${NumberFormat('#,##,###').format(data.totalCollectedRevenue)}',
                      color: const Color(0xFF38BDF8),
                    ),
                    const SizedBox(width: 12),
                    _buildHeaderStatChip(
                      label: 'Outstanding PPL',
                      value:
                          '₹${NumberFormat('#,##,###').format(data.outstandingPayPerLead)}',
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 12),
                    _buildHeaderStatChip(
                      label: 'Txns',
                      value: '${data.totalTransactions}',
                      color: const Color(0xFFA78BFA),
                    ),
                    const SizedBox(width: 16),
                    // Export CSV Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final success =
                            await CsvExportHelper.downloadPaymentRecordsCsv(
                              data.allMatchingRecords,
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Exported ${data.allMatchingRecords.length} records to CSV successfully!'
                                    : 'No records to export.',
                                style: GoogleFonts.poppins(),
                              ),
                              backgroundColor:
                                  success
                                      ? const Color(0xFF16A34A)
                                      : Colors.orange,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.file_download_rounded, size: 16),
                      label: Text(
                        'Export CSV',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Refresh Button
                    IconButton(
                      onPressed:
                          () => ref.invalidate(revenueRawRecordsProvider),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                      ),
                      tooltip: 'Sync & Refresh All Collections',
                    ),
                  ],
                ),
            orElse:
                () => IconButton(
                  onPressed: () => ref.invalidate(revenueRawRecordsProvider),
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                  ),
                  tooltip: 'Refresh',
                ),
          ),
        ],
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
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF94A3B8),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsBar(RevenueDashboardTab activeTab) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Row(
          children:
              RevenueDashboardTab.values.map((tab) {
                final isSelected = activeTab == tab;
                final icon = switch (tab) {
                  RevenueDashboardTab.overview => Icons.analytics_rounded,
                  RevenueDashboardTab.streams => Icons.payments_rounded,
                  RevenueDashboardTab.cities => Icons.location_city_rounded,
                  RevenueDashboardTab.categories => Icons.category_rounded,
                  RevenueDashboardTab.transactions =>
                    Icons.receipt_long_rounded,
                  RevenueDashboardTab.reconciliation => Icons.balance_rounded,
                  RevenueDashboardTab.linkSender => Icons.link_rounded,
                };

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap:
                        () =>
                            ref.read(revenueActiveTabProvider.notifier).state =
                                tab,
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? const Color(0xFF0F172A)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color:
                                isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tab.title,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildDataArchitectureBanner(
    AsyncValue<RevenueAnalyticsData> analyticsAsync,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: Color(0xFF1D4ED8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Integrity Audit Standards Active',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E40AF),
                  ),
                ),
                Text(
                  'No dedicated Firestore transactions collection exists; provider subscription figures represent latest checkout state (dataScope: latest_only). Outstanding Pay-per-lead is strictly excluded from collected revenue. Google Sheets historical records are kept unmerged to prevent duplication.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // GLOBAL FILTER BAR
  // =========================================================================

  Widget _buildGlobalFilterBar(RevenueFilter filter) {
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
          // Row 1: Search Box & Reset
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      ref.read(revenueFilterProvider.notifier).state = filter
                          .copyWith(searchQuery: val.trim());
                    },
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'Search by Transaction ID, User, Phone, City, Category, or Doc ID...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 18,
                        color: Color(0xFF94A3B8),
                      ),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(revenueFilterProvider.notifier)
                                      .state = filter.copyWith(searchQuery: '');
                                },
                              )
                              : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Reset filters button
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  ref.read(revenueFilterProvider.notifier).state =
                      const RevenueFilter();
                },
                icon: const Icon(
                  Icons.filter_alt_off_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                label: Text(
                  'Reset Filters',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Row 2: Date Range Pills (Horizontal Scroll)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children:
                  RevenueDateRangeOption.values.map((opt) {
                    final isSelected = filter.dateRangeOption == opt;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () async {
                          if (opt == RevenueDateRangeOption.customRange) {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2022),
                              lastDate: DateTime.now().add(
                                const Duration(days: 1),
                              ),
                              initialDateRange:
                                  filter.customStartDate != null &&
                                          filter.customEndDate != null
                                      ? DateTimeRange(
                                        start: filter.customStartDate!,
                                        end: filter.customEndDate!,
                                      )
                                      : null,
                            );
                            if (picked != null) {
                              ref
                                  .read(revenueFilterProvider.notifier)
                                  .state = filter.copyWith(
                                dateRangeOption: opt,
                                customStartDate: picked.start,
                                customEndDate: picked.end,
                              );
                            }
                          } else {
                            ref
                                .read(revenueFilterProvider.notifier)
                                .state = filter.copyWith(dateRangeOption: opt);
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isSelected
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            opt == RevenueDateRangeOption.customRange &&
                                    filter.customStartDate != null
                                ? '${DateFormat('dd MMM').format(filter.customStartDate!)} - ${DateFormat('dd MMM').format(filter.customEndDate!)}'
                                : opt.label,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                              color:
                                  isSelected
                                      ? Colors.white
                                      : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Row 3: Dropdowns for City, Stream, and Status
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Stream Filter Dropdown
              _buildDropdownFilter<PaymentStream?>(
                label: 'Stream',
                value: filter.selectedStream,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Streams'),
                  ),
                  ...PaymentStream.values
                      .where(
                        (s) =>
                            s != PaymentStream.unknown &&
                            s != PaymentStream.payPerLeadCollected,
                      )
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.displayName),
                        ),
                      ),
                ],
                onChanged: (val) {
                  ref.read(revenueFilterProvider.notifier).state = filter
                      .copyWith(selectedStream: val, clearStream: val == null);
                },
              ),

              // Status Filter Dropdown
              _buildDropdownFilter<PaymentStatus?>(
                label: 'Status',
                value: filter.selectedStatus,
                items: const [
                  DropdownMenuItem(value: null, child: Text('All Statuses')),
                  DropdownMenuItem(
                    value: PaymentStatus.collected,
                    child: Text('Collected'),
                  ),
                  DropdownMenuItem(
                    value: PaymentStatus.outstanding,
                    child: Text('Outstanding'),
                  ),
                  DropdownMenuItem(
                    value: PaymentStatus.paymentAttempt,
                    child: Text('Payment Attempt'),
                  ),
                ],
                onChanged: (val) {
                  ref.read(revenueFilterProvider.notifier).state = filter
                      .copyWith(selectedStatus: val, clearStatus: val == null);
                },
              ),

              // City Quick Pill
              if (filter.selectedCity != null)
                Chip(
                  label: Text(
                    'City: ${filter.selectedCity}',
                    style: GoogleFonts.poppins(fontSize: 11),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    ref.read(revenueFilterProvider.notifier).state = filter
                        .copyWith(clearCity: true);
                  },
                  backgroundColor: const Color(0xFFE0F2FE),
                ),

              // Category Quick Pill
              if (filter.selectedCategory != null)
                Chip(
                  label: Text(
                    'Category: ${filter.selectedCategory}',
                    style: GoogleFonts.poppins(fontSize: 11),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () {
                    ref.read(revenueFilterProvider.notifier).state = filter
                        .copyWith(clearCategory: true);
                  },
                  backgroundColor: const Color(0xFFF3E8FF),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: (v) {
            onChanged(v as T);
          },
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: OVERVIEW & SUMMARY
  // =========================================================================

  Widget _buildOverviewTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data:
          (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Summary Metric Cards
              _buildSummaryCardsGrid(data),
              const SizedBox(height: 28),

              // Payment Streams Table
              _buildSectionHeader(
                'REVENUE BY PAYMENT STREAM',
                'Breakdown across verified SKAZO revenue channels',
              ),
              const SizedBox(height: 12),
              _buildStreamBreakdownTable(data),
              const SizedBox(height: 28),

              // City Quick Highlights
              _buildSectionHeader(
                'CITY SUMMARY PREVIEW',
                'Top contributing geographic markets',
              ),
              const SizedBox(height: 12),
              _buildCityBreakdownTable(data, limit: 5),
            ],
          ),
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildSummaryCardsGrid(RevenueAnalyticsData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount = w > 1200 ? 4 : (w > 760 ? 3 : 2);

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.1,
          children: [
            _buildStatCard(
              title: 'Total Collected Revenue',
              value:
                  '₹${NumberFormat('#,##,###').format(data.totalCollectedRevenue)}',
              sub: 'Verified received funds',
              color: const Color(0xFF0284C7),
              icon: Icons.payments_rounded,
            ),
            _buildStatCard(
              title: 'Current Period Revenue',
              value:
                  '₹${NumberFormat('#,##,###').format(data.currentPeriodRevenue)}',
              sub: 'Matches active date filter',
              color: const Color(0xFF16A34A),
              icon: Icons.date_range_rounded,
            ),
            _buildStatCard(
              title: 'Total Transactions',
              value: '${data.totalTransactions}',
              sub: 'Successful checkouts',
              color: const Color(0xFF8B5CF6),
              icon: Icons.receipt_rounded,
            ),
            _buildStatCard(
              title: 'Outstanding Pay-per-Lead',
              value:
                  '₹${NumberFormat('#,##,###').format(data.outstandingPayPerLead)}',
              sub: 'Owed debt (NOT collected)',
              color: const Color(0xFFEA580C),
              icon: Icons.pending_actions_rounded,
              isWarning: true,
            ),
            _buildStatCard(
              title: 'Provider Subscriptions',
              value:
                  '₹${NumberFormat('#,##,###').format(data.providerRevenue)}',
              sub: 'Verification & active plans',
              color: const Color(0xFF0F766E),
              icon: Icons.badge_rounded,
            ),
            _buildStatCard(
              title: 'Property Listing Fees',
              value:
                  '₹${NumberFormat('#,##,###').format(data.propertyRevenue)}',
              sub: 'Premium estate listings',
              color: const Color(0xFF4338CA),
              icon: Icons.home_work_rounded,
            ),
            _buildStatCard(
              title: 'Agent Verification',
              value: '₹${NumberFormat('#,##,###').format(data.agentRevenue)}',
              sub: '₹999 verified agent charge',
              color: const Color(0xFFD97706),
              icon: Icons.verified_user_rounded,
            ),
            _buildStatCard(
              title: 'Local Promotions',
              value:
                  '₹${NumberFormat('#,##,###').format(data.localPromotionRevenue)}',
              sub: 'In-app business ads',
              color: const Color(0xFFDB2777),
              icon: Icons.campaign_rounded,
            ),
            _buildStatCard(
              title: 'Tenant Contact Passes',
              value:
                  '₹${NumberFormat('#,##,###').format(data.tenantContactRevenue)}',
              sub: '₹49 current / ₹29 legacy',
              color: const Color(0xFF2563EB),
              icon: Icons.contact_phone_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isWarning ? const Color(0xFFFDBA74) : const Color(0xFFF1F5F9),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color:
                        isWarning
                            ? const Color(0xFFC2410C)
                            : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color:
                        isWarning
                            ? const Color(0xFFEA580C)
                            : const Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: REVENUE STREAMS
  // =========================================================================

  Widget _buildStreamsTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data:
          (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'CANONICAL REVENUE STREAMS',
                'Complete breakdown and audit criteria for all 6 payment streams',
              ),
              const SizedBox(height: 14),
              _buildStreamBreakdownTable(data),
              const SizedBox(height: 24),
              // Stream cards with source details
              ...data.streamBreakdown.map(
                (item) => _buildStreamDetailCard(item),
              ),
            ],
          ),
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildStreamBreakdownTable(RevenueAnalyticsData data) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.5),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1.0),
          5: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            children: [
              _buildTableHeaderCell('Payment Stream'),
              _buildTableHeaderCell('Transactions', align: TextAlign.right),
              _buildTableHeaderCell(
                'Collected Revenue',
                align: TextAlign.right,
              ),
              _buildTableHeaderCell('Outstanding', align: TextAlign.right),
              _buildTableHeaderCell('% Share', align: TextAlign.right),
              _buildTableHeaderCell('Action', align: TextAlign.center),
            ],
          ),
          ...data.streamBreakdown.map((item) {
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _colorForStream(item.stream),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.stream.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    '${item.transactionCount}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    '₹${NumberFormat('#,##,###').format(item.collectedRevenue)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    item.outstandingAmount > 0
                        ? '₹${NumberFormat('#,##,###').format(item.outstandingAmount)}'
                        : '—',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          item.outstandingAmount > 0
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    '${item.revenuePercentage.toStringAsFixed(1)}%',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: TextButton(
                    onPressed: () {
                      ref.read(revenueFilterProvider.notifier).state = ref
                          .read(revenueFilterProvider)
                          .copyWith(selectedStream: item.stream);
                      ref.read(revenueActiveTabProvider.notifier).state =
                          RevenueDashboardTab.transactions;
                    },
                    child: Text(
                      'Filter',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStreamDetailCard(StreamBreakdownItem item) {
    final (desc, source, fields) = switch (item.stream) {
      PaymentStream.providerSubscription => (
        'Subscription and verification fees paid by Star Service Providers to activate their profile and receive verified badges.',
        'Firestore `users` collection',
        'AtivePlan, totalAmount, paymentCount, transactionId, paymentPlanDuration, paymentDate, paymentLinkSend',
      ),
      PaymentStream.payPerLeadOutstanding => (
        'Accumulated debt charged when customer calls/leads are delivered to providers. Owed amount that becomes collected only when checked out.',
        'Firestore `users` collection',
        'payperLeadcharge, overallpayperleadamount, lastpaymentpayperlead, payPerLeadFeedback',
      ),
      PaymentStream.tenantContact => (
        'Fees paid by tenants to unlock landlord phone numbers and contact details (active: ₹49, historical: ₹29).',
        'Firestore `users` collection',
        'userPropertyPaid, userPropertyPaymentDate, userPropertyValidTill, userPropertyPaymentId',
      ),
      PaymentStream.propertyListing => (
        'Premium listing promotions and verified badge charges paid by property owners for rental properties.',
        'Firestore `rental_properties` collection',
        'ownerPlan, transactionId, paymentDate, isPremium, isBoosted, paymentPropertyLinkSend',
      ),
      PaymentStream.agentVerification => (
        'Verification and onboarding fees paid by agents (standard ₹999 fee). Commission earned is not treated as SKAZO revenue.',
        'Firestore `agents` collection',
        'transactionId, agentPlan, isApproved, agentPaymentLink, city',
      ),
      PaymentStream.localPromotion => (
        'Paid promotional banners and local ads shown across the application.',
        'Firestore `local_promotions` collection',
        'transactionId, paymentDate, amount, activePlan, planExpiredDate, paymentInitiated',
      ),
      _ => ('Other revenue streams', 'Unknown', 'N/A'),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.stream.displayName,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  source,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.code_rounded,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Relevant fields: $fields',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: CITY WISE REVENUE
  // =========================================================================

  Widget _buildCitiesTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data:
          (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'CITY-WISE REVENUE BREAKDOWN',
                'Geographic attribution based on direct city records and verified pincode resolution',
              ),
              const SizedBox(height: 14),
              _buildCityBreakdownTable(data),
            ],
          ),
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildCityBreakdownTable(RevenueAnalyticsData data, {int? limit}) {
    final list =
        limit != null
            ? data.cityBreakdown.take(limit).toList()
            : data.cityBreakdown;

    if (list.isEmpty) {
      return _buildEmptyMessage('No city records matching current filters.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.0),
          1: FlexColumnWidth(1.2),
          2: FlexColumnWidth(1.5),
          3: FlexColumnWidth(1.5),
          4: FlexColumnWidth(1.0),
          5: FlexColumnWidth(1.4),
          6: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            children: [
              _buildTableHeaderCell('City'),
              _buildTableHeaderCell('Transactions', align: TextAlign.right),
              _buildTableHeaderCell(
                'Collected Revenue',
                align: TextAlign.right,
              ),
              _buildTableHeaderCell('Outstanding', align: TextAlign.right),
              _buildTableHeaderCell('Users', align: TextAlign.right),
              _buildTableHeaderCell('Avg Payment', align: TextAlign.right),
              _buildTableHeaderCell('Action', align: TextAlign.center),
            ],
          ),
          ...list.map((item) {
            final isUnmapped = item.city.toLowerCase().contains('unmapped');
            return TableRow(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    item.city,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isUnmapped
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF1E293B),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    '${item.transactionCount}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    '₹${NumberFormat('#,##,###').format(item.collectedRevenue)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF16A34A),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    item.outstandingAmount > 0
                        ? '₹${NumberFormat('#,##,###').format(item.outstandingAmount)}'
                        : '—',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          item.outstandingAmount > 0
                              ? const Color(0xFFEA580C)
                              : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    '${item.uniqueUsers}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Text(
                    '₹${item.averagePayment.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  child: TextButton(
                    onPressed: () {
                      ref.read(revenueFilterProvider.notifier).state = ref
                          .read(revenueFilterProvider)
                          .copyWith(selectedCity: item.city);
                      ref.read(revenueActiveTabProvider.notifier).state =
                          RevenueDashboardTab.transactions;
                    },
                    child: Text(
                      'View',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 4: CATEGORY WISE REVENUE — FULL INTERACTIVE VIEW
  // Uses revenueRawRecordsProvider (unfiltered) + global date/search from
  // revenueFilterProvider + local stream/city from categoryWiseLocalStateProvider.
  // ZERO additional Firestore reads — all grouping is done in-memory.
  // =========================================================================

  // =========================================================================
  // TAB 4: CATEGORY WISE REVENUE — 2-LEVEL FLOW (CARDS -> DRILL-DOWN)
  // 44 canonical categories, in-memory grouping, multi-category token matching,
  // zero extra Firestore queries. Stream is strictly preserved into detail view.
  // =========================================================================

  /// Normalized check whether category token [cat] matches canonical [canonicalCategory].
  /// Handles case-insensitivity, singular/plural variants, and comma-separated tokens.
  bool _categoryMatches(String cat, String canonicalCategory) {
    final a = cat.trim().toLowerCase();
    final b = canonicalCategory.trim().toLowerCase();
    if (a.isEmpty || b.isEmpty) return false;
    if (a == b) return true;
    if (a == '${b}s' || '${a}s' == b) return true;
    if (a.endsWith('ies') && '${a.substring(0, a.length - 3)}y' == b) return true;
    if (b.endsWith('ies') && '${b.substring(0, b.length - 3)}y' == a) return true;
    return false;
  }

  /// Checks whether a [PaymentRecord] belongs to [canonicalCategory].
  /// Handles multi-category strings like "Electrician, AC Repair".
  bool _recordBelongsToCategory(PaymentRecord record, String canonicalCategory) {
    final raw = record.category.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'unmapped') return false;
    final tokens = raw.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty);
    for (final t in tokens) {
      if (_categoryMatches(t, canonicalCategory)) {
        return true;
      }
    }
    return false;
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'house cleaning':
      case 'pest control':
      case 'tank cleaning':
        return Icons.cleaning_services_rounded;
      case 'electricians':
      case 'electrician':
        return Icons.bolt_rounded;
      case 'plumbers':
      case 'plumber':
        return Icons.plumbing_rounded;
      case 'ac repair':
        return Icons.ac_unit_rounded;
      case 'fridge repair':
        return Icons.kitchen_rounded;
      case 'washing machine repair':
        return Icons.local_laundry_service_rounded;
      case 'cctv installation':
        return Icons.videocam_rounded;
      case 'water purifier repair':
        return Icons.water_drop_rounded;
      case 'kitchen appliances repair':
        return Icons.microwave_rounded;
      case 'tv repair':
        return Icons.tv_rounded;
      case 'phone & system repairs':
        return Icons.phonelink_setup_rounded;
      case 'wood works':
        return Icons.carpenter_rounded;
      case 'glass design works':
        return Icons.window_rounded;
      case 'interior designers':
        return Icons.deck_rounded;
      case 'ceiling':
      case 'tiles':
        return Icons.roofing_rounded;
      case 'painters':
      case 'painter':
        return Icons.format_paint_rounded;
      case 'purohith':
      case 'wedding halls':
      case 'photographers':
      case 'catering':
      case 'shamiyana':
      case 'bridal and groom makeup':
      case 'beauty services':
      case 'mehandi artists':
      case 'other event services':
        return Icons.celebration_rounded;
      case 'astrologers':
        return Icons.psychology_rounded;
      case 'packers and movers':
        return Icons.local_shipping_rounded;
      case 'car mechanic':
      case 'bike mechanic':
        return Icons.two_wheeler_rounded;
      case 'car drivers':
      case 'car travels':
      case 'autos':
        return Icons.directions_car_rounded;
      case 'welders':
        return Icons.hardware_rounded;
      case 'builders & contractors':
        return Icons.construction_rounded;
      case 'ambulance':
      case 'diagnostic centers':
        return Icons.medical_services_rounded;
      case 'tenant membership':
        return Icons.badge_rounded;
      case 'rental property listing':
        return Icons.home_work_rounded;
      case 'agent verification':
        return Icons.verified_user_rounded;
      case 'local promotions':
        return Icons.campaign_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildCategoriesTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    final rawAsync = ref.watch(revenueRawRecordsProvider);
    final globalFilter = ref.watch(revenueFilterProvider);
    final cwState = ref.watch(categoryWiseLocalStateProvider);

    return rawAsync.when(
      data: (rawRecords) {
        // 1. Base filter: global date + global search + local stream + local city
        final baseRecords = rawRecords.where((r) {
          final range = globalFilter.dateRangeOption
              .calculateRange(globalFilter.customStartDate, globalFilter.customEndDate);
          if (range != null) {
            if (r.paymentDate == null) return false;
            if (r.paymentDate!.isBefore(range.start) ||
                r.paymentDate!.isAfter(range.end)) {
              return false;
            }
          }
          if (globalFilter.searchQuery.isNotEmpty) {
            final q = globalFilter.searchQuery.toLowerCase();
            final ok = r.transactionId.toLowerCase().contains(q) ||
                (r.razorpayPaymentId?.toLowerCase().contains(q) ?? false) ||
                (r.userName?.toLowerCase().contains(q) ?? false) ||
                (r.userPhone?.toString().contains(q) ?? false) ||
                r.city.toLowerCase().contains(q) ||
                r.category.toLowerCase().contains(q) ||
                r.sourceDocumentId.toLowerCase().contains(q);
            if (!ok) return false;
          }
          if (cwState.localStream != null && r.stream != cwState.localStream) {
            return false;
          }
          if (cwState.localCity != null && cwState.localCity!.isNotEmpty) {
            if (r.city.toLowerCase() != cwState.localCity!.toLowerCase()) {
              return false;
            }
          }
          return true;
        }).toList();

        // Level 2: If a category card was clicked, show detail view
        if (cwState.selectedCategory != null) {
          return _buildCategoryDetailView(
            cwState,
            baseRecords,
            globalFilter,
            rawRecords,
          );
        }

        // Level 1: 44 Canonical Category Cards
        final List<_CatAccum> cats = [];
        for (final canonicalCat in kAllCanonicalCategories) {
          final accum = _CatAccum(canonicalCat);
          for (final r in baseRecords) {
            if (_recordBelongsToCategory(r, canonicalCat)) {
              accum.add(r);
            }
          }
          cats.add(accum);
        }

        final totalCollected = cats.fold<double>(
          0.0,
          (s, c) => s + c.collectedRevenue,
        );

        // Sort: Collected Revenue DESC -> Count DESC -> Name ASC
        cats.sort((a, b) {
          final c1 = b.collectedRevenue.compareTo(a.collectedRevenue);
          if (c1 != 0) return c1;
          final c2 = b.transactionCount.compareTo(a.transactionCount);
          if (c2 != 0) return c2;
          return a.displayName.compareTo(b.displayName);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCategoryWiseFilters(cwState, rawRecords),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSectionHeader(
                    'CATEGORY WISE REVENUE',
                    '44 canonical categories — calculated in-memory with zero extra Firestore reads',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(
                    'Showing ${cats.length} categories',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildCategoryCardsGrid(cats, totalCollected),
          ],
        );
      },
      loading: () => const Center(
        child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
      ),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildCategoryWiseFilters(
    CategoryWiseLocalState cwState,
    List<PaymentRecord> rawRecords,
  ) {
    final cities = rawRecords
        .map((r) => r.city)
        .where((c) => c.isNotEmpty && c.toLowerCase() != 'unknown / unmapped')
        .toSet()
        .toList()
      ..sort();

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
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Payment Stream',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              _buildDropdownFilter<PaymentStream?>(
                label: 'Stream',
                value: cwState.localStream,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Streams')),
                  ...PaymentStream.values
                      .where((s) =>
                          s != PaymentStream.unknown &&
                          s != PaymentStream.payPerLeadCollected)
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.displayName))),
                ],
                onChanged: (val) {
                  // Updates stream without resetting selectedCategory so Level 2 recalculates immediately
                  ref.read(categoryWiseLocalStateProvider.notifier).state =
                      cwState.copyWith(
                    localStream: val,
                    clearStream: val == null,
                  );
                },
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'City',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 4),
              _buildDropdownFilter<String?>(
                label: 'City',
                value: cwState.localCity,
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Cities')),
                  ...cities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (val) {
                  ref.read(categoryWiseLocalStateProvider.notifier).state =
                      cwState.copyWith(
                    localCity: val,
                    clearCity: val == null,
                  );
                },
              ),
            ],
          ),
          if (cwState.localStream != null)
            Chip(
              label: Text(
                'Stream: ${cwState.localStream!.shortName}',
                style: GoogleFonts.poppins(fontSize: 11),
              ),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                ref.read(categoryWiseLocalStateProvider.notifier).state =
                    cwState.copyWith(clearStream: true);
              },
              backgroundColor: const Color(0xFFE0F2FE),
            ),
          if (cwState.localCity != null)
            Chip(
              label: Text(
                'City: ${cwState.localCity}',
                style: GoogleFonts.poppins(fontSize: 11),
              ),
              deleteIcon: const Icon(Icons.close, size: 14),
              onDeleted: () {
                ref.read(categoryWiseLocalStateProvider.notifier).state =
                    cwState.copyWith(clearCity: true);
              },
              backgroundColor: const Color(0xFFE0F2FE),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryCardsGrid(List<_CatAccum> cats, double totalCollected) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1440 ? 4 : (w >= 1024 ? 3 : (w >= 600 ? 2 : 1));
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: cols >= 3 ? 1.45 : 1.25,
          ),
          itemCount: cats.length,
          itemBuilder: (context, i) {
            final cat = cats[i];
            final pct = totalCollected > 0
                ? (cat.collectedRevenue / totalCollected * 100)
                : 0.0;
            return _buildCategoryCard(cat, pct, i);
          },
        );
      },
    );
  }

  Widget _buildCategoryCard(_CatAccum cat, double pct, int index) {
    const accentColors = [
      Color(0xFF0284C7), Color(0xFF16A34A), Color(0xFF8B5CF6),
      Color(0xFF0F766E), Color(0xFFD97706), Color(0xFFDB2777),
      Color(0xFF2563EB), Color(0xFFEA580C), Color(0xFF4338CA),
      Color(0xFF059669),
    ];
    final accent = accentColors[index % accentColors.length];
    final iconData = _getCategoryIcon(cat.displayName);

    return GestureDetector(
      onTap: () {
        ref.read(categoryWiseLocalStateProvider.notifier).state =
            ref.read(categoryWiseLocalStateProvider)
                .copyWith(selectedCategory: cat.displayName);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(iconData, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    cat.displayName,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              '₹${NumberFormat('#,##,###').format(cat.collectedRevenue)}',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF16A34A),
              ),
            ),
            Text(
              '${cat.transactionCount} ${cat.transactionCount == 1 ? 'Payment' : 'Payments'}',
              style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
            ),
            if (cat.outstandingAmount > 0)
              Text(
                'Outstanding ₹${NumberFormat('#,##,###').format(cat.outstandingAmount)}',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC2410C),
                ),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${cat.uniqueUserIds.length} ${cat.uniqueUserIds.length == 1 ? 'Provider' : 'Providers'}',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
                const Spacer(),
                if (pct > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${pct.toStringAsFixed(1)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  ref.read(categoryWiseLocalStateProvider.notifier).state =
                      ref.read(categoryWiseLocalStateProvider)
                          .copyWith(selectedCategory: cat.displayName);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'View Details →',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // LEVEL 2: CATEGORY DETAIL VIEW
  // Only records belonging to BOTH selectedCategory AND active localStream appear.
  // Filters can be changed in-place; Back button returns to 44 Category Cards.
  // =========================================================================
  Widget _buildCategoryDetailView(
    CategoryWiseLocalState cwState,
    List<PaymentRecord> baseRecords,
    RevenueFilter globalFilter,
    List<PaymentRecord> rawRecords,
  ) {
    final selectedCat = cwState.selectedCategory!;

    // Detail records MUST satisfy both: selectedCategory AND selectedStream (already in baseRecords)
    final catRecords = baseRecords
        .where((r) => _recordBelongsToCategory(r, selectedCat))
        .toList();

    double collected = 0.0;
    double outstanding = 0.0;
    int count = 0;
    final Set<String> userIds = {};
    for (final r in catRecords) {
      if (r.isCollected) {
        collected += r.collectedAmount;
        count++;
      } else if (r.isOutstanding) {
        outstanding += r.outstandingAmount;
      }
      if (r.userId != null) userIds.add(r.userId!);
    }

    final streamLabel = cwState.localStream?.displayName ?? 'All Streams';
    final cityLabel = cwState.localCity ?? 'All Cities';
    final dateRange = globalFilter.dateRangeOption
        .calculateRange(globalFilter.customStartDate, globalFilter.customEndDate);
    final dateLabel = dateRange != null
        ? '${DateFormat('dd MMM yyyy').format(dateRange.start)} – ${DateFormat('dd MMM yyyy').format(dateRange.end)}'
        : 'All Time';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level 2 filter bar: permits changing stream/city while inside detail view
        _buildCategoryWiseFilters(cwState, rawRecords),
        const SizedBox(height: 16),

        // Back button returns to 44 category cards with stream preserved
        TextButton.icon(
          onPressed: () {
            ref.read(categoryWiseLocalStateProvider.notifier).state =
                cwState.copyWith(clearCategory: true);
          },
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: Text(
            'Back to Categories',
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF0284C7)),
        ),
        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedCat.toUpperCase(),
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Payment Stream: $streamLabel  •  City: $cityLabel  •  Date: $dateLabel',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final cols = w >= 800 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 4 ? 2.2 : 1.8,
              children: [
                _buildStatCard(
                  title: 'Total Payments',
                  value: '$count',
                  sub: 'Matching payments',
                  color: const Color(0xFF0284C7),
                  icon: Icons.receipt_rounded,
                ),
                _buildStatCard(
                  title: 'Collected Revenue',
                  value: '₹${NumberFormat('#,##,###').format(collected)}',
                  sub: 'Verified received funds',
                  color: const Color(0xFF16A34A),
                  icon: Icons.payments_rounded,
                ),
                _buildStatCard(
                  title: 'Outstanding',
                  value: '₹${NumberFormat('#,##,###').format(outstanding)}',
                  sub: 'Owed debt (uncollected)',
                  color: const Color(0xFFEA580C),
                  icon: Icons.pending_actions_rounded,
                  isWarning: outstanding > 0,
                ),
                _buildStatCard(
                  title: 'Unique Providers / Users',
                  value: '${userIds.length}',
                  sub: 'Distinct entities',
                  color: const Color(0xFF8B5CF6),
                  icon: Icons.people_rounded,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),

        _buildSectionHeader(
          'PAYMENT DETAILS — $selectedCat',
          'Records matching category "$selectedCat" and stream "$streamLabel". Click any row to view drawer.',
        ),
        const SizedBox(height: 14),

        if (catRecords.isEmpty)
          _buildEmptyMessage(
            'No payments found for "$selectedCat" under "$streamLabel" with the active filters.',
          )
        else
          _CategoryDetailTable(records: catRecords, pageSize: 25),
      ],
    );
  }


  // =========================================================================
  // TAB 5: TRANSACTIONS LEDGER TABLE & PAGINATION
  // =========================================================================

  Widget _buildTransactionsTab(
    AsyncValue<RevenueAnalyticsData> analyticsAsync,
  ) {
    final pageIndex = ref.watch(revenueTransactionPageProvider);
    final pageSize = ref.watch(revenueTransactionPageSizeProvider);

    return analyticsAsync.when(
      data: (data) {
        final totalCount = data.allMatchingRecords.length;
        final start = pageIndex * pageSize;
        final end =
            (start + pageSize > totalCount) ? totalCount : start + pageSize;
        final pageItems =
            start < totalCount
                ? data.allMatchingRecords.sublist(start, end)
                : <PaymentRecord>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  'TRANSACTIONS LEDGER (${NumberFormat('#,##,###').format(totalCount)})',
                  'Click any transaction row to inspect complete payment, user, and reconciliation details.',
                ),
                Text(
                  'Showing ${start + 1}–$end of $totalCount',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (pageItems.isEmpty)
              _buildEmptyMessage('No transactions matching the active filters.')
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _hScrollController,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF8FAFC),
                    ),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 58,
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Transaction ID')),
                      DataColumn(label: Text('Stream')),
                      DataColumn(label: Text('User / Business')),
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('City')),
                      DataColumn(
                        label: Text('Amount (₹)', textAlign: TextAlign.right),
                      ),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('Source')),
                    ],
                    rows:
                        pageItems.map((r) {
                          return DataRow(
                            onSelectChanged: (_) {
                              ref
                                  .read(
                                    revenueSelectedRecordForDrawerProvider
                                        .notifier,
                                  )
                                  .state = r;
                            },
                            cells: [
                              DataCell(
                                Text(
                                  r.paymentDate != null
                                      ? DateFormat(
                                        'dd MMM yyyy',
                                      ).format(r.paymentDate!)
                                      : '—',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.transactionId,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.stream.shortName,
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.userName ?? '—',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  r.category,
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      r.city,
                                      style: GoogleFonts.poppins(fontSize: 12),
                                    ),
                                    if (r.cityConfidence ==
                                        DataConfidence.unknown)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4),
                                        child: Icon(
                                          Icons.help_outline_rounded,
                                          size: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  '₹${(r.isCollected ? r.collectedAmount : r.amount).toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        r.isCollected
                                            ? const Color(0xFF16A34A)
                                            : (r.isOutstanding
                                                ? const Color(0xFFEA580C)
                                                : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              DataCell(_buildStatusBadge(r.status)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r.sourceCollection,
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ),

            // Pagination Controls Footer
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Page ${pageIndex + 1} of ${(totalCount / pageSize).ceil() == 0 ? 1 : (totalCount / pageSize).ceil()}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed:
                      pageIndex > 0
                          ? () =>
                              ref
                                  .read(revenueTransactionPageProvider.notifier)
                                  .state = pageIndex - 1
                          : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton(
                  onPressed:
                      end < totalCount
                          ? () =>
                              ref
                                  .read(revenueTransactionPageProvider.notifier)
                                  .state = pageIndex + 1
                          : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        );
      },
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    final (bg, fg, label) = switch (status) {
      PaymentStatus.collected => (
        const Color(0xFFDCFCE7),
        const Color(0xFF16A34A),
        'Collected',
      ),
      PaymentStatus.outstanding => (
        const Color(0xFFFFEDD5),
        const Color(0xFFC2410C),
        'Outstanding',
      ),
      PaymentStatus.paymentAttempt => (
        const Color(0xFFF1F5F9),
        const Color(0xFF64748B),
        'Attempt',
      ),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF64748B), 'Unknown'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 6: RAZORPAY & SOURCE RECONCILIATION
  // =========================================================================

  Widget _buildReconciliationTab(
    AsyncValue<RevenueAnalyticsData> analyticsAsync,
  ) {
    return analyticsAsync.when(
      data:
          (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(
                'RAZORPAY & SOURCE RECONCILIATION',
                'Cross-ledger reconciliation between Firebase source documents, Google Sheets, and Razorpay',
              ),
              const SizedBox(height: 16),

              // Razorpay Not Connected Alert
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD97706),
                      size: 28,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Razorpay Direct API Integration Pending',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'This application does not currently connect directly to the Razorpay Payments API. All transactions are marked "Razorpay Not Connected" rather than claiming artificial match status. Real-time reconciliation will be enabled once webhook/API credentials are wired.',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: const Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Reconciliation Cards Grid
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildStatCard(
                    title: 'Firebase Collected Total',
                    value:
                        '₹${NumberFormat('#,##,###').format(data.totalCollectedRevenue)}',
                    sub: '${data.totalTransactions} recorded payments',
                    color: const Color(0xFF0284C7),
                    icon: Icons.cloud_done_rounded,
                  ),
                  _buildStatCard(
                    title: 'Razorpay Dashboard Total',
                    value: 'Not Connected',
                    sub: 'Requires Razorpay API connection',
                    color: const Color(0xFF94A3B8),
                    icon: Icons.account_balance_rounded,
                  ),
                  _buildStatCard(
                    title: 'Discrepancy / Gap',
                    value: 'Pending Connection',
                    sub: 'Cannot be determined without API',
                    color: const Color(0xFFEA580C),
                    icon: Icons.compare_arrows_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Google Sheets Reconciliation Note
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.table_chart_rounded,
                          color: Color(0xFF16A34A),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Google Sheets Historical Revenue Sync',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The application relies on backend Cloud Functions to synchronize historical payment transactions into Google Sheets tabs: '
                      'ActivePlan, ActivePlanwithPayment, propertiesrevenue, propertyinitiatedtransaction, Agent_Revenue, local_promotes_revenue, and hyd29paid.\n\n'
                      'Because this Admin Website client reads directly from Firestore, it only sees the latest entity state (users.totalAmount). '
                      'The canonical transaction ledger for multi-payment providers is retained in those Google Sheets to avoid double-counting.',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      loading:
          () => const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            ),
          ),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  // =========================================================================
  // TAB 7: PAYMENT LINK OPERATIONS (Preserved Existing Functionality)
  // =========================================================================

  Widget _buildLinkOperationsTab() {
    final dataAsync = ref.watch(paginatedPaymentProvider);
    final notifier = ref.watch(paginatedPaymentProvider.notifier);
    final isSuper = ref.watch(isSuperAdminProvider);
    final adminProfile = ref.watch(currentAdminProfileProvider).value;
    final currentAdminId = adminProfile?['admin_id'] ?? adminProfile?['id'];
    final String? statsFilterAdminId =
        isSuper
            ? ref.watch(selectedPaymentAdminFilterProvider)
            : currentAdminId;
    final statsAsync = ref.watch(paymentSalesStatsProvider(statsFilterAdminId));
    final adminsAsync = ref.watch(adminsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'PAYMENT LINK OPERATIONS & ACTIONS',
          'Send payment verification links directly to providers or manually mark transactions as paid.',
        ),
        const SizedBox(height: 16),

        // Super Admin Filter & Refresh
        if (isSuper) ...[
          adminsAsync.when(
            data: (adminsList) {
              final selectedAdminId = ref.watch(
                selectedPaymentAdminFilterProvider,
              );
              return Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedAdminId,
                    hint: Text(
                      'All Admins',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    onChanged: (val) {
                      ref
                          .read(selectedPaymentAdminFilterProvider.notifier)
                          .state = val;
                      ref
                          .read(paginatedPaymentProvider.notifier)
                          .fetchInitial();
                    },
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Admins'),
                      ),
                      ...adminsList.map((admin) {
                        final adminId = admin['admin_id'] ?? admin['id'];
                        return DropdownMenuItem<String?>(
                          value: adminId,
                          child: Text(
                            admin['name'] ?? admin['email'] ?? 'Unknown',
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
        ],

        // Sales Stats Section
        statsAsync.when(
          data:
              (stats) => GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                children: [
                  _buildStatCard(
                    title: 'Total Sales',
                    value: '₹${stats.totalSale.toStringAsFixed(0)}',
                    sub: 'Link sender records',
                    color: const Color(0xFF2563EB),
                    icon: Icons.payments_rounded,
                  ),
                  _buildStatCard(
                    title: 'This Month (30d)',
                    value: '₹${stats.thisMonthSale.toStringAsFixed(0)}',
                    sub: 'Past 30 days',
                    color: const Color(0xFF16A34A),
                    icon: Icons.calendar_today_rounded,
                  ),
                  _buildStatCard(
                    title: "Today's Sales",
                    value: '₹${stats.todaySale.toStringAsFixed(0)}',
                    sub: 'Today link payments',
                    color: const Color(0xFF0D9488),
                    icon: Icons.today_rounded,
                  ),
                  _buildStatCard(
                    title: "Yesterday's Sales",
                    value: '₹${stats.yesterdaySale.toStringAsFixed(0)}',
                    sub: 'Yesterday link payments',
                    color: const Color(0xFFEA580C),
                    icon: Icons.history_rounded,
                  ),
                ],
              ),
          loading:
              () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
          error: (e, _) => Text('Error loading link stats: $e'),
        ),
        const SizedBox(height: 24),

        // List of providers
        dataAsync.when(
          data: (users) {
            if (users.isEmpty)
              return _buildEmptyMessage('No provider payment records found.');
            return Column(
              children: [
                ...users.map((user) => _buildPaymentCard(context, user, ref)),
                _buildPaginationFooter(notifier),
              ],
            );
          },
          loading:
              () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ],
    );
  }

  // =========================================================================
  // TRANSACTION DETAIL DRAWER (Row Click Modal)
  // =========================================================================

  Widget _buildDetailDrawer(PaymentRecord r) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 480,
      child: Material(
        elevation: 24,
        color: Colors.white,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drawer Header
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: const BoxDecoration(color: Color(0xFF0F172A)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRANSACTION DETAILS',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          r.transactionId,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        ref
                            .read(
                              revenueSelectedRecordForDrawerProvider.notifier,
                            )
                            .state = null;
                      },
                    ),
                  ],
                ),
              ),

              // Drawer Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Amount',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '₹${r.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                          _buildStatusBadge(r.status),
                        ],
                      ),
                      const Divider(height: 32),

                      // Section 1: Payment Information
                      _buildDrawerSectionTitle('Payment Information'),
                      _buildDrawerField('Stream', r.stream.displayName),
                      _buildDrawerField('Transaction ID', r.transactionId),
                      _buildDrawerField(
                        'Razorpay ID',
                        r.razorpayPaymentId ?? 'N/A in Firebase doc',
                      ),
                      _buildDrawerField(
                        'Date',
                        r.paymentDate != null
                            ? DateFormat(
                              'dd MMM yyyy, hh:mm a',
                            ).format(r.paymentDate!)
                            : 'N/A',
                      ),
                      _buildDrawerField(
                        'Collected Portion',
                        '₹${r.collectedAmount.toStringAsFixed(2)}',
                      ),
                      _buildDrawerField(
                        'Outstanding Portion',
                        '₹${r.outstandingAmount.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 20),

                      // Section 2: Customer / Entity Information
                      _buildDrawerSectionTitle('Customer / Entity Information'),
                      _buildDrawerField('Name', r.userName ?? 'N/A'),
                      _buildDrawerField(
                        'User / Doc ID',
                        r.userId ?? r.sourceDocumentId,
                      ),
                      _buildDrawerField(
                        'Phone',
                        r.userPhone?.toString() ?? 'N/A',
                      ),
                      _buildDrawerField(
                        'City',
                        '${r.city} (${r.cityConfidence.label})',
                      ),
                      _buildDrawerField('Category', r.category),
                      const SizedBox(height: 20),

                      // Section 3: Firebase Source & Data Scope
                      _buildDrawerSectionTitle('Firebase Source & Integrity'),
                      _buildDrawerField('Collection', r.sourceCollection),
                      _buildDrawerField('Document ID', r.sourceDocumentId),
                      _buildDrawerField('Data Scope', r.dataScope.label),
                      _buildDrawerField(
                        'Reconciliation',
                        r.reconciliationStatus.displayName,
                      ),
                      if (r.notes != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            r.notes!,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0284C7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF64748B),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeaderCell(
    String label, {
    TextAlign align = TextAlign.left,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        label,
        textAlign: align,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF475569),
        ),
      ),
    );
  }

  Color _colorForStream(PaymentStream s) {
    switch (s) {
      case PaymentStream.providerSubscription:
        return const Color(0xFF0284C7);
      case PaymentStream.payPerLeadOutstanding:
        return const Color(0xFFEA580C);
      case PaymentStream.tenantContact:
        return const Color(0xFF2563EB);
      case PaymentStream.propertyListing:
        return const Color(0xFF8B5CF6);
      case PaymentStream.agentVerification:
        return const Color(0xFFD97706);
      case PaymentStream.localPromotion:
        return const Color(0xFFDB2777);
      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _buildEmptyMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, size: 36, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(
        'Error loading payments data: $error',
        style: GoogleFonts.poppins(color: Colors.red.shade800),
      ),
    );
  }

  // --- Preserved Link Operations Helpers ---

  Widget _buildPaginationFooter(PaginatedPaymentNotifier notifier) {
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

  Widget _buildPaymentCard(
    BuildContext context,
    Map<String, dynamic> user,
    WidgetRef ref,
  ) {
    final bool paymentLinkSend = user['paymentLinkSend'] ?? false;
    final num totalAmount = user['totalAmount'] ?? 0;
    final String planDuration = user['paymentPlanDuration'] ?? 'N/A';
    final String transactionId = user['transactionId'] ?? '';
    final num paymentCount = user['paymentCount'] ?? 0;
    final bool hasPaid = paymentCount > 0 || transactionId.isNotEmpty;

    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusinessProfilePage(businessData: user),
            ),
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['businessname'] ??
                        user['firstname'] ??
                        user['name'] ??
                        'Unknown User',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user['phone']?.toString() ?? 'No Phone',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Info',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (hasPaid) ...[
                    Text(
                      '₹$totalAmount • $planDuration',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'TXN: $transactionId',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ] else ...[
                    Text(
                      paymentLinkSend
                          ? 'Link sent • Unpaid'
                          : 'No payments recorded',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasPaid)
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
                      child: Text(
                        'Paid',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    )
                  else ...[
                    ElevatedButton.icon(
                      onPressed:
                          paymentLinkSend
                              ? null
                              : () => _sendPaymentLink(user['id'], ref),
                      icon: Icon(
                        paymentLinkSend ? Icons.mark_email_read : Icons.send,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        paymentLinkSend ? 'Link Sent' : 'Send Link',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            paymentLinkSend
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed:
                          () => _showMarkAsPaidDialog(context, user['id'], ref),
                      icon: const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: Color(0xFF16A34A),
                      ),
                      label: Text(
                        'Mark Paid',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF16A34A),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendPaymentLink(String userId, WidgetRef ref) async {
    try {
      final adminProfile = ref.read(currentAdminProfileProvider).value;
      final senderId =
          adminProfile?['admin_id'] ?? adminProfile?['id'] ?? 'Unknown';
      final senderName = adminProfile?['name'] ?? 'Unknown';

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'paymentLinkSend': true,
        'paymentLinkSenderId': senderId,
        'paymentLinkSenderName': senderName,
        'paymentLinkSentAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Payment link sent successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      ref.read(paginatedPaymentProvider.notifier).fetchInitial();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send link: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showMarkAsPaidDialog(
    BuildContext context,
    String userId,
    WidgetRef ref,
  ) async {
    final amountController = TextEditingController(text: '500');
    final txnController = TextEditingController(
      text: 'TXN${DateTime.now().millisecondsSinceEpoch}',
    );
    String selectedDuration = '1 Month';
    bool isSaving = false;

    return showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'Mark as Paid',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount (₹)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedDuration,
                        decoration: InputDecoration(
                          labelText: 'Plan Duration',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: '1 Month',
                            child: Text('1 Month'),
                          ),
                          DropdownMenuItem(
                            value: '3 Months',
                            child: Text('3 Months'),
                          ),
                          DropdownMenuItem(
                            value: '6 Months',
                            child: Text('6 Months'),
                          ),
                          DropdownMenuItem(
                            value: '1 Year',
                            child: Text('1 Year'),
                          ),
                        ],
                        onChanged: (v) => setState(() => selectedDuration = v!),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: txnController,
                        decoration: InputDecoration(
                          labelText: 'Transaction ID',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      if (isSaving) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    ElevatedButton(
                      onPressed:
                          isSaving
                              ? null
                              : () async {
                                final amountStr = amountController.text.trim();
                                final txnId = txnController.text.trim();
                                if (amountStr.isEmpty || txnId.isEmpty) return;
                                final amount = double.tryParse(amountStr);
                                if (amount == null || amount <= 0) return;

                                setState(() => isSaving = true);
                                try {
                                  final adminProfile =
                                      ref
                                          .read(currentAdminProfileProvider)
                                          .value;
                                  final senderId =
                                      adminProfile?['admin_id'] ??
                                      adminProfile?['id'] ??
                                      'Unknown';
                                  final senderName =
                                      adminProfile?['name'] ?? 'Unknown';

                                  await FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(userId)
                                      .update({
                                        'paymentLinkSend': true,
                                        'paymentCount': FieldValue.increment(1),
                                        'totalAmount': FieldValue.increment(
                                          amount,
                                        ),
                                        'overaltotalamount':
                                            FieldValue.increment(amount),
                                        'paymentPlanDuration': selectedDuration,
                                        'transactionId': txnId,
                                        'lastPaymentAt':
                                            FieldValue.serverTimestamp(),
                                        'paymentPaidAt':
                                            FieldValue.serverTimestamp(),
                                        'paymentLinkSenderId': senderId,
                                        'paymentLinkSenderName': senderName,
                                      });

                                  ref.invalidate(paymentSalesStatsProvider);
                                  ref
                                      .read(paginatedPaymentProvider.notifier)
                                      .fetchInitial();
                                  ref.invalidate(revenueRawRecordsProvider);

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Payment recorded successfully!',
                                          style: GoogleFonts.poppins(),
                                        ),
                                        backgroundColor: const Color(
                                          0xFF16A34A,
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (context.mounted)
                                    setState(() => isSaving = false);
                                }
                              },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(isSaving ? 'Saving...' : 'Confirm Paid'),
                    ),
                  ],
                ),
          ),
    );
  }
}

// ===========================================================================
// _CategoryDetailTable
// Stateful sub-widget for the category drill-down payment table.
// Keeps its own page index so it doesn't pollute the outer state class.
// ===========================================================================
class _CategoryDetailTable extends ConsumerStatefulWidget {
  final List<PaymentRecord> records;
  final int pageSize;

  const _CategoryDetailTable({required this.records, required this.pageSize});

  @override
  ConsumerState<_CategoryDetailTable> createState() =>
      _CategoryDetailTableState();
}

class _CategoryDetailTableState extends ConsumerState<_CategoryDetailTable> {
  int _page = 0;

  @override
  void didUpdateWidget(_CategoryDetailTable old) {
    super.didUpdateWidget(old);
    // Reset to page 0 if the record list changed (filter/category changed).
    if (old.records != widget.records) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.records.length;
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize > total) ? total : start + widget.pageSize;
    final pageItems =
        start < total ? widget.records.sublist(start, end) : <PaymentRecord>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$total records total',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
            Text(
              'Showing ${start + 1}–$end',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              dataRowMinHeight: 50,
              dataRowMaxHeight: 56,
              columns: [
                DataColumn(
                  label: Text('Date',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('Transaction ID',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('Stream',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('User / Business',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('Phone',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('City',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('Amount (\u20B9)',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('Status',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
                DataColumn(
                  label: Text('Source',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: const Color(0xFF475569)))),
              ],
              rows: pageItems.map((r) {
                return DataRow(
                  onSelectChanged: (_) {
                    ref
                        .read(revenueSelectedRecordForDrawerProvider.notifier)
                        .state = r;
                  },
                  cells: [
                    DataCell(Text(
                      r.paymentDate != null
                          ? DateFormat('dd MMM yyyy').format(r.paymentDate!)
                          : '—',
                      style: GoogleFonts.poppins(fontSize: 12),
                    )),
                    DataCell(Text(
                      r.transactionId,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF0284C7),
                      ),
                    )),
                    DataCell(Text(
                      r.stream.shortName,
                      style: GoogleFonts.poppins(fontSize: 12),
                    )),
                    DataCell(Text(
                      r.userName ?? '—',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w500),
                    )),
                    DataCell(Text(
                      r.userPhone?.toString() ?? '—',
                      style: GoogleFonts.poppins(fontSize: 12),
                    )),
                    DataCell(Text(
                      r.city,
                      style: GoogleFonts.poppins(fontSize: 12),
                    )),
                    DataCell(Text(
                      '\u20B9${(r.isCollected ? r.collectedAmount : r.amount).toStringAsFixed(0)}',
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: r.isCollected
                            ? const Color(0xFF16A34A)
                            : (r.isOutstanding
                                ? const Color(0xFFEA580C)
                                : const Color(0xFF64748B)),
                      ),
                    )),
                    DataCell(_buildStatusBadgeCat(r.status)),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.sourceCollection,
                        style: GoogleFonts.poppins(
                            fontSize: 10, color: const Color(0xFF475569)),
                      ),
                    )),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Page ${_page + 1} of ${total == 0 ? 1 : ((total - 1) ~/ widget.pageSize) + 1}',
              style: GoogleFonts.poppins(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              onPressed:
                  end < total ? () => setState(() => _page++) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadgeCat(PaymentStatus status) {
    final (bg, fg, label) = switch (status) {
      PaymentStatus.collected => (
          const Color(0xFFDCFCE7),
          const Color(0xFF16A34A),
          'Collected',
        ),
      PaymentStatus.outstanding => (
          const Color(0xFFFFEDD5),
          const Color(0xFFC2410C),
          'Outstanding',
        ),
      PaymentStatus.paymentAttempt => (
          const Color(0xFFF1F5F9),
          const Color(0xFF64748B),
          'Attempt',
        ),
      _ => (const Color(0xFFF1F5F9), const Color(0xFF64748B), 'Unknown'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ===========================================================================
// _CatAccum — in-memory accumulator for category grouping
// ===========================================================================
class _CatAccum {
  final String displayName;
  int transactionCount = 0;
  double collectedRevenue = 0.0;
  double outstandingAmount = 0.0;
  final Set<String> uniqueUserIds = {};

  _CatAccum(this.displayName);

  void add(PaymentRecord r) {
    if (r.userId != null) uniqueUserIds.add(r.userId!);
    if (r.isCollected) {
      transactionCount++;
      collectedRevenue += r.collectedAmount;
    } else if (r.isOutstanding) {
      outstandingAmount += r.outstandingAmount;
    }
  }
}

