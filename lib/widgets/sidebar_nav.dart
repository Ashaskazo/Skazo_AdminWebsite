import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/admin_providers.dart';

class SidebarNav extends ConsumerWidget {
  const SidebarNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentView = ref.watch(currentDashboardViewProvider);

    return Container(
      width: 280,
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
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
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
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Skazo Admin',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildSectionHeader('MAIN'),
                _buildNavItem(
                  ref,
                  'Dashboard',
                  Icons.dashboard_outlined,
                  DashboardView.summary,
                  currentView,
                ),
                
                const SizedBox(height: 16),
                _buildSectionHeader('ENTITIES'),
                _buildNavItem(
                  ref,
                  'Users',
                  Icons.people_outline,
                  DashboardView.users,
                  currentView,
                ),
                _buildNavItem(
                  ref,
                  'Service Posts',
                  Icons.post_add_outlined,
                  DashboardView.servicePosts,
                  currentView,
                ),
                _buildNavItem(
                  ref,
                  'Rental Properties',
                  Icons.home_work_outlined,
                  DashboardView.rentalProperties,
                  currentView,
                ),
                _buildNavItem(
                  ref,
                  'Orders',
                  Icons.shopping_cart_outlined,
                  DashboardView.orders,
                  currentView,
                ),
                _buildNavItem(
                  ref,
                  'Payments',
                  Icons.payments_outlined,
                  DashboardView.payments,
                  currentView,
                ),

                const SizedBox(height: 16),
                _buildSectionHeader('OPERATIONS'),
                _buildNavItem(
                  ref,
                  'Tickets',
                  Icons.confirmation_number_outlined,
                  DashboardView.tickets,
                  currentView,
                ),
                _buildNavItem(
                  ref,
                  'Verification',
                  Icons.verified_user_outlined,
                  DashboardView.verification,
                  currentView,
                ),
                _buildNavItem(
                  ref,
                  'WhatsApp Messages',
                  Icons.message_outlined,
                  DashboardView.whatsappMessages,
                  currentView,
                ),

                const SizedBox(height: 16),
                _buildSectionHeader('SYSTEM'),
                if (ref.watch(isSuperAdminProvider)) ...[
                  _buildNavItem(
                    ref,
                    'Admin Management',
                    Icons.admin_panel_settings_outlined,
                    DashboardView.admin,
                    currentView,
                  ),
                  _buildNavItem(
                    ref,
                    'App Config',
                    Icons.settings_outlined,
                    DashboardView.appConfig,
                    currentView,
                  ),
                ],
                _buildNavItem(
                  ref,
                  'Logs',
                  Icons.history_outlined,
                  DashboardView.logs,
                  currentView,
                ),
              ],
            ),
          ),

          // User Profile Info at Bottom
          const Divider(height: 1),
          ref.watch(currentAdminProfileProvider).when(
            data: (profile) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                    child: Text(
                      (profile?['name'] ?? 'A').toString().substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          (profile?['role'] ?? profile?['level'] ?? 'admin').toString().replaceAll('_', ' ').toUpperCase(),
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
                    onPressed: () => ref.read(adminAuthProvider.notifier).signOut(),
                    icon: const Icon(Icons.logout, size: 20, color: Color(0xFFEF4444)),
                    tooltip: 'Logout',
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
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
  ) {
    final isSelected = view == currentView;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => ref.read(currentDashboardViewProvider.notifier).state = view,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                ),
              ),
              if (isSelected) ...[
                const Spacer(),
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
    );
  }
}
