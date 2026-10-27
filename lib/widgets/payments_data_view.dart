import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/constants/business_categories.dart';
import 'package:skazo_admin/models/payment_record.dart';
import 'package:skazo_admin/models/revenue_analytics_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/revenue_providers.dart';
import 'package:skazo_admin/utils/csv_export_helper.dart';

/// CEO-Level Financial Command Center & Razorpay Reconciliation Dashboard
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
    final syncMetaSnap = ref.watch(revenueSyncMetadataProvider).value;
    final isSyncing = ref.watch(revenueIsSyncingProvider);

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
                _buildTopHeader(context, analyticsAsync, syncMetaSnap?.data(), isSyncing),
                const SizedBox(height: 20),

                // Navigation Tabs
                _buildTabsBar(activeTab),
                const SizedBox(height: 20),

                // Global Filter Bar (shown on analytics tabs)
                if (activeTab != RevenueDashboardTab.linkSender &&
                    activeTab != RevenueDashboardTab.syncAudit) ...[
                  _buildGlobalFilterBar(currentFilter),
                  const SizedBox(height: 24),
                ],

                // Tab Content Switcher
                switch (activeTab) {
                  RevenueDashboardTab.overview => _buildOverviewTab(analyticsAsync),
                  RevenueDashboardTab.streams => _buildStreamsTab(analyticsAsync),
                  RevenueDashboardTab.cities => _buildCitiesTab(analyticsAsync),
                  RevenueDashboardTab.categories => _buildCategoriesTab(analyticsAsync),
                  RevenueDashboardTab.transactions => _buildTransactionsTab(analyticsAsync),
                  RevenueDashboardTab.reconciliation => _buildReconciliationTab(analyticsAsync),
                  RevenueDashboardTab.linkSender => _buildLinkOperationsTab(),
                  RevenueDashboardTab.refunds => _buildRefundsTab(analyticsAsync),
                  RevenueDashboardTab.settlements => _buildSettlementsTab(analyticsAsync),
                  RevenueDashboardTab.syncAudit => _buildSyncAuditTab(analyticsAsync, syncMetaSnap?.data()),
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
    Map<String, dynamic>? syncMeta,
    bool isSyncing,
  ) {
    final bool isConfigured = syncMeta?['isConfigured'] == true;
    final String syncStatus = syncMeta?['syncStatus']?.toString() ?? 'idle';
    final DateTime? lastSync = syncMeta?['lastSuccessfulRazorpaySyncAt'] is Timestamp
        ? (syncMeta!['lastSuccessfulRazorpaySyncAt'] as Timestamp).toDate()
        : null;

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;

    if (isSyncing || syncStatus == 'in_progress') {
      badgeColor = const Color(0xFFD97706);
      badgeText = 'RAZORPAY SYNCING...';
      badgeIcon = Icons.sync_rounded;
    } else if (isConfigured && (syncStatus == 'success' || syncStatus == 'completed')) {
      badgeColor = const Color(0xFF16A34A);
      badgeText = 'RAZORPAY CONNECTED';
      badgeIcon = Icons.check_circle_rounded;
    } else if (syncStatus == 'config_required' || !isConfigured) {
      badgeColor = const Color(0xFF7C3AED);
      badgeText = 'CONFIGURATION REQUIRED';
      badgeIcon = Icons.admin_panel_settings_rounded;
    } else if (syncStatus == 'failed' || syncStatus == 'error') {
      badgeColor = const Color(0xFFE11D48);
      badgeText = 'RAZORPAY CONNECTION ERROR';
      badgeIcon = Icons.error_outline_rounded;
    } else {
      badgeColor = const Color(0xFFE11D48);
      badgeText = 'SYNC REQUIRED';
      badgeIcon = Icons.warning_amber_rounded;
    }

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
                        'PAYMENTS & REVENUE COMMAND CENTER',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            badgeText,
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lastSync != null
                      ? 'Verified Razorpay financial ledger • Last synchronized: ${DateFormat('dd MMM yyyy, HH:mm').format(lastSync)}'
                      : 'Verified Razorpay financial ledger • Gateway synchronization required for official status.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFFCBD5E1),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Sync Razorpay Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 18),
                label: Text(
                  isSyncing ? 'Syncing...' : 'Sync Razorpay',
                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: isSyncing
                    ? null
                    : () async {
                        ref.read(revenueIsSyncingProvider.notifier).state = true;
                        try {
                          final repo = ref.read(revenueRepositoryProvider);
                          final res = await repo.triggerRazorpaySync();
                          ref.invalidate(revenueRawRecordsProvider);
                          ref.invalidate(revenueSyncMetadataProvider);
                          ref.invalidate(revenueRefundsProvider);
                          ref.invalidate(revenueSettlementsProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  res['message'] ?? 'Razorpay sync triggered successfully.',
                                  style: GoogleFonts.poppins(),
                                ),
                                backgroundColor: res['status'] == 'error'
                                    ? Colors.red
                                    : const Color(0xFF16A34A),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Sync error: $e', style: GoogleFonts.poppins()),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } finally {
                          ref.read(revenueIsSyncingProvider.notifier).state = false;
                        }
                      },
              ),
              // Export CSV Button
              analyticsAsync.maybeWhen(
                data: (data) => ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: Text(
                    'Export CSV',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    CsvExportHelper.downloadPaymentRecordsCsv(
                      data.allMatchingRecords,
                      filenamePrefix: 'SKAZO_Financial_Transactions_${DateFormat('yyyyMMdd').format(DateTime.now())}',
                    );
                  },
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabsBar(RevenueDashboardTab activeTab) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: RevenueDashboardTab.values.map((tab) {
            final isSelected = tab == activeTab;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () {
                  ref.read(revenueActiveTabProvider.notifier).state = tab;
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getTabIcon(tab),
                        size: 16,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tab.title,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
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

  IconData _getTabIcon(RevenueDashboardTab tab) {
    switch (tab) {
      case RevenueDashboardTab.overview:
        return Icons.dashboard_rounded;
      case RevenueDashboardTab.streams:
        return Icons.account_tree_rounded;
      case RevenueDashboardTab.cities:
        return Icons.location_city_rounded;
      case RevenueDashboardTab.categories:
        return Icons.category_rounded;
      case RevenueDashboardTab.transactions:
        return Icons.receipt_long_rounded;
      case RevenueDashboardTab.reconciliation:
        return Icons.balance_rounded;
      case RevenueDashboardTab.linkSender:
        return Icons.link_rounded;
      case RevenueDashboardTab.refunds:
        return Icons.undo_rounded;
      case RevenueDashboardTab.settlements:
        return Icons.account_balance_rounded;
      case RevenueDashboardTab.syncAudit:
        return Icons.security_rounded;
    }
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Search Input
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.poppins(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search by Txn ID, Razorpay ID, Customer Name, Phone, or City...',
                      hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF94A3B8)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(revenueFilterProvider.notifier).state =
                                    filter.copyWith(searchQuery: '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF0284C7)),
                      ),
                    ),
                    onChanged: (val) {
                      ref.read(revenueFilterProvider.notifier).state =
                          filter.copyWith(searchQuery: val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Date Range Preset Dropdown
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<RevenueDateRangeOption>(
                    value: filter.dateRangeOption,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                    onChanged: (opt) {
                      if (opt != null) {
                        ref.read(revenueFilterProvider.notifier).state =
                            filter.copyWith(dateRangeOption: opt);
                      }
                    },
                    items: RevenueDateRangeOption.values.map((opt) {
                      return DropdownMenuItem(
                        value: opt,
                        child: Text(opt.label),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Reset All Filters Button
              IconButton(
                tooltip: 'Reset Filters',
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                onPressed: () {
                  _searchController.clear();
                  ref.read(revenueFilterProvider.notifier).state = const RevenueFilter();
                  ref.invalidate(revenueRawRecordsProvider);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Secondary Filter Chips (Stream, Status, Reconciliation)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _filterBarScrollController,
            child: Row(
              children: [
                // Stream Filter Chip
                _buildFilterDropdown<PaymentStream>(
                  label: 'Stream',
                  currentValue: filter.selectedStream,
                  items: PaymentStream.values
                      // [PPL DISABLED] Pay Per Lead streams excluded from filter dropdown
                      .where((s) =>
                          s != PaymentStream.payPerLeadOutstanding &&
                          s != PaymentStream.payPerLeadCollected)
                      .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.displayName),
                  )).toList(),
                  onChanged: (val) {
                    ref.read(revenueFilterProvider.notifier).state =
                        filter.copyWith(selectedStream: val, clearStream: val == null);
                  },
                ),
                const SizedBox(width: 8),

                // Payment Status Filter Chip
                _buildFilterDropdown<PaymentStatus>(
                  label: 'Status',
                  currentValue: filter.selectedStatus,
                  items: PaymentStatus.values.map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s.displayName),
                  )).toList(),
                  onChanged: (val) {
                    ref.read(revenueFilterProvider.notifier).state =
                        filter.copyWith(selectedStatus: val, clearStatus: val == null);
                  },
                ),
                const SizedBox(width: 8),

                // Reconciliation Filter Chip
                _buildFilterDropdown<ReconciliationStatus>(
                  label: 'Reconciliation',
                  currentValue: filter.selectedReconciliationStatus,
                  items: ReconciliationStatus.values.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.displayName),
                  )).toList(),
                  onChanged: (val) {
                    ref.read(revenueFilterProvider.notifier).state =
                        filter.copyWith(selectedReconciliationStatus: val, clearReconciliation: val == null);
                  },
                ),
                const SizedBox(width: 8),

                // Active City Filter Indicator
                if (filter.selectedCity != null)
                  Chip(
                    backgroundColor: const Color(0xFFE0F2FE),
                    label: Text(
                      'City: ${filter.selectedCity}',
                      style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF0284C7), fontWeight: FontWeight.w600),
                    ),
                    deleteIcon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFF0284C7)),
                    onDeleted: () {
                      ref.read(revenueFilterProvider.notifier).state =
                          filter.copyWith(clearCity: true);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T? currentValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: currentValue != null ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: currentValue != null ? const Color(0xFF3B82F6) : const Color(0xFFE2E8F0),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: currentValue,
          hint: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F172A),
          ),
          onChanged: onChanged,
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text('All $label', style: GoogleFonts.poppins(fontSize: 12)),
            ),
            ...items,
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: OVERVIEW TAB (CEO Financial Dashboard)
  // =========================================================================

  Widget _buildOverviewTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Warnings Banner
          if (data.dataWarnings.isNotEmpty) ...[
            _buildDataWarningsBanner(data.dataWarnings),
            const SizedBox(height: 20),
          ],

          // CEO Top KPI Grid
          _buildCeoKpiGrid(data),
          const SizedBox(height: 28),

          // Streams Summary Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                'REVENUE STREAMS BREAKDOWN',
                'Gross collected revenue vs outstanding obligations across streams',
              ),
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('View Stream Details', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: () {
                  ref.read(revenueActiveTabProvider.notifier).state = RevenueDashboardTab.streams;
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStreamBreakdownTable(data),
          const SizedBox(height: 28),

          // Geographic Distribution Preview
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader(
                'TOP MARKETS / CITY ATTRIBUTION',
                'Geographic distribution of collected funds and customer concentration',
              ),
              TextButton.icon(
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('View All Cities', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                onPressed: () {
                  ref.read(revenueActiveTabProvider.notifier).state = RevenueDashboardTab.cities;
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCityBreakdownTable(data, limit: 5),
        ],
      ),
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(60),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildDataWarningsBanner(List<String> warnings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                'Financial Data Quality & Synchronization Alerts',
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF92400E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...warnings.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        w,
                        style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF78350F)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCeoKpiGrid(RevenueAnalyticsData data) {
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
              title: 'TOTAL COLLECTED',
              value: '₹${NumberFormat('#,##,###').format(data.totalCollectedRevenue)}',
              sub: 'Verified captured revenue',
              color: const Color(0xFF0284C7),
              icon: Icons.account_balance_wallet_rounded,
            ),
            _buildStatCard(
              title: 'NET COLLECTION',
              value: '₹${NumberFormat('#,##,###').format(data.netCollectedRevenue)}',
              sub: 'Collected minus refunds',
              color: const Color(0xFF16A34A),
              icon: Icons.monetization_on_rounded,
            ),
            // [PPL DISABLED] Pay Per Lead outstanding card disabled
            /*
            _buildStatCard(
              title: 'OUTSTANDING (PPL)',
              value: '₹${NumberFormat('#,##,###').format(data.outstandingPayPerLead)}',
              sub: 'Owed to SKAZO (uncollected debt)',
              color: const Color(0xFFEA580C),
              icon: Icons.pending_actions_rounded,
            ),
            */
            _buildStatCard(
              title: 'TOTAL REFUNDED',
              value: '₹${NumberFormat('#,##,###').format(data.totalRefunded)}',
              sub: 'Deducted from gross collection',
              color: const Color(0xFFDC2626),
              icon: Icons.undo_rounded,
            ),
            _buildStatCard(
              title: 'TODAY',
              value: '₹${NumberFormat('#,##,###').format(data.todayRevenue)}',
              sub: 'Collected today',
              color: const Color(0xFF0D9488),
              icon: Icons.today_rounded,
            ),
            _buildStatCard(
              title: 'THIS WEEK',
              value: '₹${NumberFormat('#,##,###').format(data.thisWeekRevenue)}',
              sub: 'Current calendar week',
              color: const Color(0xFF4F46E5),
              icon: Icons.view_week_rounded,
            ),
            _buildStatCard(
              title: 'THIS MONTH',
              value: '₹${NumberFormat('#,##,###').format(data.thisMonthRevenue)}',
              sub: 'Current calendar month',
              color: const Color(0xFF0891B2),
              icon: Icons.calendar_month_rounded,
            ),
            _buildStatCard(
              title: 'THIS YEAR',
              value: '₹${NumberFormat('#,##,###').format(data.thisYearRevenue)}',
              sub: 'Current fiscal/calendar year',
              color: const Color(0xFF9333EA),
              icon: Icons.calendar_today_rounded,
            ),
            _buildStatCard(
              title: 'TRANSACTION COUNT',
              value: '${data.totalTransactions}',
              sub: 'Successful captured payments',
              color: const Color(0xFF334155),
              icon: Icons.receipt_long_rounded,
            ),
            _buildStatCard(
              title: 'FAILED PAYMENTS',
              value: '${data.failedPaymentsCount}',
              sub: 'Failed or cancelled attempts',
              color: const Color(0xFF991B1B),
              icon: Icons.cancel_rounded,
            ),
            _buildStatCard(
              title: 'PAYMENT SUCCESS RATE',
              value: '${data.paymentSuccessRate.toStringAsFixed(1)}%',
              sub: 'Checkout completion ratio',
              color: const Color(0xFF059669),
              icon: Icons.check_circle_outline_rounded,
            ),
            _buildStatCard(
              title: 'RECONCILIATION',
              value: data.reconciliationSummary.matchedCount > 0
                  ? '${data.reconciliationSummary.matchedCount} Matched'
                  : 'Sync Required',
              sub: '${data.reconciliationSummary.needsReviewCount} discrepancies flag',
              color: data.reconciliationSummary.needsReviewCount > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF2563EB),
              icon: Icons.balance_rounded,
            ),
          ],
        );
      },
    );
  }

  // =========================================================================
  // TAB 2: REVENUE STREAMS TAB
  // =========================================================================

  Widget _buildStreamsTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'REVENUE STREAMS & OBLIGATIONS',
            'Canonical SKAZO revenue streams separating collected revenue from outstanding receivables',
          ),
          const SizedBox(height: 16),
          _buildStreamBreakdownTable(data, showAllColumns: true),
        ],
      ),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildStreamBreakdownTable(RevenueAnalyticsData data, {bool showAllColumns = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(label: Text('STREAM', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('TRANSACTIONS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('COLLECTED REVENUE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('OUTSTANDING', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              if (showAllColumns)
                DataColumn(label: Text('REFUNDED', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('NET REVENUE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('% OF TOTAL', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('ACTION', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
            rows: data.streamBreakdown.map((item) {
              final isPplOutstanding = item.stream == PaymentStream.payPerLeadOutstanding;

              return DataRow(
                cells: [
                  DataCell(
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPplOutstanding ? const Color(0xFFEA580C) : const Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.stream.displayName,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isPplOutstanding ? const Color(0xFFEA580C) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(Text('${item.transactionCount}', style: GoogleFonts.poppins(fontSize: 13))),
                  DataCell(
                    Text(
                      '₹${NumberFormat('#,##,###').format(item.collectedRevenue)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.collectedRevenue > 0 ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${NumberFormat('#,##,###').format(item.outstandingAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: item.outstandingAmount > 0 ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (showAllColumns)
                    DataCell(
                      Text(
                        '₹${NumberFormat('#,##,###').format(item.refundedAmount)}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: item.refundedAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  DataCell(
                    Text(
                      '₹${NumberFormat('#,##,###').format(item.netAmount)}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${item.revenuePercentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 60,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: (item.revenuePercentage / 100.0).clamp(0.0, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () {
                        ref.read(revenueFilterProvider.notifier).state =
                            ref.read(revenueFilterProvider).copyWith(selectedStream: item.stream);
                        ref.read(revenueActiveTabProvider.notifier).state =
                            RevenueDashboardTab.transactions;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'View Ledgers',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
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
    );
  }

  // =========================================================================
  // TAB 3: CITY WISE TAB
  // =========================================================================

  Widget _buildCitiesTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data: (data) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'CITY / GEOGRAPHIC DISTRIBUTION',
            'Attribution of collections, outstanding balances, and paying customer accounts across cities',
          ),
          const SizedBox(height: 16),
          _buildCityBreakdownTable(data),
        ],
      ),
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildCityBreakdownTable(RevenueAnalyticsData data, {int? limit}) {
    final list = limit != null ? data.cityBreakdown.take(limit).toList() : data.cityBreakdown;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(label: Text('CITY', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('PAYING USERS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('TRANSACTIONS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('COLLECTED REVENUE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('OUTSTANDING', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('REFUNDED', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('NET REVENUE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('AVG PAYMENT', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('ACTION', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
            rows: list.map((item) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      item.city,
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                    ),
                  ),
                  DataCell(Text('${item.uniqueUsers}', style: GoogleFonts.poppins(fontSize: 13))),
                  DataCell(Text('${item.transactionCount}', style: GoogleFonts.poppins(fontSize: 13))),
                  DataCell(
                    Text(
                      '₹${NumberFormat('#,##,###').format(item.collectedRevenue)}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF16A34A)),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${NumberFormat('#,##,###').format(item.outstandingAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: item.outstandingAmount > 0 ? const Color(0xFFEA580C) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${NumberFormat('#,##,###').format(item.refundedAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: item.refundedAmount > 0 ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      '₹${NumberFormat('#,##,###').format(item.netAmount)}',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  DataCell(
                    Text('₹${item.averagePayment.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontSize: 13)),
                  ),
                  DataCell(
                    InkWell(
                      onTap: () {
                        ref.read(revenueFilterProvider.notifier).state =
                            ref.read(revenueFilterProvider).copyWith(selectedCity: item.city);
                        ref.read(revenueActiveTabProvider.notifier).state =
                            RevenueDashboardTab.transactions;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Filter City',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
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
    );
  }

  // =========================================================================
  // TAB 4: CATEGORY WISE TAB (All 44 Canonical Categories Preserved)
  // =========================================================================

  Widget _buildCategoriesTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    final localState = ref.watch(categoryWiseLocalStateProvider);
    final rawAsync = ref.watch(revenueRawRecordsProvider);

    return rawAsync.when(
      data: (allRecords) {
        // If user drilled into a specific category, show details table
        if (localState.selectedCategory != null) {
          return _buildCategoryDetailView(allRecords, localState.selectedCategory!);
        }

        // Otherwise show all 44 canonical category cards
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'CATEGORY WISE REVENUE',
              'All 44 canonical SKAZO service & business categories with revenue attribution',
            ),
            const SizedBox(height: 16),
            _buildAllCategoryCardsGrid(allRecords),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildAllCategoryCardsGrid(List<PaymentRecord> records) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final int crossAxisCount = w > 1200 ? 4 : (w > 800 ? 3 : 2);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.8,
          ),
          itemCount: kAllCanonicalCategories.length,
          itemBuilder: (context, index) {
            final categoryName = kAllCanonicalCategories[index];
            final matching = records.where((r) => _recordMatchesCategory(r, categoryName)).toList();

            final int collectedPaise = matching
                .where((r) => r.isCollected)
                .fold(0, (acc, r) => acc + r.collectedAmountPaise);
            final int outstandingPaise = matching
                .where((r) => r.isOutstanding)
                .fold(0, (acc, r) => acc + r.outstandingAmountPaise);

            final double collected = collectedPaise / 100.0;
            final double outstanding = outstandingPaise / 100.0;
            final int txnCounts = matching.where((r) => r.isCollected).length;

            return InkWell(
              onTap: () {
                ref.read(categoryWiseLocalStateProvider.notifier).state =
                    ref.read(categoryWiseLocalStateProvider).copyWith(selectedCategory: categoryName);
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
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            categoryName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$txnCounts txns',
                            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${NumberFormat('#,##,###').format(collected)}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: collected > 0 ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (outstanding > 0)
                          Text(
                            '₹${NumberFormat('#,##,###').format(outstanding)} owed (PPL)',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEA580C), fontWeight: FontWeight.w500),
                          ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Drilldown to records', style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF0284C7))),
                        const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF0284C7)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryDetailView(List<PaymentRecord> allRecords, String categoryName) {
    final matching = allRecords.where((r) => _recordMatchesCategory(r, categoryName)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                ref.read(categoryWiseLocalStateProvider.notifier).state =
                    ref.read(categoryWiseLocalStateProvider).copyWith(clearCategory: true);
              },
            ),
            const SizedBox(width: 8),
            _buildSectionHeader(
              'CATEGORY: $categoryName',
              'Listing ${matching.length} transactions associated with $categoryName',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _CategoryDetailTable(records: matching, pageSize: 25),
      ],
    );
  }

  bool _recordMatchesCategory(PaymentRecord r, String canonicalCat) {
    final cat = r.category.toLowerCase().trim();
    final canonical = canonicalCat.toLowerCase().trim();
    if (cat.isEmpty || cat == 'unmapped') return false;
    return cat.contains(canonical);
  }

  // =========================================================================
  // TAB 5: TRANSACTIONS LEDGER TAB
  // =========================================================================

  Widget _buildTransactionsTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data: (data) {
        final records = data.allMatchingRecords;
        final page = ref.watch(revenueTransactionPageProvider);
        final pageSize = ref.watch(revenueTransactionPageSizeProvider);
        final total = records.length;
        final start = page * pageSize;
        final end = (start + pageSize > total) ? total : start + pageSize;
        final pageItems = start < total ? records.sublist(start, end) : <PaymentRecord>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  'FINANCIAL TRANSACTIONS LEDGER',
                  'Audited immutable financial records verified against Razorpay gateway states',
                ),
                Text(
                  'Showing ${start + 1}–$end of $total transactions',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Main Transactions Data Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _hScrollController,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: [
                      DataColumn(label: Text('DATE / TIME', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('TRANSACTION ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('RAZORPAY ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('CUSTOMER', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('STREAM', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('CITY', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('AMOUNT', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('NET AMOUNT', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('METHOD', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('STATUS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('RECONCILIATION', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('ACTION', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                    rows: pageItems.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              r.paymentDate != null
                                  ? DateFormat('dd MMM yyyy, HH:mm').format(r.paymentDate!)
                                  : 'N/A',
                              style: GoogleFonts.poppins(fontSize: 12.5),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.transactionId,
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.razorpayPaymentId ?? '—',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: r.razorpayPaymentId != null ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          DataCell(
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  r.userName ?? 'Customer',
                                  style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (r.userPhone != null)
                                  Text(
                                    '${r.userPhone}',
                                    style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                                  ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.stream.shortName,
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                              ),
                            ),
                          ),
                          DataCell(Text(r.city, style: GoogleFonts.poppins(fontSize: 12.5))),
                          DataCell(
                            Text(
                              '₹${r.amount.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataCell(
                            Text(
                              '₹${r.netCollectedAmount.toStringAsFixed(0)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: r.isCollected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              (r.paymentMethod ?? 'unknown').toUpperCase(),
                              style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                            ),
                          ),
                          DataCell(_buildStatusBadge(r.status)),
                          DataCell(_buildReconciliationBadge(r.reconciliationStatus)),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.visibility_rounded, size: 18, color: Color(0xFF0284C7)),
                              tooltip: 'Inspect Transaction',
                              onPressed: () {
                                ref.read(revenueSelectedRecordForDrawerProvider.notifier).state = r;
                              },
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pagination Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${page + 1} of ${(total / pageSize).ceil().clamp(1, 9999)}',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: page > 0
                          ? () {
                              ref.read(revenueTransactionPageProvider.notifier).state = page - 1;
                            }
                          : null,
                      child: const Text('Previous'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: end < total
                          ? () {
                              ref.read(revenueTransactionPageProvider.notifier).state = page + 1;
                            }
                          : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  // =========================================================================
  // TAB 6: RAZORPAY RECONCILIATION TAB
  // =========================================================================

  Widget _buildReconciliationTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data: (data) {
        final recon = data.reconciliationSummary;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'RAZORPAY GATEWAY RECONCILIATION',
              'Independent validation of SKAZO internal ledger records against live Razorpay payment entities',
            ),
            const SizedBox(height: 16),

            // Reconciliation KPI Summary
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: [
                _buildStatCard(
                  title: 'MATCHED RECORDS',
                  value: '${recon.matchedCount}',
                  sub: 'Gateway status verified',
                  color: const Color(0xFF16A34A),
                  icon: Icons.check_circle_rounded,
                ),
                _buildStatCard(
                  title: 'MISSING IN FIREBASE',
                  value: '${recon.missingInFirebaseCount}',
                  sub: 'Razorpay payment without ledger record',
                  color: const Color(0xFF2563EB),
                  icon: Icons.cloud_off_rounded,
                ),
                _buildStatCard(
                  title: 'MISSING IN RAZORPAY',
                  value: '${recon.missingInRazorpayCount}',
                  sub: 'Firebase record absent in gateway',
                  color: const Color(0xFFEA580C),
                  icon: Icons.search_off_rounded,
                ),
                _buildStatCard(
                  title: 'DISCREPANCIES / REVIEW',
                  value: '${recon.amountMismatchCount + recon.dateMismatchCount + recon.needsReviewCount}',
                  sub: 'Amount, date, or status mismatch',
                  color: const Color(0xFFDC2626),
                  icon: Icons.rule_folder_rounded,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Gateway Connection / Sync Callout
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: recon.isRazorpayConnected ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      recon.isRazorpayConnected ? Icons.verified_rounded : Icons.info_outline_rounded,
                      color: recon.isRazorpayConnected ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recon.isRazorpayConnected
                              ? 'Razorpay Gateway Connected & Verified'
                              : 'Razorpay Gateway Synchronization Required',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          recon.isRazorpayConnected
                              ? 'Transactions are actively validated with the Razorpay API. Last sync: ${recon.lastSyncTime != null ? DateFormat('dd MMM yyyy, HH:mm').format(recon.lastSyncTime!) : 'Recent'}.'
                              : 'Connect and trigger backend sync to perform complete two-way reconciliation against the official Razorpay payments API.',
                          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: Text('Trigger Gateway Sync', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                    onPressed: () async {
                      final repo = ref.read(revenueRepositoryProvider);
                      await repo.triggerRazorpaySync();
                      ref.invalidate(revenueRawRecordsProvider);
                      ref.invalidate(revenueSyncMetadataProvider);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Discrepancies Table
            _buildSectionHeader(
              'RECONCILIATION REVIEW LIST',
              'Transactions requiring administrative inspection or re-verification',
            ),
            const SizedBox(height: 12),
            _buildDiscrepanciesTable(data.allMatchingRecords),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  Widget _buildDiscrepanciesTable(List<PaymentRecord> records) {
    final list = records
        .where((r) => r.reconciliationStatus != ReconciliationStatus.matched)
        .take(50)
        .toList();

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 40),
              const SizedBox(height: 8),
              Text(
                'No Discrepancies Detected',
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
              ),
              Text(
                'All reconciled records match between Razorpay and SKAZO ledger.',
                style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(label: Text('DATE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('TRANSACTION ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('CUSTOMER', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('AMOUNT', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('RECONCILIATION ISSUE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('SOURCE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('ACTION', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
            rows: list.map((r) {
              return DataRow(
                cells: [
                  DataCell(Text(r.paymentDate != null ? DateFormat('dd MMM yyyy').format(r.paymentDate!) : '—')),
                  DataCell(Text(r.transactionId, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                  DataCell(Text(r.userName ?? 'Customer')),
                  DataCell(Text('₹${r.amount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                  DataCell(_buildReconciliationBadge(r.reconciliationStatus)),
                  DataCell(Text(r.sourceCollection, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)))),
                  DataCell(
                    TextButton(
                      child: const Text('Inspect'),
                      onPressed: () {
                        ref.read(revenueSelectedRecordForDrawerProvider.notifier).state = r;
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 7: PAYMENT LINK OPERATIONS (Preserved)
  // =========================================================================

  Widget _buildLinkOperationsTab() {
    final dataAsync = ref.watch(paginatedPaymentProvider);
    final isSuper = ref.watch(isSuperAdminProvider);
    final adminProfile = ref.watch(currentAdminProfileProvider).value;
    final currentAdminId = adminProfile?['admin_id'] ?? adminProfile?['id'];
    final String? statsFilterAdminId = isSuper ? ref.watch(selectedPaymentAdminFilterProvider) : currentAdminId;
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

        // Super Admin Filter
        if (isSuper) ...[
          adminsAsync.when(
            data: (adminsList) {
              final selectedAdminId = ref.watch(selectedPaymentAdminFilterProvider);
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
                    hint: Text('All Admins', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B))),
                    onChanged: (val) {
                      ref.read(selectedPaymentAdminFilterProvider.notifier).state = val;
                      ref.read(paginatedPaymentProvider.notifier).fetchInitial();
                    },
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('All Admins')),
                      ...adminsList.map((admin) {
                        final adminId = admin['admin_id'] ?? admin['id'];
                        return DropdownMenuItem<String?>(
                          value: adminId,
                          child: Text(admin['name'] ?? admin['email'] ?? 'Unknown'),
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

        // Stats Cards
        statsAsync.when(
          data: (stats) => GridView.count(
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
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildErrorCard(e.toString()),
        ),
        const SizedBox(height: 24),

        // Link Table
        dataAsync.when(
          data: (users) => _buildLinkOperationsTable(users),
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => _buildErrorCard(e.toString()),
        ),
      ],
    );
  }

  Widget _buildLinkOperationsTable(List<Map<String, dynamic>> users) {
    if (users.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text('No payment link records found.')),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(label: Text('BUSINESS / PROVIDER', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('PHONE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('SENDER ADMIN', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('TOTAL PAID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('PLAN DURATION', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('TXN ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('LINK SENT DATE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
            rows: users.map((u) {
              final paid = (u['totalAmount'] as num?)?.toDouble() ?? 0.0;
              final pDate = u['paymentPaidAt'] ?? u['lastPaymentAt'] ?? u['paymentDate'];
              DateTime? parsedDate;
              if (pDate is Timestamp) parsedDate = pDate.toDate();

              return DataRow(
                cells: [
                  DataCell(Text(u['businessname'] ?? u['name'] ?? 'Provider', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                  DataCell(Text('${u['phone'] ?? '—'}')),
                  DataCell(Text(u['paymentLinkSenderName'] ?? '—')),
                  DataCell(Text('₹${paid.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF16A34A)))),
                  DataCell(Text(u['paymentPlanDuration'] ?? '—')),
                  DataCell(Text(u['transactionId'] ?? '—', style: GoogleFonts.poppins(fontSize: 11))),
                  DataCell(Text(parsedDate != null ? DateFormat('dd MMM yyyy').format(parsedDate) : '—')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 8: REFUNDS TAB
  // =========================================================================

  Widget _buildRefundsTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data: (data) {
        final refunds = data.refunds;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'REFUNDS & REVERSALS',
              'Tracked refund events subtracted from gross collections to determine net revenue',
            ),
            const SizedBox(height: 16),

            // Top Refund Summary
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.undo_rounded, color: Color(0xFFDC2626), size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Refunded Volume', style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B))),
                        Text(
                          '₹${NumberFormat('#,##,###').format(data.totalRefunded)}',
                          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFFDC2626)),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${refunds.length} recorded refunds',
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Refunds Table
            if (refunds.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Text('No refunds recorded yet.')),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: [
                        DataColumn(label: Text('DATE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('REFUND ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('PAYMENT ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('AMOUNT', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('STATUS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('SOURCE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      ],
                      rows: refunds.map((rf) {
                        return DataRow(
                          cells: [
                            DataCell(Text(rf.refundDate != null ? DateFormat('dd MMM yyyy').format(rf.refundDate!) : '—')),
                            DataCell(Text(rf.refundId, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                            DataCell(Text(rf.paymentId, style: GoogleFonts.poppins(color: const Color(0xFF0284C7)))),
                            DataCell(
                              Text('₹${rf.amount.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                                child: Text(rf.status.toUpperCase(),
                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFDC2626))),
                              ),
                            ),
                            DataCell(Text(rf.source, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  // =========================================================================
  // TAB 9: SETTLEMENTS TAB
  // =========================================================================

  Widget _buildSettlementsTab(AsyncValue<RevenueAnalyticsData> analyticsAsync) {
    return analyticsAsync.when(
      data: (data) {
        final settlements = data.settlements;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              'BANK SETTLEMENTS & PAYOUTS',
              'Razorpay bank payout records distinguishing customer payment collection from bank deposits',
            ),
            const SizedBox(height: 16),

            // Settlement Principle Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment Collection vs Bank Settlement',
                          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Payment collection occurs in real-time when a customer completes checkout. Bank settlement is the subsequent wire transfer by Razorpay into SKAZO\'s corporate bank account (T+2 business days) net of Razorpay processing fees and GST.',
                          style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF1E3A8A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (settlements.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.account_balance_rounded, color: Color(0xFF94A3B8), size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'No Bank Settlements Available',
                        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Settlement data will be automatically retrieved once settlement webhooks or permissions are active on your Razorpay account.',
                        style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      columns: [
                        DataColumn(label: Text('DATE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('SETTLEMENT ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('GROSS AMOUNT', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('FEES', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('TAX', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('NET SETTLED', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('UTR', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                        DataColumn(label: Text('STATUS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      ],
                      rows: settlements.map((s) {
                        return DataRow(
                          cells: [
                            DataCell(Text(s.settlementDate != null ? DateFormat('dd MMM yyyy').format(s.settlementDate!) : '—')),
                            DataCell(Text(s.settlementId, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                            DataCell(Text('₹${s.amount.toStringAsFixed(0)}')),
                            DataCell(Text('₹${s.fees.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: const Color(0xFFDC2626)))),
                            DataCell(Text('₹${s.tax.toStringAsFixed(0)}', style: GoogleFonts.poppins(color: const Color(0xFFDC2626)))),
                            DataCell(
                              Text('₹${s.netSettlement.toStringAsFixed(0)}',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF16A34A))),
                            ),
                            DataCell(Text(s.utr, style: GoogleFonts.poppins(fontSize: 11))),
                            DataCell(Text(s.status.toUpperCase(), style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
      error: (e, _) => _buildErrorCard(e.toString()),
    );
  }

  // =========================================================================
  // TAB 10: SYNC & AUDIT LOG TAB
  // =========================================================================

  Widget _buildSyncAuditTab(AsyncValue<RevenueAnalyticsData> analyticsAsync, Map<String, dynamic>? syncMeta) {
    final auditLogsAsync = ref.watch(revenueAuditLogsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'GATEWAY SYNCHRONIZATION & AUDIT TRAIL',
          'Synchronization history, gateway connection settings, and cryptographic audit log of financial actions',
        ),
        const SizedBox(height: 16),

        // Gateway Operations Panel
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Razorpay Backend Integration Status',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Run Full Historical Sync'),
                    onPressed: () async {
                      final repo = ref.read(revenueRepositoryProvider);
                      await repo.triggerRazorpaySync(fullSync: true);
                      ref.invalidate(revenueRawRecordsProvider);
                      ref.invalidate(revenueSyncMetadataProvider);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Status: ${syncMeta?['syncStatus'] ?? 'idle'} • '
                'Processed: ${syncMeta?['recordsProcessed'] ?? 0} • '
                'Matched: ${syncMeta?['recordsMatched'] ?? 0} • '
                'Created: ${syncMeta?['recordsCreated'] ?? 0}',
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.drive_file_move_rounded, size: 16),
                label: const Text('Migrate Historical Legacy Data into Ledger'),
                onPressed: () async {
                  final repo = ref.read(revenueRepositoryProvider);
                  final res = await repo.triggerLegacyMigration();
                  ref.invalidate(revenueRawRecordsProvider);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(res['message'] ?? 'Migration completed.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Audit Trail Table
        _buildSectionHeader('FINANCIAL AUDIT LOG', 'Traceability of all system, admin, and webhook financial operations'),
        const SizedBox(height: 12),
        auditLogsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: const Center(child: Text('No audit events logged yet.')),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: [
                      DataColumn(label: Text('TIMESTAMP', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('ACTOR', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('ACTION', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                      DataColumn(label: Text('TRANSACTION ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                    rows: logs.map((l) {
                      return DataRow(
                        cells: [
                          DataCell(Text(l.timestamp != null ? DateFormat('dd MMM yyyy, HH:mm:ss').format(l.timestamp!) : '—')),
                          DataCell(Text(l.actor, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                              child: Text(l.action, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          DataCell(Text(l.transactionId ?? '—', style: GoogleFonts.poppins(color: const Color(0xFF0284C7)))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator())),
          error: (e, _) => _buildErrorCard(e.toString()),
        ),
      ],
    );
  }

  // =========================================================================
  // TRANSACTION DETAIL DRAWER
  // =========================================================================

  Widget _buildDetailDrawer(PaymentRecord r) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 500,
      child: Material(
        elevation: 24,
        color: Colors.white,
        child: Container(
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Color(0xFFE2E8F0)))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(color: Color(0xFF0F172A)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TRANSACTION DETAILS',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(r.transactionId, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () {
                        ref.read(revenueSelectedRecordForDrawerProvider.notifier).state = null;
                      },
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Amount & Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gross Amount', style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
                              Text(
                                '₹${r.amount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                          _buildStatusBadge(r.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (r.refundedAmount > 0)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.undo_rounded, size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Text(
                                '₹${r.refundedAmount.toStringAsFixed(2)} Refunded • Net: ₹${r.netCollectedAmount.toStringAsFixed(2)}',
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF991B1B)),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 32),

                      // Customer Info
                      _buildDrawerSectionTitle('Customer Information'),
                      _buildDrawerField('Name', r.userName ?? 'N/A'),
                      _buildDrawerField('Phone', '${r.userPhone ?? 'N/A'}'),
                      _buildDrawerField('User ID', r.userId ?? 'N/A'),
                      const Divider(height: 32),

                      // Razorpay Verification & IDs
                      _buildDrawerSectionTitle('Gateway & Identification'),
                      _buildDrawerField('Razorpay Payment ID', r.razorpayPaymentId ?? 'N/A'),
                      _buildDrawerField('Razorpay Order ID', r.razorpayOrderId ?? 'N/A'),
                      _buildDrawerField('Razorpay Link ID', r.razorpayLinkId ?? 'N/A'),
                      _buildDrawerField('Payment Method', (r.paymentMethod ?? 'unknown').toUpperCase()),
                      _buildDrawerField('Verification Status', r.verificationStatus.toUpperCase()),
                      _buildDrawerField('Signature Verified', r.signatureVerified ? 'Yes (HMAC SHA256)' : 'Unverified'),
                      _buildDrawerField('Webhook Verified', r.webhookVerified ? 'Yes (Event Confirmed)' : 'Pending Webhook'),
                      _buildDrawerField('Reconciliation Status', r.reconciliationStatus.displayName),
                      const Divider(height: 32),

                      // Business Context
                      _buildDrawerSectionTitle('Business Stream & Attribution'),
                      _buildDrawerField('Stream', r.stream.displayName),
                      _buildDrawerField('Category', r.category),
                      _buildDrawerField('City', '${r.city} (${r.cityConfidence.label})'),
                      _buildDrawerField('Source Document', '${r.sourceCollection} / ${r.sourceDocumentId}'),
                      _buildDrawerField('Data Scope', r.dataScope.label),
                      const Divider(height: 32),

                      // Timeline
                      _buildDrawerSectionTitle('Verifiable Timeline'),
                      _buildTimelineItem('Order Created', r.createdAt ?? r.paymentDate, isFirst: true),
                      _buildTimelineItem('Payment Captured', r.capturedAt ?? r.paymentDate),
                      if (r.webhookVerified)
                        _buildTimelineItem('Webhook Verified', r.updatedAt ?? r.paymentDate),
                      if (r.refundedAmount > 0)
                        _buildTimelineItem('Refund Processed', r.updatedAt, isRefund: true),
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

  Widget _buildTimelineItem(String title, DateTime? date, {bool isFirst = false, bool isRefund = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRefund ? Icons.undo_rounded : Icons.check_circle_rounded,
            size: 16,
            color: isRefund ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600)),
                Text(
                  date != null ? DateFormat('dd MMM yyyy, HH:mm:ss').format(date) : 'Confirmed event',
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
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
            child: Text(label, style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // HELPER WIDGETS
  // =========================================================================

  Widget _buildStatCard({
    required String title,
    required String value,
    required String sub,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), letterSpacing: 0.4),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF64748B))),
      ],
    );
  }

  Widget _buildStatusBadge(PaymentStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case PaymentStatus.collected:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'COLLECTED';
        break;
      case PaymentStatus.outstanding:
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFEA580C);
        label = 'OUTSTANDING';
        break;
      case PaymentStatus.paymentAttempt:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = 'ATTEMPT (UNPAID)';
        break;
      case PaymentStatus.refunded:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'REFUNDED';
        break;
      case PaymentStatus.partiallyRefunded:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'PARTIAL REFUND';
        break;
      case PaymentStatus.authorized:
        bg = const Color(0xFFE0F2FE);
        fg = const Color(0xFF0284C7);
        label = 'AUTHORIZED';
        break;
      case PaymentStatus.failedOrCancelled:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFB91C1C);
        label = 'FAILED';
        break;
      case PaymentStatus.unknown:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        label = 'UNKNOWN';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
    );
  }

  Widget _buildReconciliationBadge(ReconciliationStatus status) {
    Color bg;
    Color fg;

    switch (status) {
      case ReconciliationStatus.matched:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        break;
      case ReconciliationStatus.missingInFirebase:
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        break;
      case ReconciliationStatus.missingInRazorpay:
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFFEA580C);
        break;
      case ReconciliationStatus.amountMismatch:
      case ReconciliationStatus.dateMismatch:
      case ReconciliationStatus.duplicate:
      case ReconciliationStatus.needsReview:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        break;
      case ReconciliationStatus.unmapped:
      case ReconciliationStatus.razorpayNotConnected:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.displayName,
        style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Synchronization or Query Error',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF991B1B)),
                ),
                Text(error, style: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF7F1D1D))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Sub-widget for Category drilldown table
class _CategoryDetailTable extends StatefulWidget {
  final List<PaymentRecord> records;
  final int pageSize;

  const _CategoryDetailTable({required this.records, required this.pageSize});

  @override
  State<_CategoryDetailTable> createState() => _CategoryDetailTableState();
}

class _CategoryDetailTableState extends State<_CategoryDetailTable> {
  final int _page = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.records.length;
    final start = _page * widget.pageSize;
    final end = (start + widget.pageSize > total) ? total : start + widget.pageSize;
    final pageItems = start < total ? widget.records.sublist(start, end) : <PaymentRecord>[];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: [
              DataColumn(label: Text('DATE', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('TRANSACTION ID', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('PROVIDER', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('STREAM', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('CITY', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('AMOUNT', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
              DataColumn(label: Text('STATUS', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700))),
            ],
            rows: pageItems.map((r) {
              return DataRow(
                cells: [
                  DataCell(Text(r.paymentDate != null ? DateFormat('dd MMM yyyy').format(r.paymentDate!) : '—')),
                  DataCell(Text(r.transactionId, style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
                  DataCell(Text(r.userName ?? 'Provider')),
                  DataCell(Text(r.stream.shortName)),
                  DataCell(Text(r.city)),
                  DataCell(Text('₹${r.amount.toStringAsFixed(0)}', style: GoogleFonts.poppins(fontWeight: FontWeight.w700))),
                  DataCell(Text(r.status.displayName)),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
