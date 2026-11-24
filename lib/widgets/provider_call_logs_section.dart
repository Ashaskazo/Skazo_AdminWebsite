// ignore_for_file: deprecated_member_use
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/utils/responsive.dart';

/// Data model representing a single call log record associated with a Provider.
class ProviderCallLogItem {
  final String id;
  final String businessId;
  final String customerName;
  final String customerPhone;
  final String rawCustomerPhone;
  final String feedbackStatus;
  final String salesStatus;
  final DateTime? timestamp;
  final Map<String, dynamic> rawData;

  const ProviderCallLogItem({
    required this.id,
    required this.businessId,
    required this.customerName,
    required this.customerPhone,
    required this.rawCustomerPhone,
    required this.feedbackStatus,
    required this.salesStatus,
    this.timestamp,
    this.rawData = const {},
  });

  factory ProviderCallLogItem.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ProviderCallLogItem.fromMap(doc.id, data);
  }

  factory ProviderCallLogItem.fromMap(
    String docId,
    Map<String, dynamic> data,
  ) {
    // 1. Customer Name (Firestore field: customerName, fallback to callerName if empty)
    final rawName = (data['customerName'] ?? data['callerName'])?.toString().trim();
    final customerName = (rawName != null && rawName.isNotEmpty) ? rawName : 'N/A';

    // 2. Customer Phone (Firestore field: customerPhone, fallback to callerPhone or customerNumber)
    final rawPhone = (data['customerPhone'] ??
            data['callerPhone'] ??
            data['customerNumber'])
        ?.toString()
        .trim() ??
        '';
    final formattedPhone = formatReadablePhoneNumber(rawPhone);

    // 3. Feedback Status (Firestore field: feedbackStatus)
    // Represents feedback provided by service provider.
    final rawFeedback = data['feedbackStatus']?.toString().trim();
    final feedbackStatus =
        (rawFeedback != null && rawFeedback.isNotEmpty) ? rawFeedback : 'N/A';

    // 4. Sales Status (Firestore field: status)
    // Read directly from respective callLogs document.
    final rawSales = data['status']?.toString().trim();
    final salesStatus =
        (rawSales != null && rawSales.isNotEmpty) ? rawSales : 'N/A';

    // 5. Timestamp
    final ts = _parseTimestamp(data['timestamp'] ?? data['createdAt']);

    // 6. Business ID
    final bId = (data['businessId'] ??
            data['business_id'] ??
            data['providerId'] ??
            data['uid'])
        ?.toString()
        .trim() ??
        '';

    return ProviderCallLogItem(
      id: docId,
      businessId: bId,
      customerName: customerName,
      customerPhone: formattedPhone,
      rawCustomerPhone: rawPhone,
      feedbackStatus: feedbackStatus,
      salesStatus: salesStatus,
      timestamp: ts,
      rawData: data,
    );
  }

  /// Formats raw phone number string into a clean readable format.
  /// Preserves the original format if already formatted or not a standard 10/12-digit number.
  static String formatReadablePhoneNumber(String? rawPhone) {
    if (rawPhone == null || rawPhone.trim().isEmpty) return 'N/A';
    final phone = rawPhone.trim();
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    } else if (digits.length == 12 && digits.startsWith('91')) {
      final ten = digits.substring(2);
      return '+91 ${ten.substring(0, 5)} ${ten.substring(5)}';
    }
    return phone;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  String get formattedDateTime {
    if (timestamp == null) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp!.toLocal());
    } catch (_) {
      return 'N/A';
    }
  }
}

/// Provider Call Logs Section
/// Displays all call log records associated with the selected provider,
/// matching `callLogs.businessId == selectedProviderId`.
class ProviderCallLogsSection extends StatefulWidget {
  final String providerId;
  final String? providerUid;
  final Map<String, dynamic>? providerData;
  final Stream<List<ProviderCallLogItem>>? callLogsStream;
  final FirebaseFirestore? firestore;

  const ProviderCallLogsSection({
    super.key,
    String? providerId,
    String? providerUid,
    this.providerData,
    this.callLogsStream,
    this.firestore,
  })  : providerId = providerId ?? providerUid ?? '',
        providerUid = providerUid ?? providerId;

  @override
  State<ProviderCallLogsSection> createState() => _ProviderCallLogsSectionState();
}

class _ProviderCallLogsSectionState extends State<ProviderCallLogsSection> {
  late Stream<List<ProviderCallLogItem>> _stream;
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _stream = widget.callLogsStream ?? _buildCallLogsStream();
  }

  @override
  void didUpdateWidget(covariant ProviderCallLogsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerId != widget.providerId ||
        oldWidget.callLogsStream != widget.callLogsStream) {
      _stream = widget.callLogsStream ?? _buildCallLogsStream();
      _currentPage = 0;
    }
  }

  Stream<List<ProviderCallLogItem>> _buildCallLogsStream() {
    final pid = widget.providerId.trim();
    if (pid.isEmpty) {
      return Stream.value(const <ProviderCallLogItem>[]);
    }

    try {
      final fs = widget.firestore ?? FirebaseFirestore.instance;

      // Check if providerData has an alternate ID (e.g. docId vs uid)
      final uid = widget.providerData?['uid']?.toString().trim();
      final docId = (widget.providerData?['id'] ?? widget.providerData?['docId'])
          ?.toString()
          .trim();
      final Set<String> ids = {
        pid,
        if (uid != null && uid.isNotEmpty) uid,
        if (docId != null && docId.isNotEmpty) docId,
      };

      Query<Map<String, dynamic>> query = fs.collection('callLogs');
      if (ids.length == 1) {
        query = query.where('businessId', isEqualTo: ids.first);
      } else {
        query = query.where('businessId', whereIn: ids.toList());
      }

      return query.snapshots().map((snapshot) {
        final list = snapshot.docs
            .map((doc) => ProviderCallLogItem.fromFirestore(doc))
            .toList();
        // Sort in memory by timestamp descending (latest call logs first)
        list.sort((a, b) {
          if (a.timestamp == null && b.timestamp == null) return 0;
          if (a.timestamp == null) return 1;
          if (b.timestamp == null) return -1;
          return b.timestamp!.compareTo(a.timestamp!);
        });
        return list;
      });
    } catch (_) {
      // Return empty stream in test environments where Firebase is not initialized
      return Stream.value(const <ProviderCallLogItem>[]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    return StreamBuilder<List<ProviderCallLogItem>>(
      stream: _stream,
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState();
        }

        // 2. Error State
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final items = snapshot.data ?? const <ProviderCallLogItem>[];

        // 3. Empty State
        if (items.isEmpty) {
          return _buildEmptyState();
        }

        // 4. Data Table with Pagination
        final totalItems = items.length;
        final totalPages = (totalItems / _pageSize).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }

        final startIndex = _currentPage * _pageSize;
        final endIndex = min(startIndex + _pageSize, totalItems);
        final pageItems = items.sublist(startIndex, endIndex);

        return Container(
          key: const ValueKey('provider_call_logs_content'),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Summary Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Call Log Records',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
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
                            '$totalItems ${totalItems == 1 ? 'Record' : 'Records'}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Live Data',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Desktop DataTable or Mobile Cards
              if (!isMobile)
                _buildDesktopTable(pageItems, startIndex)
              else
                _buildMobileCards(pageItems, startIndex),

              // Pagination Footer
              if (totalItems > 10) ...[
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                _buildPaginationBar(
                  startIndex: startIndex + 1,
                  endIndex: endIndex,
                  totalItems: totalItems,
                  totalPages: totalPages,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Desktop / Tablet DataTable
  Widget _buildDesktopTable(
    List<ProviderCallLogItem> pageItems,
    int startIndex,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 700),
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
          dataRowMaxHeight: 58,
          columnSpacing: 24,
          horizontalMargin: 20,
          columns: [
            DataColumn(
              label: Text(
                'Sl No',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Customer Name',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Customer Phone',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Feedback Status',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            DataColumn(
              label: Text(
                'Sales Status',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
          ],
          rows: List.generate(pageItems.length, (index) {
            final item = pageItems[index];
            final slNo = startIndex + index + 1;

            return DataRow(
              cells: [
                // 1. Sl No
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

                // 2. Customer Name
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        item.customerName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: item.customerName != 'N/A'
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: item.customerName != 'N/A'
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Customer Phone
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SelectableText(
                        item.customerPhone,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: item.customerPhone != 'N/A'
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: item.customerPhone != 'N/A'
                              ? const Color(0xFF334155)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                      if (item.customerPhone != 'N/A') ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          tooltip: 'Copy Phone',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _copyPhone(item.rawCustomerPhone),
                        ),
                      ],
                    ],
                  ),
                ),

                // 4. Feedback Status
                DataCell(
                  _buildFeedbackBadge(item.feedbackStatus),
                ),

                // 5. Sales Status
                DataCell(
                  _buildSalesStatusBadge(item.salesStatus),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  /// Mobile Cards List (< 720px)
  Widget _buildMobileCards(
    List<ProviderCallLogItem> pageItems,
    int startIndex,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      itemCount: pageItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = pageItems[index];
        final slNo = startIndex + index + 1;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Sl No + Customer Name + Copy Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$slNo',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.customerName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: item.customerName != 'N/A'
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  if (item.customerPhone != 'N/A')
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 15,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Copy Phone',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _copyPhone(item.rawCustomerPhone),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Phone Number Row
              Row(
                children: [
                  const Icon(
                    Icons.phone_rounded,
                    size: 14,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    item.customerPhone,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.customerPhone != 'N/A'
                          ? const Color(0xFF334155)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Status Badges Row: Feedback Status + Sales Status
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Feedback: ',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      _buildFeedbackBadge(item.feedbackStatus),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sales: ',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      _buildSalesStatusBadge(item.salesStatus),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Feedback Status Badge
  Widget _buildFeedbackBadge(String status) {
    if (status == 'N/A') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          'N/A',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    final color = _getFeedbackBadgeColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _getFeedbackBadgeColor(String status) {
    final norm = status.trim().toLowerCase();
    if (norm == 'completed' || norm == 'converted' || norm == 'connected') {
      return const Color(0xFF059669); // Emerald green
    }
    if (norm == 'pending' || norm == 'in_progress' || norm == 'callback') {
      return const Color(0xFFD97706); // Amber
    }
    if (norm == 'failed' ||
        norm == 'rejected' ||
        norm == 'not converted' ||
        norm == 'not converetd') {
      return const Color(0xFFDC2626); // Red
    }
    return const Color(0xFF64748B); // Slate
  }

  /// Sales Status Badge (Directly from Firestore field: status)
  Widget _buildSalesStatusBadge(String status) {
    if (status == 'N/A') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          'N/A',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF94A3B8),
          ),
        ),
      );
    }

    final color = _getSalesStatusBadgeColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        status,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _getSalesStatusBadgeColor(String status) {
    final norm = status.trim().toLowerCase();
    if (norm == 'won' ||
        norm == 'success' ||
        norm == 'converted' ||
        norm == 'closed') {
      return const Color(0xFF059669); // Emerald green
    }
    if (norm == 'contacted' ||
        norm == 'open' ||
        norm == 'follow_up' ||
        norm == 'pending') {
      return const Color(0xFF0284C7); // Sky blue
    }
    if (norm == 'lost' || norm == 'rejected' || norm == 'cancelled') {
      return const Color(0xFFDC2626); // Red
    }
    return const Color(0xFF6366F1); // Indigo
  }

  /// Pagination Footer Bar
  Widget _buildPaginationBar({
    required int startIndex,
    required int endIndex,
    required int totalItems,
    required int totalPages,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Showing $startIndex–$endIndex of $totalItems records',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Page Size Selector
              Text(
                'Per page: ',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
              DropdownButton<int>(
                value: _pageSize,
                underline: const SizedBox.shrink(),
                items: const [10, 25, 50].map((size) {
                  return DropdownMenuItem<int>(
                    value: size,
                    child: Text(
                      '$size',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (newSize) {
                  if (newSize != null) {
                    setState(() {
                      _pageSize = newSize;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              const SizedBox(width: 8),

              // Previous Page Button
              IconButton(
                key: const ValueKey('provider_call_logs_prev_btn'),
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: _currentPage > 0
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Previous Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),

              // Page Indicator
              Text(
                '${_currentPage + 1} / $totalPages',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),

              // Next Page Button
              IconButton(
                key: const ValueKey('provider_call_logs_next_btn'),
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: _currentPage < totalPages - 1
                    ? () => setState(() => _currentPage++)
                    : null,
                tooltip: 'Next Page',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Empty State Card
  Widget _buildEmptyState() {
    return Container(
      key: const ValueKey('provider_call_logs_empty_state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_missed_rounded,
              size: 32,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Call Logs Found',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              'There are no call log records associated with this provider yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Error State Card
  Widget _buildErrorState(String error) {
    return Container(
      key: const ValueKey('provider_call_logs_error_state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 34,
            color: Color(0xFFEF4444),
          ),
          const SizedBox(height: 10),
          Text(
            'Error Loading Provider Call Logs',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF991B1B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFB91C1C),
            ),
          ),
        ],
      ),
    );
  }

  /// Loading State Card
  Widget _buildLoadingState() {
    return Container(
      key: const ValueKey('provider_call_logs_loading_state'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF0284C7),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Loading provider call logs...',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  void _copyPhone(String phone) {
    if (phone.isEmpty) return;
    Clipboard.setData(ClipboardData(text: phone));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Phone copied: $phone'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
