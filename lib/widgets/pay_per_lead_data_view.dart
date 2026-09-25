import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/pay_per_lead_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

/// Production-ready, strictly read-only Pay Per Lead entity view.
///
/// Displays:
///   isuser == false
///   AND payperLeadcharge > 0
///
/// Supports smooth 2D scrolling (vertical for all records on the page,
/// horizontal for all table columns) with pinned pagination footer.
class PayPerLeadDataView extends ConsumerStatefulWidget {
  const PayPerLeadDataView({super.key});

  @override
  ConsumerState<PayPerLeadDataView> createState() => _PayPerLeadDataViewState();
}

class _PayPerLeadDataViewState extends ConsumerState<PayPerLeadDataView> {
  String? _selectedCity;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final state = ref.read(payPerLeadPaginationProvider);
    _selectedCity = state.selectedCity;
    _dateFrom = state.dateFrom;
    _dateTo = state.dateTo;
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  /// ------------------------------------------------------------
  /// FILTER ACTIONS
  /// ------------------------------------------------------------

  void _applyFilters() {
    ref.read(payPerLeadPaginationProvider.notifier).applyFilters(
          city: _selectedCity,
          dateFrom: _dateFrom,
          dateTo: _dateTo,
        );
  }

  void _clearFilters() {
    setState(() {
      _selectedCity = null;
      _dateFrom = null;
      _dateTo = null;
    });
    ref.read(payPerLeadPaginationProvider.notifier).clearFilters();
  }

  /// ------------------------------------------------------------
  /// DATE PICKER
  /// ------------------------------------------------------------

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final initialDate =
        isFrom ? (_dateFrom ?? now) : (_dateTo ?? _dateFrom ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0284C7),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      if (isFrom) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(_dateFrom!)) {
          _dateTo = _dateFrom;
        }
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(_dateTo!)) {
          _dateFrom = _dateTo;
        }
      }
    });
  }

  /// ------------------------------------------------------------
  /// BUILD
  /// ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(payPerLeadPaginationProvider);
    final isSuper = ref.watch(isSuperAdminProvider);
    final assignedCities = ref.watch(currentAdminAssignedCitiesProvider);
    final allowedCitiesAsync = ref.watch(allowedCitiesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildFilterSection(
                allowedCitiesAsync,
                isSuper,
                assignedCities,
                state,
              ),
              _buildSummaryBanner(state),

              /// Expanded content area fills all available vertical space
              Expanded(
                child: _buildContent(state, isDesktop),
              ),

              /// Pinned pagination footer (outside scrolling area, stays visible)
              if (state.providers.isNotEmpty ||
                  (state.totalCount != null && state.totalCount! > 0))
                _buildPaginationFooter(state),
            ],
          );
        },
      ),
    );
  }

  /// ------------------------------------------------------------
  /// HEADER
  /// ------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 14),
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
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.leaderboard_rounded,
                        color: Color(0xFF0284C7),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Pay Per Lead',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.5,
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
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        'READ-ONLY',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Providers with outstanding Pay Per Lead charges (payperLeadcharge > 0)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                ref.read(payPerLeadPaginationProvider.notifier).refresh();
              },
              icon: const Icon(
                Icons.refresh_rounded,
                color: Color(0xFF0284C7),
                size: 22,
              ),
              tooltip: 'Refresh Current View',
            ),
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------------------
  /// FILTER SECTION
  /// ------------------------------------------------------------

  Widget _buildFilterSection(
    AsyncValue<List<String>> allowedCitiesAsync,
    bool isSuper,
    List<String> assignedCities,
    PayPerLeadPaginationState state,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            /// CITY
            allowedCitiesAsync.when(
              data: (cities) {
                final items = cities.toSet().toList()..sort();

                return Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedCity,
                      hint: Text(
                        'Select City',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedCity = value;
                        });
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
                        ...items.map(
                          (city) => DropdownMenuItem<String?>(
                            value: city,
                            child: Text(
                              city,
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              loading: () => const SizedBox(
                width: 140,
                height: 42,
                child: Center(child: LinearProgressIndicator()),
              ),
              error: (_, __) => const SizedBox.shrink(),
            ),

            /// DATE FROM
            InkWell(
              onTap: () => _pickDate(isFrom: true),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _dateFrom != null
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dateFrom != null
                          ? 'From: ${dateFormat.format(_dateFrom!)}'
                          : 'Date From',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _dateFrom != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                        fontWeight: _dateFrom != null
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// DATE TO
            InkWell(
              onTap: () => _pickDate(isFrom: false),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _dateTo != null
                        ? const Color(0xFF0284C7)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event_available_rounded,
                      size: 15,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _dateTo != null
                          ? 'To: ${dateFormat.format(_dateTo!)}'
                          : 'Date To',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _dateTo != null
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF64748B),
                        fontWeight:
                            _dateTo != null ? FontWeight.w500 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// SORT
            Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.sort_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<PayPerLeadSortOrder>(
                      value: state.sortOrder,
                      onChanged: (order) {
                        if (order == null) return;
                        ref
                            .read(payPerLeadPaginationProvider.notifier)
                            .changeSortOrder(order);
                      },
                      items: [
                        DropdownMenuItem(
                          value: PayPerLeadSortOrder.newest,
                          child: Text(
                            'Newest First',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                        DropdownMenuItem(
                          value: PayPerLeadSortOrder.oldest,
                          child: Text(
                            'Oldest First',
                            style: GoogleFonts.poppins(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            /// APPLY
            ElevatedButton.icon(
              onPressed: state.isLoading ? null : _applyFilters,
              icon: const Icon(Icons.filter_alt_rounded, size: 15),
              label: const Text('Apply'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),

            /// CLEAR
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : _clearFilters,
              icon: const Icon(Icons.clear_all_rounded, size: 15),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------------------
  /// SUMMARY BANNER
  /// ------------------------------------------------------------

  Widget _buildSummaryBanner(PayPerLeadPaginationState state) {
    final balanceText = state.isLoading
        ? '...'
        : _formatCurrency(state.totalBillBalance ?? 0);
    final countText = state.isLoading
        ? '...'
        : '${state.totalCount ?? 0}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 32,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // TOTAL OUTSTANDING BILL BALANCE
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFFDC2626),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'TOTAL OUTSTANDING BILL BALANCE',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            balanceText,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFDC2626),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Divider between stats on wider screens
                  Container(
                    width: 1,
                    height: 36,
                    color: const Color(0xFFE2E8F0),
                  ),

                  // TOTAL PROVIDERS
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F9FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFBAE6FD)),
                        ),
                        child: const Icon(
                          Icons.people_alt_rounded,
                          color: Color(0xFF0284C7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'PROVIDERS',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            countText,
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (state.isLoadingPage)
              const Padding(
                padding: EdgeInsets.only(left: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ------------------------------------------------------------
  /// CONTENT (Stack with table/cards and overlays)
  /// ------------------------------------------------------------

  Widget _buildContent(PayPerLeadPaginationState state, bool isDesktop) {
    /// INITIAL LOADING ONLY (when no providers are available yet)
    if (state.isLoading && state.providers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF0284C7)),
            SizedBox(height: 16),
            Text(
              'Loading Pay Per Lead providers...',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
          ],
        ),
      );
    }

    /// INITIAL LOAD ERROR
    if (state.errorMessage != null && state.providers.isEmpty) {
      return _buildInitialError(state);
    }

    /// NO RESULTS
    if (state.providers.isEmpty) {
      return _buildEmptyState();
    }

    /// DATA PRESENT: Render full scrollable content
    return Stack(
      children: [
        Positioned.fill(
          child: isDesktop
              ? _buildDesktopTable(state)
              : _buildMobileCardsList(state),
        ),

        /// Loading badge while navigating pages (without removing table content)
        if (state.isLoadingPage)
          Positioned(
            top: 10,
            right: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading page...',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ),

        /// Page error banner if page navigation encounters an issue
        if (state.errorMessage != null && !state.isLoading)
          Positioned(
            left: 24,
            right: 24,
            bottom: 12,
            child: _buildPageError(state.errorMessage!),
          ),
      ],
    );
  }

  Widget _buildInitialError(PayPerLeadPaginationState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            'Failed to load Pay Per Lead data',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              state.errorMessage ?? '',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              ref.read(payPerLeadPaginationProvider.notifier).fetchInitial();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
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

  Widget _buildPageError(String error) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFED7AA)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: Color(0xFFEA580C),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                error,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: const Color(0xFF9A3412),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Pay-Per-Lead Providers Found',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'No providers with outstanding PPL charges match the selected filters.',
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

  /// ------------------------------------------------------------
  /// DESKTOP TABLE (2D Scrollable: Vertical + Horizontal)
  /// ------------------------------------------------------------

  Widget _buildDesktopTable(PayPerLeadPaginationState state) {
    final providers = state.providers;
    const double minTableWidth = 1450.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
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
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          trackVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: minTableWidth),
              child: Scrollbar(
                controller: _verticalScrollController,
                thumbVisibility: true,
                trackVisibility: true,
                child: SingleChildScrollView(
                  controller: _verticalScrollController,
                  scrollDirection: Axis.vertical,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF8FAFC),
                    ),
                    dataRowMaxHeight: 64,
                    headingRowHeight: 52,
                    columnSpacing: 24,
                    horizontalMargin: 20,
                    showCheckboxColumn: false,
                    columns: [
                      DataColumn(
                        label: Text(
                          'S.No',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Business Name',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Phone',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Address',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Bill Balance',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'PPL Payment Date',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Transaction ID',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Overall PPL Amount',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Active Plan',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Payment Date',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    rows: List.generate(providers.length, (index) {
                      final user = providers[index];
                      final sn =
                          (state.currentPage * state.pageSize) + index + 1;

                      return DataRow(
                        onSelectChanged: (_) => _showReadOnlyDetails(user),
                        cells: [
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
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                user.businessname?.trim().isNotEmpty == true
                                    ? user.businessname!
                                    : '--',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              user.phone != null ? '${user.phone}' : '--',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 220),
                              child: Text(
                                user.businessaddress?.trim().isNotEmpty == true
                                    ? user.businessaddress!
                                    : '--',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(_buildBillBalance(user.payperLeadCharge)),
                          DataCell(
                            Text(
                              _formatDate(user.lastpaymentpayperlead),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF334155),
                              ),
                            ),
                          ),
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Text(
                                user.lastpayperleadtransactionid
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? user.lastpayperleadtransactionid!
                                    : '--',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF0284C7),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              user.overallpayperleadamount != null
                                  ? _formatCurrency(user.overallpayperleadamount)
                                  : '--',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: user.overallpayperleadamount != null
                                    ? const Color(0xFF0F172A)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              user.activePlan != null
                                  ? _formatCurrency(user.activePlan)
                                  : '--',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatDate(user.paymentDate),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF334155),
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
          ),
        ),
      ),
    );
  }

  Widget _buildBillBalance(num? amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        _formatCurrency(amount),
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFDC2626),
        ),
      ),
    );
  }

  /// ------------------------------------------------------------
  /// MOBILE LIST (Responsive Card Layout)
  /// ------------------------------------------------------------

  Widget _buildMobileCardsList(PayPerLeadPaginationState state) {
    final providers = state.providers;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: providers.length,
      itemBuilder: (context, index) {
        final user = providers[index];
        final sn = (state.currentPage * state.pageSize) + index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: InkWell(
            onTap: () => _showReadOnlyDetails(user),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$sn',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user.businessname?.trim().isNotEmpty == true
                              ? user.businessname!
                              : '--',
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildBillBalance(user.payperLeadCharge),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.phone_rounded,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        user.phone != null ? '${user.phone}' : '--',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                  if (user.businessaddress?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            user.businessaddress!,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _buildMobileDetailItem(
                        'PPL Payment Date',
                        _formatDate(user.lastpaymentpayperlead),
                      ),
                      _buildMobileDetailItem(
                        'Transaction ID',
                        user.lastpayperleadtransactionid?.trim().isNotEmpty ==
                                true
                            ? user.lastpayperleadtransactionid!
                            : '--',
                      ),
                      _buildMobileDetailItem(
                        'Overall PPL Amount',
                        user.overallpayperleadamount != null
                            ? _formatCurrency(user.overallpayperleadamount)
                            : '--',
                      ),
                      _buildMobileDetailItem(
                        'Active Plan',
                        user.activePlan != null
                            ? _formatCurrency(user.activePlan)
                            : '--',
                      ),
                      _buildMobileDetailItem(
                        'Payment Date',
                        _formatDate(user.paymentDate),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileDetailItem(String label, String value) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------------------
  /// PAGINATION FOOTER (Pinned at bottom, stays visible)
  /// ------------------------------------------------------------

  Widget _buildPaginationFooter(PayPerLeadPaginationState state) {
    final int total = state.totalCount ?? state.providers.length;
    final int start = total == 0 ? 0 : (state.currentPage * state.pageSize) + 1;
    final int end = total == 0
        ? 0
        : min((state.currentPage + 1) * state.pageSize, total);

    final int totalPages = state.totalCount != null
        ? max(1, ((state.totalCount! + state.pageSize - 1) ~/ state.pageSize))
        : (state.currentPage + 1);

    final bool canGoPrevious = state.currentPage > 0 && !state.isLoadingPage;
    final bool canGoNext = state.hasNextPage && !state.isLoadingPage;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              total > 0
                  ? 'Showing $start–$end of $total providers'
                  : state.isLoading
                      ? 'Loading providers...'
                      : 'No providers to display',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous Page',
                onPressed: canGoPrevious
                    ? () {
                        ref
                            .read(payPerLeadPaginationProvider.notifier)
                            .prevPage();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  state.totalCount != null
                      ? 'Page ${state.currentPage + 1} of $totalPages'
                      : 'Page ${state.currentPage + 1}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Next Page',
                onPressed: canGoNext
                    ? () {
                        ref
                            .read(payPerLeadPaginationProvider.notifier)
                            .nextPage();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// ------------------------------------------------------------
  /// READ-ONLY DETAILS MODAL DIALOG WITH FEEDBACK
  /// ------------------------------------------------------------

  void _showReadOnlyDetails(UserModel user) {
    showDialog(
      context: context,
      builder: (ctx) => _PayPerLeadDetailsDialog(user: user),
    );
  }

  /// ------------------------------------------------------------
  /// FORMATTERS
  /// ------------------------------------------------------------

  String _formatCurrency(num? value) {
    final int intValue = (value ?? 0).toInt();
    final formatter = NumberFormat('#,##,###');
    return '₹${formatter.format(intValue)}';
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return '--';
    }
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }
}

/// Modal dialog showing complete Pay Per Lead provider details and an
/// editable Feedback section persisted directly to users/{userId}.
class _PayPerLeadDetailsDialog extends ConsumerStatefulWidget {
  final UserModel user;

  const _PayPerLeadDetailsDialog({required this.user});

  @override
  ConsumerState<_PayPerLeadDetailsDialog> createState() =>
      _PayPerLeadDetailsDialogState();
}

class _PayPerLeadDetailsDialogState
    extends ConsumerState<_PayPerLeadDetailsDialog> {
  late final TextEditingController _feedbackController;
  bool _isSaving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _feedbackController = TextEditingController(
      text: widget.user.payPerLeadFeedback ?? '',
    );
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _saveFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _validationError = 'Please enter feedback before saving.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      final repo = ref.read(userRepositoryProvider);
      await repo.savePayPerLeadFeedback(
        userId: widget.user.id,
        feedback: text,
      );

      // Update in-memory state so it's immediately reflected
      ref
          .read(payPerLeadPaginationProvider.notifier)
          .updateProviderFeedback(widget.user.id, text);

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Feedback saved successfully',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _validationError = 'Failed to save feedback: $e';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save feedback: $e',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = min(screenWidth * 0.9, 520.0);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: Color(0xFF0284C7),
              size: 22,
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
                      : '--',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'UID: ${user.uid ?? user.id}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRow('Phone', user.phone != null ? '${user.phone}' : '--'),
              _buildRow(
                'Address',
                user.businessaddress?.trim().isNotEmpty == true
                    ? user.businessaddress!
                    : '--',
              ),
              _buildRow('City', user.city ?? user.cityKey ?? '--'),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),
              _buildRow(
                'Bill Balance',
                _formatCurrency(user.payperLeadCharge),
              ),
              _buildRow(
                'PPL Payment Date',
                _formatDate(user.lastpaymentpayperlead),
              ),
              _buildRow(
                'Transaction ID',
                user.lastpayperleadtransactionid?.trim().isNotEmpty == true
                    ? user.lastpayperleadtransactionid!
                    : '--',
              ),
              _buildRow(
                'Overall PPL Amount',
                user.overallpayperleadamount != null
                    ? _formatCurrency(user.overallpayperleadamount)
                    : '--',
              ),
              _buildRow(
                'Active Plan',
                user.activePlan != null
                    ? _formatCurrency(user.activePlan)
                    : '--',
              ),
              _buildRow('Payment Date', _formatDate(user.paymentDate)),
              const SizedBox(height: 12),
              const Divider(height: 24, color: Color(0xFFF1F5F9)),

              // FEEDBACK SECTION
              Text(
                'FEEDBACK',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _feedbackController,
                minLines: 3,
                maxLines: 4,
                maxLength: 1000,
                onChanged: (_) {
                  if (_validationError != null) {
                    setState(() {
                      _validationError = null;
                    });
                  }
                },
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Enter feedback about this provider/payment...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF94A3B8),
                  ),
                  errorText: _validationError,
                  errorStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFFDC2626),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF0284C7),
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveFeedback,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_rounded, size: 16),
                  label: Text(_isSaving ? 'Saving...' : 'Save Feedback'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Close',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0284C7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
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

  String _formatCurrency(num? value) {
    final int intValue = (value ?? 0).toInt();
    final formatter = NumberFormat('#,##,###');
    return '₹${formatter.format(intValue)}';
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) return '--';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
  }
}
