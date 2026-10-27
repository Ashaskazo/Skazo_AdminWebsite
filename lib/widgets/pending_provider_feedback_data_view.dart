import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/providers/pending_feedback_provider.dart';

/// Full-page widget for the "Pending Provider Feedback" entity.
///
/// Displays service providers that have at least one callLog document
/// with feedbackStatus == "pending", de-duplicated by businessId.
class PendingProviderFeedbackDataView extends ConsumerStatefulWidget {
  const PendingProviderFeedbackDataView({super.key});

  @override
  ConsumerState<PendingProviderFeedbackDataView> createState() =>
      _PendingProviderFeedbackDataViewState();
}

class _PendingProviderFeedbackDataViewState
    extends ConsumerState<PendingProviderFeedbackDataView> {
  final TextEditingController _searchController = TextEditingController();

  // Pagination
  static const int _pageSize = 15;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      ref
          .read(pendingFeedbackProvider.notifier)
          .setSearchQuery(_searchController.text);
      // Reset to first page when the query changes.
      if (_currentPage != 0) {
        setState(() => _currentPage = 0);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pendingFeedbackProvider);
    final filtered = state.filtered;

    final totalPages =
        filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _pageSize) + 1;
    // Clamp current page in case data shrinks (e.g. after real-time update).
    final page = _currentPage.clamp(0, totalPages - 1);
    final startIndex = page * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, filtered.length);
    final pageRows = filtered.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(state),
        Expanded(
          child:
              state.isLoading
                  ? _buildLoadingState()
                  : state.error != null
                  ? _buildErrorState(state.error!)
                  : filtered.isEmpty
                  ? _buildEmptyState()
                  : _buildTableArea(
                    pageRows,
                    filtered.length,
                    page,
                    totalPages,
                  ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(PendingFeedbackState state) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF59E0B,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.feedback_rounded,
                            color: Color(0xFFF59E0B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Pending Provider Feedback',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Count badge
                        if (!state.isLoading)
                          _buildCountBadge(state.providers.length),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Service providers with at least one call log awaiting feedback',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _currentPage = 0);
                    ref.read(pendingFeedbackProvider.notifier).refresh();
                  },
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFFF59E0B),
                    size: 22,
                  ),
                  tooltip: 'Refresh Pending Feedback List',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Search bar
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        '$count Pending',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFB45309),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.poppins(
          fontSize: 13.5,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          hintText: 'Search by provider, customer, phone, or business name…',
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
              _searchController.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _currentPage = 0);
                    },
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 12,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Loading / Error / Empty
  // ---------------------------------------------------------------------------

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFF59E0B), strokeWidth: 2.5),
          SizedBox(height: 16),
          Text(
            'Loading pending feedback…',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFEF4444),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load pending feedback',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed:
                  () => ref.read(pendingFeedbackProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
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

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.check_circle_outline_rounded,
              color:
                  hasSearch ? const Color(0xFF94A3B8) : const Color(0xFF10B981),
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'No providers match your search'
                  : 'No Pending Feedback',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Try adjusting your search query.'
                  : 'All service providers have been followed up. Great work! 🎉',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Table
  // ---------------------------------------------------------------------------

  Widget _buildTableArea(
    List<PendingFeedbackProvider> pageRows,
    int totalFiltered,
    int page,
    int totalPages,
  ) {
    final globalStartIndex = page * _pageSize;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              children: [
                _buildTable(pageRows, globalStartIndex),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        _buildPaginationBar(totalFiltered, page, totalPages),
      ],
    );
  }

  Widget _buildTable(List<PendingFeedbackProvider> rows, int globalStartIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(64), // Serial No.
          1: FlexColumnWidth(2.5), // Name
          2: FlexColumnWidth(2), // Phone
          3: FlexColumnWidth(3), // Business Name
          4: FlexColumnWidth(2.5), // Cus Name
          5: FlexColumnWidth(2), // Cus Ph
          6: FlexColumnWidth(3), // Timestamp
        },
        border: TableBorder(
          horizontalInside: BorderSide(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
          ),
        ),
        children: [
          _buildHeaderRow(),
          for (var i = 0; i < rows.length; i++)
            _buildDataRow(rows[i], globalStartIndex + i + 1, i.isEven),
        ],
      ),
    );
  }

  TableRow _buildHeaderRow() {
    return TableRow(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFEF3C7).withValues(alpha: 0.7),
            const Color(0xFFFDE68A).withValues(alpha: 0.4),
          ],
        ),
      ),
      children: [
        _buildHeaderCell('S.No', TextAlign.center),
        _buildHeaderCell('Name'),
        _buildHeaderCell('Phone'),
        _buildHeaderCell('Business Name'),
        _buildHeaderCell('Cus Name'),
        _buildHeaderCell('Cus Ph'),
        _buildHeaderCell('Timestamp'),
      ],
    );
  }

  Widget _buildHeaderCell(String text, [TextAlign align = TextAlign.left]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      child: Text(
        text,
        textAlign: align,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF92400E),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  TableRow _buildDataRow(
    PendingFeedbackProvider provider,
    int serialNo,
    bool isEven,
  ) {
    final bg = isEven ? Colors.white : const Color(0xFFFAFAFB);

    return TableRow(
      decoration: BoxDecoration(color: bg),
      children: [
        // 0: Serial No.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Text(
            '$serialNo',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        // 1: Name
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Text(
            provider.name,
            style: GoogleFonts.poppins(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ),
        // 2: Phone
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  provider.phone,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              if (provider.phone != '—')
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Copy phone',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: provider.phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Phone ${provider.phone} copied',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF0F172A),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        // 3: Business Name
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Text(
            provider.businessName,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        // 4: Cus Name
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Text(
            provider.cusName,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF334155),
            ),
          ),
        ),
        // 5: Cus Ph
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  provider.cusPhone,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF334155),
                  ),
                ),
              ),
              if (provider.cusPhone != '—')
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 14,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Copy customer phone',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: provider.cusPhone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Customer phone ${provider.cusPhone} copied',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: const Color(0xFF0F172A),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
        // 6: Timestamp
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          child: Text(
            provider.timestamp != null
                ? DateFormat(
                  'dd MMM yyyy, hh:mm a',
                ).format(provider.timestamp!.toLocal())
                : '—',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Pagination bar
  // ---------------------------------------------------------------------------

  Widget _buildPaginationBar(int total, int page, int totalPages) {
    final startRow = total == 0 ? 0 : page * _pageSize + 1;
    final endRow = ((page + 1) * _pageSize).clamp(0, total);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            total == 0
                ? 'No providers'
                : 'Showing $startRow–$endRow of $total provider${total == 1 ? '' : 's'}',
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              // First page
              _pageButton(
                icon: Icons.first_page_rounded,
                onPressed:
                    page > 0 ? () => setState(() => _currentPage = 0) : null,
                tooltip: 'First page',
              ),
              const SizedBox(width: 4),
              // Previous page
              _pageButton(
                icon: Icons.chevron_left_rounded,
                onPressed:
                    page > 0
                        ? () => setState(() => _currentPage = page - 1)
                        : null,
                tooltip: 'Previous page',
              ),
              const SizedBox(width: 10),
              Text(
                'Page ${page + 1} / $totalPages',
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 10),
              // Next page
              _pageButton(
                icon: Icons.chevron_right_rounded,
                onPressed:
                    page < totalPages - 1
                        ? () => setState(() => _currentPage = page + 1)
                        : null,
                tooltip: 'Next page',
              ),
              const SizedBox(width: 4),
              // Last page
              _pageButton(
                icon: Icons.last_page_rounded,
                onPressed:
                    page < totalPages - 1
                        ? () => setState(() => _currentPage = totalPages - 1)
                        : null,
                tooltip: 'Last page',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pageButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  onPressed != null
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                      : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color:
                  onPressed != null
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFCBD5E1),
            ),
          ),
        ),
      ),
    );
  }
}
