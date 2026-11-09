import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/models/call_log_sheet_item.dart';
import 'package:skazo_admin/providers/call_log_sheet_provider.dart';

class CallLogSheetView extends ConsumerStatefulWidget {
  const CallLogSheetView({super.key});

  @override
  ConsumerState<CallLogSheetView> createState() => _CallLogSheetViewState();
}

class _CallLogSheetViewState extends ConsumerState<CallLogSheetView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(callLogSheetSearchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  /// Formats phone number consistently, e.g. 919160338382 -> +91 91603 38382
  String _formatPhoneNumber(String rawPhone) {
    if (rawPhone.trim().isEmpty || rawPhone == 'N/A') return 'N/A';
    final cleaned = rawPhone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return 'N/A';

    if (cleaned.length == 12 && cleaned.startsWith('91')) {
      return '+91 ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
    }
    if (cleaned.length == 10) {
      return '+91 ${cleaned.substring(0, 5)} ${cleaned.substring(5)}';
    }
    return cleaned;
  }

  /// Formats deactivated date in a readable format, e.g. 17-Oct-2026
  String _formatDeactivatedDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd-MMM-yyyy').format(date);
  }

  /// Returns full timestamp with time for tooltips
  String _formatFullDateTime(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd-MMM-yyyy, hh:mm a').format(date);
  }

  /// Copies text to clipboard and displays a brief snackbar
  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label copied to clipboard',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        width: 320,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callLogSheetNotifierProvider);
    final pagination = ref.watch(callLogSheetPaginationProvider);
    final availableStatuses = ref.watch(callLogSheetAvailableStatusesProvider);
    final currentStatusFilter = ref.watch(callLogSheetStatusFilterProvider);
    final currentSort = ref.watch(callLogSheetSortByProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Page Header
            _buildPageHeader(context, state),

            // Top KPI Cards
            _buildKpiSummary(state.items),

            // Warning Banner for partial results
            if (state.warningMessage != null)
              _buildWarningBanner(state.warningMessage!),

            // Search, Filter & Controls Toolbar
            _buildFilterToolbar(
              context,
              availableStatuses,
              currentStatusFilter,
              currentSort,
              pagination.pageSize,
            ),

            const SizedBox(height: 12),

            // Table Content or States
            Expanded(
              child: _buildMainContent(
                state: state,
                pagination: pagination,
                currentSort: currentSort,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Top Header: Title, Subtitle, and Refresh Button
  Widget _buildPageHeader(BuildContext context, CallLogSheetState state) {
    final isWorking = state.isLoading || state.isRefreshing;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.table_chart_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Call Log Sheet',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'READ-ONLY REPORT',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0284C7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Consolidated provider call log & sales conversion reporting (callLogs + users)',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Action Buttons
          OutlinedButton.icon(
            onPressed: isWorking
                ? null
                : () => ref
                    .read(callLogSheetNotifierProvider.notifier)
                    .fetchData(isRefresh: true),
            icon: isWorking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0284C7),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              isWorking
                  ? (state.isRefreshing ? 'Refreshing...' : 'Syncing...')
                  : 'Refresh Sheet',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0284C7),
              side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Warning banner if non-fatal issues occur during parallel log fetch
  Widget _buildWarningBanner(String message) {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 12, 28, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Summary Cards showing overview of loaded data
  Widget _buildKpiSummary(List<CallLogSheetItem> items) {
    int totalCalls = 0;
    int totalConverted = 0;
    int deactivatedCount = 0;

    for (final it in items) {
      totalCalls += it.callsAfterLastPayment;
      totalConverted += it.convertedCount;
      if (it.deactivatedAt != null) deactivatedCount++;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 14, 28, 4),
      child: Row(
        children: [
          _buildKpiCard(
            title: 'Eligible Providers',
            value: '${items.length}',
            subtitle: 'callsAfterLastPayment > 5',
            icon: Icons.business_center_rounded,
            iconColor: const Color(0xFF0284C7),
            bgColor: const Color(0xFFE0F2FE),
          ),
          const SizedBox(width: 16),
          _buildKpiCard(
            title: 'Calls Post-Payment',
            value: '$totalCalls',
            subtitle: 'Aggregate calls > 5',
            icon: Icons.phone_forwarded_rounded,
            iconColor: const Color(0xFFF59E0B),
            bgColor: const Color(0xFFFEF3C7),
          ),
          const SizedBox(width: 16),
          _buildKpiCard(
            title: 'Converted Sales',
            value: '$totalConverted',
            subtitle: 'Source: users.convertedCount',
            icon: Icons.verified_rounded,
            iconColor: const Color(0xFF10B981),
            bgColor: const Color(0xFFD1FAE5),
          ),
          const SizedBox(width: 16),
          _buildKpiCard(
            title: 'Deactivated Providers',
            value: '$deactivatedCount',
            subtitle: 'Has deactivation date',
            icon: Icons.person_off_rounded,
            iconColor: const Color(0xFFEF4444),
            bgColor: const Color(0xFFFEE2E2),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Toolbar containing Search, Status filter, Sort options, and Page size
  Widget _buildFilterToolbar(
    BuildContext context,
    List<String> availableStatuses,
    String currentStatusFilter,
    CallLogSheetSortOption currentSort,
    int pageSize,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 12, 28, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search Input
          SizedBox(
            width: 320,
            height: 42,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(callLogSheetSearchQueryProvider.notifier).state = val;
                ref.read(callLogSheetCurrentPageProvider.notifier).state = 0;
              },
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search business, phone, tx ID...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear_rounded,
                          size: 16,
                          color: Color(0xFF94A3B8),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          ref
                              .read(callLogSheetSearchQueryProvider.notifier)
                              .state = '';
                          ref
                              .read(callLogSheetCurrentPageProvider.notifier)
                              .state = 0;
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
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
                  borderSide: const BorderSide(
                    color: Color(0xFF0284C7),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Filters and Sorting Controls
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Feedback Status Filter
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Status: ',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: availableStatuses.contains(currentStatusFilter)
                            ? currentStatusFilter
                            : 'All',
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        onChanged: (String? newVal) {
                          if (newVal != null) {
                            ref
                                .read(
                                  callLogSheetStatusFilterProvider.notifier,
                                )
                                .state = newVal;
                            ref
                                .read(
                                  callLogSheetCurrentPageProvider.notifier,
                                )
                                .state = 0;
                          }
                        },
                        items: availableStatuses.map((st) {
                          return DropdownMenuItem<String>(
                            value: st,
                            child: Text(st),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),

              // Sort By Dropdown
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sort: ',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<CallLogSheetSortOption>(
                        value: currentSort,
                        icon: const Icon(
                          Icons.sort_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        onChanged: (CallLogSheetSortOption? newVal) {
                          if (newVal != null) {
                            ref
                                .read(callLogSheetSortByProvider.notifier)
                                .state = newVal;
                            ref
                                .read(
                                  callLogSheetCurrentPageProvider.notifier,
                                )
                                .state = 0;
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.callsDesc,
                            child: Text('Calls (High → Low)'),
                          ),
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.callsAsc,
                            child: Text('Calls (Low → High)'),
                          ),
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.deactivatedDateDesc,
                            child: Text('Deactivated (Newest First)'),
                          ),
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.deactivatedDateAsc,
                            child: Text('Deactivated (Oldest First)'),
                          ),
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.convertedDesc,
                            child: Text('Converted (High → Low)'),
                          ),
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.convertedAsc,
                            child: Text('Converted (Low → High)'),
                          ),
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.businessNameAsc,
                            child: Text('Business Name (A → Z)'),
                          ),
                          DropdownMenuItem(
                            value: CallLogSheetSortOption.businessNameDesc,
                            child: Text('Business Name (Z → A)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Rows per page selector
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Per page: ',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: pageSize,
                        icon: const Icon(
                          Icons.arrow_drop_down,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF0F172A),
                        ),
                        onChanged: (int? newSize) {
                          if (newSize != null) {
                            ref
                                .read(callLogSheetPageSizeProvider.notifier)
                                .state = newSize;
                            ref
                                .read(
                                  callLogSheetCurrentPageProvider.notifier,
                                )
                                .state = 0;
                          }
                        },
                        items: const [10, 25, 50, 100].map((size) {
                          return DropdownMenuItem<int>(
                            value: size,
                            child: Text('$size'),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Main Content Router: Loading, Error, Empty, or Table
  Widget _buildMainContent({
    required CallLogSheetState state,
    required CallLogSheetPaginationData pagination,
    required CallLogSheetSortOption currentSort,
  }) {
    if (state.isLoading && state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF0284C7),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading Call Log Sheet...',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Fetching eligible providers (callsAfterLastPayment > 5) from Firestore',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      );
    }

    if (state.errorMessage != null && state.items.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFCA5A5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFEF4444),
                size: 48,
              ),
              const SizedBox(height: 14),
              Text(
                'Failed to load Call Log Sheet',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => ref
                    .read(callLogSheetNotifierProvider.notifier)
                    .fetchData(isRefresh: false),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (pagination.totalItems == 0) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 44,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No Providers Match Criteria',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Only service providers (isuser == false) with callsAfterLastPayment > 5 are eligible.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              if (_searchController.text.isNotEmpty ||
                  ref.read(callLogSheetStatusFilterProvider) != 'All') ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(callLogSheetSearchQueryProvider.notifier)
                        .state = '';
                    ref
                        .read(callLogSheetStatusFilterProvider.notifier)
                        .state = 'All';
                    ref
                        .read(callLogSheetCurrentPageProvider.notifier)
                        .state = 0;
                    setState(() {});
                  },
                  icon: const Icon(Icons.clear_all_rounded, size: 16),
                  label: const Text('Clear All Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Scrollable Table Container
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 4, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Top Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Showing ',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '${pagination.startRow} - ${pagination.endRow}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0284C7),
                      ),
                    ),
                    Text(
                      ' of ${pagination.totalItems} eligible providers (callsAfterLastPayment > 5)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                if (state.lastRefreshed != null)
                  Row(
                    children: [
                      if (state.isRefreshing) ...[
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        'Updated: ${DateFormat('hh:mm:ss a').format(state.lastRefreshed!)}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Responsive Horizontally & Vertically Scrollable DataTable
          // Sized with LayoutBuilder to guarantee ZERO RenderFlex overflow on any screen
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Minimum width accommodates all 8 columns without clipping
                final double minTableWidth = max(constraints.maxWidth, 1380.0);

                return Scrollbar(
                  controller: _horizontalScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _horizontalScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      width: minTableWidth,
                      child: Scrollbar(
                        controller: _verticalScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalScrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: DataTable(
                            headingRowHeight: 48,
                            dataRowMinHeight: 56,
                            dataRowMaxHeight: 68,
                            horizontalMargin: 20,
                            columnSpacing: 24,
                            headingRowColor: WidgetStateProperty.all(
                              const Color(0xFFF1F5F9),
                            ),
                            columns: [
                              // 1. Index
                              DataColumn(
                                label: Text(
                                  '#',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              // 2. Business Name
                              DataColumn(
                                label: Text(
                                  'BUSINESS NAME',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              // 3. Phone Number
                              DataColumn(
                                label: Text(
                                  'PHONE',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              // 4. Calls After Last Payment
                              DataColumn(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'CALLS > 5',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      currentSort ==
                                              CallLogSheetSortOption.callsDesc
                                          ? Icons.arrow_downward_rounded
                                          : (currentSort ==
                                                  CallLogSheetSortOption.callsAsc
                                              ? Icons.arrow_upward_rounded
                                              : Icons.sort_rounded),
                                      size: 14,
                                      color: (currentSort ==
                                                  CallLogSheetSortOption
                                                      .callsDesc ||
                                              currentSort ==
                                                  CallLogSheetSortOption
                                                      .callsAsc)
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                                onSort: (_, __) {
                                  final notifier = ref.read(
                                    callLogSheetSortByProvider.notifier,
                                  );
                                  notifier.state = currentSort ==
                                          CallLogSheetSortOption.callsDesc
                                      ? CallLogSheetSortOption.callsAsc
                                      : CallLogSheetSortOption.callsDesc;
                                },
                              ),
                              // 5. Deactivated Date
                              DataColumn(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'DEACTIVATED DATE',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      currentSort ==
                                              CallLogSheetSortOption
                                                  .deactivatedDateDesc
                                          ? Icons.arrow_downward_rounded
                                          : (currentSort ==
                                                  CallLogSheetSortOption
                                                      .deactivatedDateAsc
                                              ? Icons.arrow_upward_rounded
                                              : Icons.sort_rounded),
                                      size: 14,
                                      color: (currentSort ==
                                                  CallLogSheetSortOption
                                                      .deactivatedDateDesc ||
                                              currentSort ==
                                                  CallLogSheetSortOption
                                                      .deactivatedDateAsc)
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                                onSort: (_, __) {
                                  final notifier = ref.read(
                                    callLogSheetSortByProvider.notifier,
                                  );
                                  notifier.state = currentSort ==
                                          CallLogSheetSortOption
                                              .deactivatedDateDesc
                                      ? CallLogSheetSortOption.deactivatedDateAsc
                                      : CallLogSheetSortOption
                                          .deactivatedDateDesc;
                                },
                              ),
                              // 6. Sales Feedback Status
                              // DataColumn(
                              //   label: Text(
                              //     'SALES FEEDBACK STATUS',
                              //     style: GoogleFonts.poppins(
                              //       fontSize: 12,
                              //       fontWeight: FontWeight.w700,
                              //       color: const Color(0xFF475569),
                              //     ),
                              //   ),
                              // ),
                              // 7. Transaction ID
                              DataColumn(
                                label: Text(
                                  'TRANSACTION ID',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF475569),
                                  ),
                                ),
                              ),
                              // 8. Sales Feedback Converted Count
                              DataColumn(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'CONVERTED COUNT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      currentSort ==
                                              CallLogSheetSortOption
                                                  .convertedDesc
                                          ? Icons.arrow_downward_rounded
                                          : (currentSort ==
                                                  CallLogSheetSortOption
                                                      .convertedAsc
                                              ? Icons.arrow_upward_rounded
                                              : Icons.sort_rounded),
                                      size: 14,
                                      color: (currentSort ==
                                                  CallLogSheetSortOption
                                                      .convertedDesc ||
                                              currentSort ==
                                                  CallLogSheetSortOption
                                                      .convertedAsc)
                                          ? const Color(0xFF0284C7)
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                                onSort: (_, __) {
                                  final notifier = ref.read(
                                    callLogSheetSortByProvider.notifier,
                                  );
                                  notifier.state = currentSort ==
                                          CallLogSheetSortOption.convertedDesc
                                      ? CallLogSheetSortOption.convertedAsc
                                      : CallLogSheetSortOption.convertedDesc;
                                },
                              ),
                            ],
                            rows: List<DataRow>.generate(
                              pagination.pageItems.length,
                              (index) {
                                final item = pagination.pageItems[index];
                                final serialNum = pagination.startRow + index;

                                return DataRow(
                                  color: WidgetStateProperty.resolveWith<Color?>(
                                    (Set<WidgetState> states) {
                                      if (states
                                          .contains(WidgetState.hovered)) {
                                        return const Color(0xFFF1F5F9);
                                      }
                                      return index.isEven
                                          ? Colors.white
                                          : const Color(0xFFFAFAFA);
                                    },
                                  ),
                                  cells: [
                                    // 1. Index
                                    DataCell(
                                      Text(
                                        '$serialNum',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),

                                    // 2. Business Name
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 240,
                                          minWidth: 160,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Tooltip(
                                              message: item.businessName,
                                              child: Text(
                                                item.businessName,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Tooltip(
                                              message: 'UID: ${item.businessId}',
                                              child: Text(
                                                item.businessId,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  color:
                                                      const Color(0xFF94A3B8),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 3. Phone Number
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatPhoneNumber(item.phone),
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: const Color(0xFF334155),
                                            ),
                                          ),
                                          if (item.phone.isNotEmpty &&
                                              item.phone != 'N/A') ...[
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => _copyToClipboard(
                                                context,
                                                item.phone,
                                                'Phone number',
                                              ),
                                              child: const Icon(
                                                Icons.copy_rounded,
                                                size: 14,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // 4. Calls After Last Payment
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          '${item.callsAfterLastPayment}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFD97706),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 5. Deactivated Date
                                    DataCell(
                                      Tooltip(
                                        message: _formatFullDateTime(
                                          item.deactivatedAt,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (item.deactivatedAt != null)
                                              const Icon(
                                                Icons.event_busy_rounded,
                                                size: 14,
                                                color: Color(0xFFEF4444),
                                              ),
                                            if (item.deactivatedAt != null)
                                              const SizedBox(width: 6),
                                            Text(
                                              _formatDeactivatedDate(
                                                item.deactivatedAt,
                                              ),
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight:
                                                    item.deactivatedAt != null
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                color: item.deactivatedAt !=
                                                        null
                                                    ? const Color(0xFFEF4444)
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 6. Sales Feedback Status
                                    // DataCell(
                                    //   _buildSalesFeedbackCell(
                                    //     item.feedbackStatuses,
                                    //     item.callLogsFetchError,
                                    //   ),
                                    // ),

                                    // 7. Transaction ID
                                    DataCell(
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 180,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Flexible(
                                              child: Tooltip(
                                                message:
                                                    item.transactionId ?? 'N/A',
                                                child: Text(
                                                  item.transactionId ?? 'N/A',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    fontWeight: item
                                                                .transactionId !=
                                                            null
                                                        ? FontWeight.w600
                                                        : FontWeight.w400,
                                                    color: item
                                                                .transactionId !=
                                                            null
                                                        ? const Color(
                                                            0xFF475569)
                                                        : const Color(
                                                            0xFF94A3B8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            if (item.transactionId !=
                                                null) ...[
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _copyToClipboard(
                                                  context,
                                                  item.transactionId!,
                                                  'Transaction ID',
                                                ),
                                                child: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 14,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 8. Sales Feedback Converted Count (users.convertedCount)
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color: const Color(0xFF8B5CF6)
                                                .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Text(
                                          '${item.convertedCount}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF7C3AED),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom Pagination Footer Bar
          _buildPaginationBar(pagination),
        ],
      ),
    );
  }

  /// Builds responsive pagination bar at table bottom
  Widget _buildPaginationBar(CallLogSheetPaginationData pagination) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Range Indicator
          Text(
            'Showing ${pagination.startRow} - ${pagination.endRow} of ${pagination.totalItems} entries',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),

          // Page Navigation Buttons
          Row(
            children: [
              // First Page Button
              IconButton(
                onPressed: pagination.hasPreviousPage
                    ? () => ref
                        .read(callLogSheetCurrentPageProvider.notifier)
                        .state = 0
                    : null,
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                color: const Color(0xFF0284C7),
                disabledColor: const Color(0xFFCBD5E1),
              ),

              // Previous Page Button
              IconButton(
                onPressed: pagination.hasPreviousPage
                    ? () => ref
                        .read(callLogSheetCurrentPageProvider.notifier)
                        .state = pagination.currentPage - 1
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                color: const Color(0xFF0284C7),
                disabledColor: const Color(0xFFCBD5E1),
              ),

              // Page Status Badge
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page ${pagination.currentPage + 1} of ${pagination.totalPages}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),

              // Next Page Button
              IconButton(
                onPressed: pagination.hasNextPage
                    ? () => ref
                        .read(callLogSheetCurrentPageProvider.notifier)
                        .state = pagination.currentPage + 1
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                color: const Color(0xFF0284C7),
                disabledColor: const Color(0xFFCBD5E1),
              ),

              // Last Page Button
              IconButton(
                onPressed: pagination.hasNextPage
                    ? () => ref
                        .read(callLogSheetCurrentPageProvider.notifier)
                        .state = pagination.totalPages - 1
                    : null,
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                color: const Color(0xFF0284C7),
                disabledColor: const Color(0xFFCBD5E1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a badge or set of badges for sales feedback statuses
  Widget _buildSalesFeedbackCell(List<String> statuses, String? fetchError) {
    if (fetchError != null) {
      return Tooltip(
        message: 'Retrieval failure: $fetchError',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 13,
                color: Color(0xFFDC2626),
              ),
              const SizedBox(width: 4),
              Text(
                'Fetch Error',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (statuses.isEmpty) {
      return Text(
        'No Calls Logged',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: const Color(0xFF94A3B8),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: statuses.map((st) {
          final normalized = st.toLowerCase().trim();
          Color bg;
          Color fg;

          if (normalized == 'converted') {
            bg = const Color(0xFF10B981).withValues(alpha: 0.15);
            fg = const Color(0xFF047857);
          } else if (normalized == 'pending') {
            bg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
            fg = const Color(0xFFB45309);
          } else if (normalized == 'interested') {
            bg = const Color(0xFF3B82F6).withValues(alpha: 0.15);
            fg = const Color(0xFF1D4ED8);
          } else if (normalized == 'follow_up' || normalized == 'follow up') {
            bg = const Color(0xFFF97316).withValues(alpha: 0.15);
            fg = const Color(0xFFC2410C);
          } else if (normalized == 'not_interested' ||
              normalized == 'not interested' ||
              normalized == 'rejected') {
            bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
            fg = const Color(0xFFB91C1C);
          } else if (normalized == 'sync error') {
            bg = const Color(0xFFFEE2E2);
            fg = const Color(0xFFDC2626);
          } else {
            bg = const Color(0xFF64748B).withValues(alpha: 0.15);
            fg = const Color(0xFF334155);
          }

          return Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              st,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
