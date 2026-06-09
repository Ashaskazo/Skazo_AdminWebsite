import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';

class PaymentsDataView extends ConsumerStatefulWidget {
  const PaymentsDataView({super.key});

  @override
  ConsumerState<PaymentsDataView> createState() => _PaymentsDataViewState();
}

class _PaymentsDataViewState extends ConsumerState<PaymentsDataView> {
  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(paginatedPaymentProvider);
    final notifier = ref.watch(paginatedPaymentProvider.notifier);

    // Watch admin related providers
    final isSuper = ref.watch(isSuperAdminProvider);
    final adminProfile = ref.watch(currentAdminProfileProvider).value;
    final currentAdminId = adminProfile?['admin_id'] ?? adminProfile?['id'];

    // Listen for filter changes to refresh list
    ref.listen(
      paymentSearchQueryProvider,
      (_, __) => ref.read(paginatedPaymentProvider.notifier).fetchInitial(),
    );

    ref.listen(
      selectedPaymentAdminFilterProvider,
      (_, __) => ref.read(paginatedPaymentProvider.notifier).fetchInitial(),
    );

    ref.listen<AsyncValue<Map<String, dynamic>?>>(currentAdminProfileProvider, (
      previous,
      next,
    ) {
      if (next.hasValue && next.value != null) {
        ref.read(paginatedPaymentProvider.notifier).fetchInitial();
      }
    });

    // Calculate stats filter ID
    final String? statsFilterAdminId =
        isSuper
            ? ref.watch(selectedPaymentAdminFilterProvider)
            : currentAdminId;

    final statsAsync = ref.watch(paymentSalesStatsProvider(statsFilterAdminId));
    final adminsAsync = ref.watch(adminsListProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payments',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage verification charges and payment links',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  // Dropdown for Super Admin
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
                                    .read(
                                      selectedPaymentAdminFilterProvider
                                          .notifier,
                                    )
                                    .state = val;
                              },
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    'All Admins',
                                    style: GoogleFonts.poppins(fontSize: 13),
                                  ),
                                ),
                                ...adminsList.map((admin) {
                                  final adminId =
                                      admin['admin_id'] ?? admin['id'];
                                  return DropdownMenuItem<String?>(
                                    value: adminId,
                                    child: Text(
                                      admin['name'] ??
                                          admin['email'] ??
                                          'Unknown',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                      loading:
                          () => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 16),
                  ],
                  // Refresh button
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        ref.read(paymentSearchQueryProvider.notifier).state =
                            '';
                        if (isSuper) {
                          ref
                              .read(selectedPaymentAdminFilterProvider.notifier)
                              .state = null;
                        }
                        ref.invalidate(paymentSalesStatsProvider);
                        ref
                            .read(paginatedPaymentProvider.notifier)
                            .fetchInitial();
                      },
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                      tooltip: 'Reset & Refresh',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Sales Stats Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: statsAsync.when(
            data: (stats) => _buildStatsGrid(stats),
            loading:
                () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                ),
            error:
                (e, _) => Center(
                  child: Text(
                    'Failed to load sales stats: $e',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
          ),
        ),
        const SizedBox(height: 24),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 54,
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
            child: TextField(
              onChanged:
                  (value) =>
                      ref.read(paymentSearchQueryProvider.notifier).state =
                          value,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search provider by name or phone...',
                hintStyle: GoogleFonts.poppins(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF94A3B8),
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Data List
        Expanded(
          child: dataAsync.when(
            data: (users) {
              if (users.isEmpty) return _buildEmptyState();
              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildPaymentCard(context, user, ref);
                      },
                    ),
                  ),
                  _buildPaginationFooter(notifier),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(PaymentSalesStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 2.2,
      children: [
        _buildStatCard(
          title: 'Total Sales',
          value: stats.totalSale,
          color: const Color(0xFF2563EB),
          icon: Icons.payments_rounded,
        ),
        _buildStatCard(
          title: 'This Month (30d)',
          value: stats.thisMonthSale,
          color: const Color(0xFF16A34A),
          icon: Icons.calendar_today_rounded,
        ),
        _buildStatCard(
          title: 'Today\'s Sales',
          value: stats.todaySale,
          color: const Color(0xFF0D9488),
          icon: Icons.today_rounded,
        ),
        _buildStatCard(
          title: 'Yesterday\'s Sales',
          value: stats.yesterdaySale,
          color: const Color(0xFFEA580C),
          icon: Icons.history_rounded,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required double value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${value.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
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
            child: Icon(icon, color: color, size: 22),
          ),
        ],
      ),
    );
  }

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

    // Check if they have an active plan or any payment
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
            // User Info
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.category,
                        size: 14,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _formatCategories(user['category']),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (user['paymentLinkSenderName'] != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Sender: ${user['paymentLinkSenderName']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF2563EB),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Payment Details
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
                    const SizedBox(height: 2),
                    Text(
                      'TXN: $transactionId',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Paid At: ${_formatDate(user['paymentDate'] ?? user['paymentPaidAt'] ?? user['lastPaymentAt'])}',
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
                    if (paymentLinkSend &&
                        (user['paymentInitiatedAt'] != null ||
                            user['paymentLinkSentAt'] != null)) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Sent: ${_formatDate(user['paymentInitiatedAt'] ?? user['paymentLinkSentAt'])}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            // Actions
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle,
                            size: 14,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Paid',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF16A34A),
                            ),
                          ),
                        ],
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
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
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
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.payments_outlined,
            size: 48,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 16),
          Text(
            'No payment records found',
            style: GoogleFonts.poppins(color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  String _formatCategories(dynamic categoryData) {
    if (categoryData == null) return 'No Category';
    if (categoryData is String) return categoryData;
    if (categoryData is List) return categoryData.join(', ');
    return 'Unknown';
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    DateTime? dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is String) {
      dateTime = DateTime.tryParse(timestamp);
    } else if (timestamp is int) {
      dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    }

    if (dateTime == null) return 'N/A';

    final day = dateTime.day.toString().padLeft(2, '0');
    final monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[dateTime.month - 1];
    final year = dateTime.year;

    return '$day $month $year';
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
                        value: selectedDuration,
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
                                if (amountStr.isEmpty || txnId.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Please fill all fields'),
                                    ),
                                  );
                                  return;
                                }

                                final amount = double.tryParse(amountStr);
                                if (amount == null || amount <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a valid amount',
                                      ),
                                    ),
                                  );
                                  return;
                                }

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
                                        'paymentPlanDuration': selectedDuration,
                                        'transactionId': txnId,
                                        'lastPaymentAt':
                                            FieldValue.serverTimestamp(),
                                        'paymentPaidAt':
                                            FieldValue.serverTimestamp(),
                                        'paymentLinkSenderId': senderId,
                                        'paymentLinkSenderName': senderName,
                                      });

                                  // Invalidate stats and refresh list
                                  ref.invalidate(paymentSalesStatsProvider);
                                  ref
                                      .read(paginatedPaymentProvider.notifier)
                                      .fetchInitial();

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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(isSaving ? 'Saving...' : 'Confirm Paid'),
                    ),
                  ],
                ),
          ),
    );
  }
}
