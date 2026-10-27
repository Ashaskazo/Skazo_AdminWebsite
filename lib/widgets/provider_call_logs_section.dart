import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

/// Displays a paginated call logs table for a specific service provider
/// at the bottom of the BusinessProfile & Settings page.
///
/// Strictly filters call logs on or after the provider's `paymentDate`
/// stored in `users/{providerUid}`.
class ProviderCallLogsSection extends StatefulWidget {
  final String? providerUid;

  const ProviderCallLogsSection({super.key, required this.providerUid});

  @override
  State<ProviderCallLogsSection> createState() =>
      _ProviderCallLogsSectionState();
}

class _ProviderCallLogsSectionState extends State<ProviderCallLogsSection> {
  static const int _pageSize = 20;

  final List<DocumentSnapshot<Map<String, dynamic>>> _callLogDocs = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  String? _errorMessage;
  String? _loadMoreError;
  String? _activeProviderUid;

  // Payment date state strictly from users/{providerUid}.paymentDate
  Timestamp? _paymentDateTimestamp;
  bool _isPaymentDateUnavailable = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialLogs();
  }

  @override
  void didUpdateWidget(covariant ProviderCallLogsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.providerUid != widget.providerUid) {
      _fetchInitialLogs();
    }
  }

  /// Parses any Firestore-compatible timestamp representation into a native [Timestamp].
  ///
  /// Returns null if missing, null, or invalid.
  static Timestamp? _parseFirestoreTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw;
    if (raw is DateTime) return Timestamp.fromDate(raw);
    if (raw is int) {
      try {
        return Timestamp.fromMillisecondsSinceEpoch(raw);
      } catch (_) {
        return null;
      }
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return null;
  }

  Future<void> _fetchInitialLogs() async {
    final uid = widget.providerUid?.trim();
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _hasMore = false;
          _callLogDocs.clear();
          _lastDocument = null;
          _errorMessage = null;
          _loadMoreError = null;
          _activeProviderUid = null;
          _paymentDateTimestamp = null;
          _isPaymentDateUnavailable = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _errorMessage = null;
      _loadMoreError = null;
      _callLogDocs.clear();
      _lastDocument = null;
      _hasMore = false;
      _activeProviderUid = uid;
      _paymentDateTimestamp = null;
      _isPaymentDateUnavailable = false;
    });

    try {
      // 1. Read the selected provider's document from users collection using provider UID.
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!mounted) return;
      if (_activeProviderUid != uid) return;

      if (!userDoc.exists || userDoc.data() == null) {
        setState(() {
          _isLoading = false;
          _isPaymentDateUnavailable = true;
          _paymentDateTimestamp = null;
        });
        return;
      }

      // 2. Read paymentDate field exclusively from users/{providerUid}.
      final rawPaymentDate = userDoc.data()!['paymentDate'];
      final parsedCutoff = _parseFirestoreTimestamp(rawPaymentDate);

      // 8. If paymentDate is missing, null, invalid, or not a valid Firestore-compatible
      // timestamp, do not display unfiltered historical calls.
      if (parsedCutoff == null) {
        setState(() {
          _isLoading = false;
          _isPaymentDateUnavailable = true;
          _paymentDateTimestamp = null;
        });
        return;
      }

      _paymentDateTimestamp = parsedCutoff;
      _isPaymentDateUnavailable = false;

      // 4. Query callLogs using both businessId == providerUid AND timestamp >= paymentDate.
      // 5. Order results by timestamp descending.
      final query = FirebaseFirestore.instance
          .collection('callLogs')
          .where('businessId', isEqualTo: uid)
          .where('timestamp', isGreaterThanOrEqualTo: parsedCutoff)
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (!mounted) return;
      if (_activeProviderUid != uid) return;

      final docs = snapshot.docs;
      setState(() {
        _isLoading = false;
        _callLogDocs.addAll(docs);
        _lastDocument = docs.isNotEmpty ? docs.last : null;
        _hasMore = docs.length == _pageSize;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (_activeProviderUid != uid) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      if (_activeProviderUid != uid) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _fetchMoreLogs() async {
    final uid = _activeProviderUid;
    final cutoff = _paymentDateTimestamp;
    if (_isLoading || _isLoadingMore || !_hasMore || _lastDocument == null) {
      return;
    }
    if (uid == null || uid.isEmpty || cutoff == null) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      final query = FirebaseFirestore.instance
          .collection('callLogs')
          .where('businessId', isEqualTo: uid)
          .where('timestamp', isGreaterThanOrEqualTo: cutoff)
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();

      if (!mounted) return;
      if (_activeProviderUid != uid) return;

      final newDocs = snapshot.docs;
      final existingIds = _callLogDocs.map((d) => d.id).toSet();
      final uniqueNewDocs =
          newDocs.where((d) => !existingIds.contains(d.id)).toList();

      setState(() {
        _isLoadingMore = false;
        _callLogDocs.addAll(uniqueNewDocs);
        if (newDocs.isNotEmpty) {
          _lastDocument = newDocs.last;
        }
        _hasMore = newDocs.length == _pageSize;
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (_activeProviderUid != uid) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = e.message ?? e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      if (_activeProviderUid != uid) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = e.toString();
      });
    }
  }

  String _formatField(dynamic value, [dynamic fallback]) {
    if (value != null) {
      final str = value.toString().trim();
      if (str.isNotEmpty && str.toLowerCase() != 'null') {
        return str;
      }
    }
    if (fallback != null) {
      final str = fallback.toString().trim();
      if (str.isNotEmpty && str.toLowerCase() != 'null') {
        return str;
      }
    }
    return '—';
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF6366F1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading call logs...',
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

  Widget _buildPaymentDateUnavailableState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 32,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Provider's Payment Date is Unavailable",
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(
              'Call logs can only be displayed on or after the provider’s payment date. No valid paymentDate was found on this provider’s profile document.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF78350F),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchInitialLogs,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Refresh Payment Date',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final dateStr =
        _paymentDateTimestamp != null
            ? DateFormat(
              'dd MMM yyyy, hh:mm a',
            ).format(_paymentDateTimestamp!.toDate())
            : null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 16),
          Text(
            'No call logs found',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateStr != null
                ? 'No customer calls recorded on or after $dateStr.'
                : 'No customer calls have been logged for this service provider.',
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

  Widget _buildErrorState() {
    final isIndexError = _errorMessage?.toLowerCase().contains('index') == true;

    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isIndexError
                ? 'Firestore Index Required'
                : 'Failed to load call logs',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isIndexError
                  ? 'A composite index on callLogs (businessId ASC, timestamp DESC) is required in Firestore.'
                  : (_errorMessage ?? 'An unexpected error occurred.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchInitialLogs,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.providerUid?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header inside the card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provider Call Logs 📞',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _paymentDateTimestamp != null
                          ? 'Calls on or after paymentDate: ${DateFormat('dd MMM yyyy, hh:mm a').format(_paymentDateTimestamp!.toDate())}'
                          : 'Customer calls received on or after provider paymentDate',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              if (_paymentDateTimestamp != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.event_available_rounded,
                        size: 14,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Since ${DateFormat('dd MMM yyyy').format(_paymentDateTimestamp!.toDate())}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_callLogDocs.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    '${_callLogDocs.length} loaded',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF475569),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isLoading ? null : _fetchInitialLogs,
                tooltip: 'Refresh Call Logs & Payment Date',
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
          const SizedBox(height: 16),

          // Content States
          if (uid == null || uid.isEmpty)
            _buildEmptyState()
          else if (_isLoading)
            _buildLoadingState()
          else if (_errorMessage != null)
            _buildErrorState()
          else if (_isPaymentDateUnavailable)
            _buildPaymentDateUnavailableState()
          else if (_callLogDocs.isEmpty)
            _buildEmptyState()
          else ...[
            // Call Logs Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              clipBehavior: Clip.antiAlias,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF8FAFC),
                        ),
                        dataRowMinHeight: 52,
                        dataRowMaxHeight: 80,
                        horizontalMargin: 20,
                        columnSpacing: 28,
                        columns: [
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
                              'Sales Status',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Provider Status',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Sales Feedback Description',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                        rows:
                            _callLogDocs.map((doc) {
                              final data = doc.data() ?? {};
                              final name = _formatField(
                                data['customerName'],
                                data['callerName'],
                              );
                              final phone = _formatField(
                                data['customerPhone'],
                                data['customerNumber'] ?? data['callerPhone'],
                              );
                              final descriptionRaw =
                                  data['salesFeedbackDescription'];
                              final description =
                                  descriptionRaw != null &&
                                          descriptionRaw
                                              .toString()
                                              .trim()
                                              .isNotEmpty
                                      ? descriptionRaw.toString().trim()
                                      : null;

                              return DataRow(
                                key: ValueKey(doc.id),
                                cells: [
                                  DataCell(
                                    Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      phone,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  DataCell(_StatusDropdownCell(doc: doc)),
                                  DataCell(_FeedbackStatusCell(doc: doc)),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 260,
                                      ),
                                      child:
                                          description != null
                                              ? Tooltip(
                                                message: description,
                                                child: Text(
                                                  description,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 12,
                                                    color: const Color(
                                                      0xFF334155,
                                                    ),
                                                  ),
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )
                                              : Text(
                                                '—',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 13,
                                                  color: const Color(
                                                    0xFF94A3B8,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ),

            if (_loadMoreError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Failed to load more logs: $_loadMoreError',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF991B1B),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _fetchMoreLogs,
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_hasMore) ...[
              const SizedBox(height: 16),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _isLoadingMore ? null : _fetchMoreLogs,
                  icon:
                      _isLoadingMore
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF6366F1),
                            ),
                          )
                          : const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(
                    _isLoadingMore
                        ? 'Loading more calls...'
                        : 'Load More Calls',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF6366F1),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6366F1),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else if (_callLogDocs.isNotEmpty) ...[
              const SizedBox(height: 14),
              Center(
                child: Text(
                  'All call logs loaded (${_callLogDocs.length} total)',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Editable Status dropdown for each call log row.
///
/// Options are strictly 'Enquiry' and 'Converted'.
/// Updates `callLogs/{documentId}.status` immediately on change.
class _StatusDropdownCell extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;

  const _StatusDropdownCell({required this.doc});

  @override
  State<_StatusDropdownCell> createState() => _StatusDropdownCellState();
}

class _StatusDropdownCellState extends State<_StatusDropdownCell> {
  bool _isSaving = false;
  String? _currentValue;

  @override
  void initState() {
    super.initState();
    _currentValue = _normalizeStatus(widget.doc.data()?['status']);
  }

  @override
  void didUpdateWidget(covariant _StatusDropdownCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.id != widget.doc.id ||
        oldWidget.doc.data()?['status'] != widget.doc.data()?['status']) {
      if (!_isSaving) {
        setState(() {
          _currentValue = _normalizeStatus(widget.doc.data()?['status']);
        });
      }
    }
  }

  static String? _normalizeStatus(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.toLowerCase() == 'enquiry') return 'Enquiry';
    if (str.toLowerCase() == 'converted') return 'Converted';
    return null;
  }

  Future<void> _updateStatus(String newValue) async {
    if (_isSaving || newValue == _currentValue) return;

    final previousValue = _currentValue;
    setState(() {
      _isSaving = true;
      _currentValue = newValue;
    });

    try {
      await widget.doc.reference.update({'status': newValue});

      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to "$newValue"'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _currentValue = previousValue; // Revert on failure
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawStatus = widget.doc.data()?['status']?.toString().trim() ?? '';
    final isConverted = _currentValue == 'Converted';

    return Container(
      width: 140,
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isConverted ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isConverted ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _currentValue,
          isExpanded: true,
          hint: Text(
            rawStatus.isNotEmpty ? rawStatus : 'Select',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          icon:
              _isSaving
                  ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF6366F1),
                    ),
                  )
                  : const Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color:
                isConverted ? const Color(0xFF065F46) : const Color(0xFF0F172A),
          ),
          items: const [
            DropdownMenuItem(value: 'Enquiry', child: Text('Enquiry')),
            DropdownMenuItem(value: 'Converted', child: Text('Converted')),
          ],
          onChanged:
              _isSaving
                  ? null
                  : (val) {
                    if (val != null) {
                      _updateStatus(val);
                    }
                  },
        ),
      ),
    );
  }
}

/// Editable Feedback Status text field for each call log row.
///
/// Updates `callLogs/{documentId}.feedbackStatus` on Enter or when focus is lost.
class _FeedbackStatusCell extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>> doc;

  const _FeedbackStatusCell({required this.doc});

  @override
  State<_FeedbackStatusCell> createState() => _FeedbackStatusCellState();
}

class _FeedbackStatusCellState extends State<_FeedbackStatusCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isSaving = false;
  bool _hasError = false;
  String? _errorMessage;
  String _lastSavedText = '';

  @override
  void initState() {
    super.initState();
    final data = widget.doc.data() ?? {};
    final initial =
        (data['feedbackStatus'] ?? data['salesFeedbackStatus'] ?? '')
            .toString()
            .trim();
    _lastSavedText = initial;
    _controller = TextEditingController(text: initial);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _FeedbackStatusCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doc.id != widget.doc.id) {
      final data = widget.doc.data() ?? {};
      final initial =
          (data['feedbackStatus'] ?? data['salesFeedbackStatus'] ?? '')
              .toString()
              .trim();
      _lastSavedText = initial;
      _controller.text = initial;
      _hasError = false;
      _errorMessage = null;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // User finished editing by clicking away/unfocusing
      final currentText = _controller.text.trim();
      if (currentText != _lastSavedText && !_isSaving) {
        _saveFeedback(currentText);
      }
    }
  }

  Future<void> _saveFeedback(String newText) async {
    if (_isSaving) return;
    if (newText == _lastSavedText && !_hasError) return;

    setState(() {
      _isSaving = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      await widget.doc.reference.update({'feedbackStatus': newText});

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _lastSavedText = newText;
        _hasError = false;
      });

      final customerName =
          widget.doc.data()?['customerName']?.toString().trim();
      final target =
          (customerName != null && customerName.isNotEmpty)
              ? customerName
              : 'call log';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback saved for $target'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasError = true;
        _errorMessage = e.toString();
      });

      // Do not lose the text! User's text remains in _controller.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save feedback: $e'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _saveFeedback(_controller.text.trim()),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 38,
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textInputAction: TextInputAction.done,
        onSubmitted: (val) => _saveFeedback(val.trim()),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF0F172A),
        ),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          hintText: 'Enter feedback note...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF94A3B8),
          ),
          filled: true,
          fillColor:
              _hasError ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color:
                  _hasError ? const Color(0xFFFCA5A5) : const Color(0xFFCBD5E1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color:
                  _hasError ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
              width: 1.5,
            ),
          ),
          suffixIconConstraints: const BoxConstraints(
            maxHeight: 38,
            maxWidth: 36,
          ),
          suffixIcon:
              _isSaving
                  ? const Center(
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  )
                  : _hasError
                  ? IconButton(
                    icon: const Icon(
                      Icons.error_outline,
                      size: 16,
                      color: Color(0xFFEF4444),
                    ),
                    tooltip: _errorMessage ?? 'Save failed. Click to retry.',
                    padding: EdgeInsets.zero,
                    onPressed: () => _saveFeedback(_controller.text.trim()),
                  )
                  : _focusNode.hasFocus &&
                      _controller.text.trim() != _lastSavedText
                  ? IconButton(
                    icon: const Icon(
                      Icons.check,
                      size: 16,
                      color: Color(0xFF6366F1),
                    ),
                    tooltip: 'Save feedback',
                    padding: EdgeInsets.zero,
                    onPressed: () => _saveFeedback(_controller.text.trim()),
                  )
                  : null,
        ),
      ),
    );
  }
}
