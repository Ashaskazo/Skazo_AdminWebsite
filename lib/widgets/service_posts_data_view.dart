import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/pages/service_post_details_page.dart';

class ServicePostsDataView extends ConsumerWidget {
  const ServicePostsDataView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(paginatedServicePostProvider);
    final searchQuery = ref.watch(serviceSearchQueryProvider);
    final selectedCategory = ref.watch(serviceSelectedCategoryProvider);
    final selectedStatus = ref.watch(serviceStatusFilterProvider);
    final todayOnly = ref.watch(serviceTodayOnlyProvider);
    final notifier = ref.watch(paginatedServicePostProvider.notifier);

    // Listen for filter changes
    ref.listen(serviceSearchQueryProvider, (_, __) => notifier.fetchInitial());
    ref.listen(serviceSelectedCategoryProvider, (_, __) => notifier.fetchInitial());
    ref.listen(serviceStatusFilterProvider, (_, __) => notifier.fetchInitial());
    ref.listen(serviceTodayOnlyProvider, (_, __) => notifier.fetchInitial());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Posts',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Monitor services posted by providers.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    ref.read(serviceSearchQueryProvider.notifier).state = '';
                    ref.read(serviceSelectedCategoryProvider.notifier).state = null;
                    ref.read(serviceStatusFilterProvider.notifier).state = null;
                    ref.read(serviceTodayOnlyProvider.notifier).state = false;
                    notifier.fetchInitial();
                  },
                  icon: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
        ),

        // Count Summary
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              _buildCountCard('Total Posts', notifier.totalCount, const Color(0xFF2563EB)),
              const SizedBox(width: 16),
              _buildCountCard('Today\'s Posts', notifier.todayCount, const Color(0xFF10B981)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Row(
                children: [
                  // Search
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        onChanged: (v) => ref.read(serviceSearchQueryProvider.notifier).state = v,
                        decoration: const InputDecoration(
                          hintText: 'Search by user name...',
                          prefixIcon: Icon(Icons.search, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Category Filter
                  ref.watch(serviceCategoriesProvider).when(
                    data: (categories) => Container(
                      height: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: selectedCategory,
                          hint: const Text('All Categories'),
                          onChanged: (v) => ref.read(serviceSelectedCategoryProvider.notifier).state = v,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Categories')),
                            ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          ],
                        ),
                      ),
                    ),
                    loading: () => const SizedBox(width: 50, child: LinearProgressIndicator()),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAllChip(ref, selectedStatus == null && !todayOnly),
                  const SizedBox(width: 12),
                  _buildStatusChip(ref, 'Pending', 'pending', selectedStatus),
                  const SizedBox(width: 12),
                  _buildTodayChip(ref, todayOnly),
                  const Spacer(),
                  Text(
                    'Showing ${notifier.filteredCount} posts',
                    style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // List View
        Expanded(
          child: dataAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.post_add_rounded, size: 48, color: Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      Text('No service posts found', style: GoogleFonts.poppins(color: const Color(0xFF64748B))),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        return _buildServiceCard(context, post);
                      },
                    ),
                  ),
                  _buildPaginationFooter(notifier),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildAllChip(WidgetRef ref, bool isActive) {
    return FilterChip(
      label: const Text('All'),
      selected: isActive,
      onSelected: (v) {
        if (v) {
          ref.read(serviceStatusFilterProvider.notifier).state = null;
          ref.read(serviceTodayOnlyProvider.notifier).state = false;
        }
      },
      selectedColor: const Color(0xFF64748B).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFF64748B),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildStatusChip(WidgetRef ref, String label, String status, String? currentStatus) {
    final isActive = currentStatus == status;
    return FilterChip(
      label: Text(label),
      selected: isActive,
      onSelected: (v) => ref.read(serviceStatusFilterProvider.notifier).state = v ? status : null,
      selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFF2563EB),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: isActive ? const Color(0xFF2563EB) : const Color(0xFF64748B),
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildTodayChip(WidgetRef ref, bool isActive) {
    return FilterChip(
      label: const Text('Today'),
      selected: isActive,
      onSelected: (v) => ref.read(serviceTodayOnlyProvider.notifier).state = v,
      selectedColor: const Color(0xFF10B981).withValues(alpha: 0.1),
      checkmarkColor: const Color(0xFF10B981),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: isActive ? const Color(0xFF10B981) : const Color(0xFF64748B),
        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isActive ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
      ),
    );
  }

  Widget _buildCountCard(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(BuildContext context, Map<String, dynamic> post) {
    final category = post['category']?.toString() ?? 'General';
    final userName = post['userName']?.toString() ?? 'Anonymous';
    final budget = post['budget']?.toString() ?? 'N/A';
    final contactedCount = (post['contactedBy'] as List?)?.length ?? 0;
    final status = post['status']?.toString() ?? 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ServicePostDetailsPage(postData: post),
            ),
          );
        },
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Icon(
              _getCategoryIcon(category),
              color: const Color(0xFF2563EB),
              size: 24,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                userName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            _buildStatusBadge(status),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.category_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(category, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('$contactedCount contacted', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Budget: $budget',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
                fontSize: 14,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'live':
        color = Colors.green;
        break;
      case 'completed':
        color = Colors.blue;
        break;
      default:
        color = Colors.orange;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    category = category.toLowerCase();
    if (category.contains('car')) return Icons.directions_car_outlined;
    if (category.contains('clean')) return Icons.cleaning_services_outlined;
    if (category.contains('repair')) return Icons.build_outlined;
    if (category.contains('electric')) return Icons.electrical_services_outlined;
    if (category.contains('plumb')) return Icons.plumbing_outlined;
    return Icons.miscellaneous_services_outlined;
  }

  Widget _buildPaginationFooter(PaginatedServicePostNotifier notifier) {
    final int start = (notifier.currentPage * notifier.pageSize) + 1;
    final int end = (notifier.currentPage + 1) * notifier.pageSize > notifier.filteredCount
        ? notifier.filteredCount
        : (notifier.currentPage + 1) * notifier.pageSize;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$start–$end of ${notifier.filteredCount}',
            style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: notifier.currentPage > 0 ? () => notifier.prevPage() : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: end < notifier.filteredCount ? () => notifier.nextPage() : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
