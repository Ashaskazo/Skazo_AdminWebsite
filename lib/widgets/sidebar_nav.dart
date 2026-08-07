import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/admin_providers.dart';

class SidebarNav extends ConsumerWidget {
  const SidebarNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
       print("************************************************************************");
                print('Current Admin Profile: ${ref.watch(currentAdminProfileProvider).value}');
print('Is Super Admin: ${ref.watch(isSuperAdminProvider)}');
    final currentView = ref.watch(currentDashboardViewProvider);
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: isCollapsed ? 80 : 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo/Header Area
          Container(
            padding: EdgeInsets.symmetric(
              vertical: 24,
              horizontal: isCollapsed ? 12 : 24,
            ),
            child:
                isCollapsed
                    ? Column(
                      children: [
                        IconButton(
                          onPressed:
                              () =>
                                  ref
                                      .read(sidebarCollapsedProvider.notifier)
                                      .state = false,
                          icon: const Icon(
                            Icons.menu,
                            color: Color(0xFF2563EB),
                            size: 26,
                          ),
                          tooltip: 'Expand Sidebar',
                        ),
                      ],
                    )
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: 232,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Skazo Admin',
                                maxLines: 1,
                                overflow: TextOverflow.clip,
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  () =>
                                      ref
                                          .read(
                                            sidebarCollapsedProvider.notifier,
                                          )
                                          .state = true,
                              icon: const Icon(
                                Icons.menu_open,
                                color: Color(0xFF64748B),
                                size: 22,
                              ),
                              tooltip: 'Collapse Sidebar',
                            ),
                          ],
                        ),
                      ),
                    ),
          ),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 8 : 16),
              children: [
                _buildSectionHeader('MAIN', isCollapsed),
                _buildNavItem(
                  ref,
                  'Dashboard',
                  Icons.dashboard_outlined,
                  DashboardView.summary,
                  currentView,
                  isCollapsed,
                ),

                const SizedBox(height: 16),
                _buildSectionHeader('ENTITIES', isCollapsed),
                _buildNavItem(
                  ref,
                  'Users',
                  Icons.people_outline,
                  DashboardView.users,
                  currentView,
                  isCollapsed,
                ),
                _buildNavItem(
                  ref,
                  'Logs',
                  Icons.history_outlined,
                  DashboardView.logs,
                  currentView,
                  isCollapsed,
                ),
                _buildNavItem(
                  ref,
                  'Service Posts',
                  Icons.post_add_outlined,
                  DashboardView.servicePosts,
                  currentView,
                  isCollapsed,
                ),
                _buildNavItem(
                  ref,
                  'Rental Properties',
                  Icons.home_work_outlined,
                  DashboardView.rentalProperties,
                  currentView,
                  isCollapsed,
                ),
                _buildNavItem(
                  ref,
                  'Local Promotions',
                  Icons.campaign_outlined,
                  DashboardView.localPromotions,
                  currentView,
                  isCollapsed,
                ),
                // _buildNavItem(
                //   ref,
                //   'Orders',
                //   Icons.shopping_cart_outlined,
                //   DashboardView.orders,
                //   currentView,
                //   isCollapsed,
                // ),
                _buildNavItem(
                  ref,
                  'Payments',
                  Icons.payments_outlined,
                  DashboardView.payments,
                  currentView,
                  isCollapsed,
                ),

                const SizedBox(height: 16),
                _buildSectionHeader('OPERATIONS', isCollapsed),
                _buildNavItem(
                  ref,
                  'Tickets',
                  Icons.confirmation_number_outlined,
                  DashboardView.tickets,
                  currentView,
                  isCollapsed,
                ),
                _buildNavItem(
                  ref,
                  'Verification',
                  Icons.verified_user_outlined,
                  DashboardView.verification,
                  currentView,
                  isCollapsed,
                ),
                _buildNavItem(
                  ref,
                  'WhatsApp Messages',
                  Icons.message_outlined,
                  DashboardView.whatsappMessages,
                  currentView,
                  isCollapsed,
                ),
             

                if (ref.watch(isSuperAdminProvider)) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('SYSTEM', isCollapsed),
                  _buildNavItem(
                    ref,
                    'Admin Management',
                    Icons.admin_panel_settings_outlined,
                    DashboardView.admin,
                    currentView,
                    isCollapsed,
                  ),
                  _buildNavItem(
                    ref,
                    'App Config',
                    Icons.settings_outlined,
                    DashboardView.appConfig,
                    currentView,
                    isCollapsed,
                  ),
                ],
              ],
            ),
          ),

          // User Profile Info at Bottom
          const Divider(height: 1),
          ref
              .watch(currentAdminProfileProvider)
              .when(
                data: (profile) {
                  if (isCollapsed) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          Tooltip(
                            message:
                                '${profile?['name'] ?? 'Admin User'} (${(profile?['role'] ?? profile?['level'] ?? 'admin').toString().toUpperCase()})',
                            child: CircleAvatar(
                              backgroundColor: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.1),
                              child: Text(
                                (profile?['name'] ?? 'A')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            onPressed:
                                () =>
                                    ref
                                        .read(adminAuthProvider.notifier)
                                        .signOut(),
                            icon: const Icon(
                              Icons.logout,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: 232,
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: const Color(
                                0xFF2563EB,
                              ).withValues(alpha: 0.1),
                              child: Text(
                                (profile?['name'] ?? 'A')
                                    .toString()
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    profile?['name'] ?? 'Admin User',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    (profile?['role'] ??
                                            profile?['level'] ??
                                            'admin')
                                        .toString()
                                        .replaceAll('_', ' ')
                                        .toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed:
                                  () =>
                                      ref
                                          .read(adminAuthProvider.notifier)
                                          .signOut(),
                              icon: const Icon(
                                Icons.logout,
                                size: 20,
                                color: Color(0xFFEF4444),
                              ),
                              tooltip: 'Logout',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                loading:
                    () => const SizedBox(
                      height: 80,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                error: (_, __) => const SizedBox.shrink(),
              ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isCollapsed) {
    if (isCollapsed) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Divider(height: 1, thickness: 1),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey[400],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    WidgetRef ref,
    String title,
    IconData icon,
    DashboardView view,
    DashboardView currentView,
    bool isCollapsed,
  ) {
    final isSelected = view == currentView;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Tooltip(
          message: title,
          child: InkWell(
            onTap:
                () =>
                    ref.read(currentDashboardViewProvider.notifier).state =
                        view,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color:
                    isSelected
                        ? const Color(0xFF2563EB)
                        : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap:
            () => ref.read(currentDashboardViewProvider.notifier).state = view,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: 224,
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color:
                        isSelected
                            ? const Color(0xFF2563EB)
                            : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSelected
                                ? const Color(0xFF2563EB)
                                : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
