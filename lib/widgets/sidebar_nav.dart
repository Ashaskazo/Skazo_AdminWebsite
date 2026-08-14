import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/admin_providers.dart';

class SidebarNav extends ConsumerWidget {
  const SidebarNav({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    print(
      "************************************************************************",
    );
    print(
      'Current Admin Profile: ${ref.watch(currentAdminProfileProvider).value}',
    );
    print('Is Super Admin: ${ref.watch(isSuperAdminProvider)}');
    final currentView = ref.watch(currentDashboardViewProvider);
    final isCollapsed = ref.watch(sidebarCollapsedProvider);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: isCollapsed ? 84 : 290,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          // Logo / Header Area
          Container(
            padding: EdgeInsets.symmetric(
              vertical: 20,
              horizontal: isCollapsed ? 12 : 20,
            ),
            child:
                isCollapsed
                    ? Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed:
                                () =>
                                    ref
                                        .read(sidebarCollapsedProvider.notifier)
                                        .state = false,
                            icon: const Icon(
                              Icons.bolt_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            tooltip: 'Expand Command Center 🚀',
                          ),
                        ),
                      ],
                    )
                    : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: 250,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF312E81),
                                    Color(0xFF4F46E5),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF4F46E5,
                                    ).withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SKAZO ',
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                    style: GoogleFonts.poppins(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0F172A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    'Admin Command Suite 🚀',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
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
                                Icons.menu_open_rounded,
                                color: Color(0xFF94A3B8),
                                size: 22,
                              ),
                              tooltip: 'Collapse Sidebar',
                            ),
                          ],
                        ),
                      ),
                    ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 10 : 16),
              children: [
                _buildSectionHeader('MAIN CONTROL 🎛️', isCollapsed),
                _buildNavItem(
                  ref,
                  'Dashboard Overview',
                  Icons.grid_view_rounded,
                  DashboardView.summary,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFF6366F1), Color(0xFF4F46E5)],
                ),

                const SizedBox(height: 16),
                _buildSectionHeader('CORE ENTITIES 👑', isCollapsed),
                _buildNavItem(
                  ref,
                  'Users & Providers',
                  Icons.people_alt_rounded,
                  DashboardView.users,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  badge: 'VIP',
                ),
                _buildNavItem(
                  ref,
                  'Call & Action Logs',
                  Icons.phone_in_talk_rounded,
                  DashboardView.logs,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                  badge: 'LIVE',
                ),
                _buildNavItem(
                  ref,
                  'Service Posts',
                  Icons.auto_stories_rounded,
                  DashboardView.servicePosts,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFF10B981), Color(0xFF059669)],
                ),
                _buildNavItem(
                  ref,
                  'Rental Properties',
                  Icons.holiday_village_rounded,
                  DashboardView.rentalProperties,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                ),
                _buildNavItem(
                  ref,
                  'Local Promotions',
                  Icons.campaign_rounded,
                  DashboardView.localPromotions,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFFEC4899), Color(0xFFDB2777)],
                ),
                _buildNavItem(
                  ref,
                  'Payments & Revenue',
                  Icons.account_balance_wallet_rounded,
                  DashboardView.payments,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFF06B6D4), Color(0xFF0891B2)],
                  badge: '₹💰',
                ),

                const SizedBox(height: 16),
                _buildSectionHeader('OPERATIONS & HELPDESK 🛠️', isCollapsed),
                _buildNavItem(
                  ref,
                  'Support Tickets',
                  Icons.confirmation_number_rounded,
                  DashboardView.tickets,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFFF97316), Color(0xFFEA580C)],
                ),
                _buildNavItem(
                  ref,
                  'Verification Queue',
                  Icons.verified_user_rounded,
                  DashboardView.verification,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFF14B8A6), Color(0xFF0D9488)],
                ),
                _buildNavItem(
                  ref,
                  'WhatsApp Logs',
                  Icons.chat_bubble_rounded,
                  DashboardView.whatsappMessages,
                  currentView,
                  isCollapsed,
                  activeGradient: const [Color(0xFF22C55E), Color(0xFF16A34A)],
                ),

                if (ref.watch(isSuperAdminProvider)) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader('SYSTEM CONTROL ⚡', isCollapsed),
                  _buildNavItem(
                    ref,
                    'Admin Management',
                    Icons.admin_panel_settings_rounded,
                    DashboardView.admin,
                    currentView,
                    isCollapsed,
                    activeGradient: const [
                      Color(0xFF6366F1),
                      Color(0xFF4338CA),
                    ],
                    badge: 'SUPER',
                  ),
                  _buildNavItem(
                    ref,
                    'App Configurations',
                    Icons.tune_rounded,
                    DashboardView.appConfig,
                    currentView,
                    isCollapsed,
                    activeGradient: const [
                      Color(0xFF64748B),
                      Color(0xFF334155),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),

          // User Profile Info at Bottom
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          ref
              .watch(currentAdminProfileProvider)
              .when(
                data: (profile) {
                  final name = profile?['name'] ?? 'Super Admin';
                  final role =
                      (profile?['role'] ?? profile?['level'] ?? 'Boss')
                          .toString()
                          .replaceAll('_', ' ')
                          .toUpperCase();

                  if (isCollapsed) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Column(
                        children: [
                          Tooltip(
                            message: '$name ($role) - Logged in 😎',
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF6366F1),
                                    Color(0xFFEC4899),
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white,
                                child: Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xFF6366F1),
                                    fontWeight: FontWeight.w800,
                                  ),
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
                              Icons.logout_rounded,
                              size: 20,
                              color: Color(0xFFEF4444),
                            ),
                            tooltip: 'Logout 🚪',
                          ),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF6366F1).withValues(alpha: 0.08),
                            const Color(0xFFA855F7).withValues(alpha: 0.04),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFFEC4899)],
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF6366F1),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      role,
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF6366F1),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
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
                              Icons.logout_rounded,
                              size: 18,
                              color: Color(0xFFEF4444),
                            ),
                            tooltip: 'Logout',
                          ),
                        ],
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
        child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 8, top: 12),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF94A3B8),
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
    bool isCollapsed, {
    required List<Color> activeGradient,
    String? badge,
  }) {
    final isSelected = view == currentView;

    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Tooltip(
          message: title,
          child: InkWell(
            onTap:
                () =>
                    ref.read(currentDashboardViewProvider.notifier).state =
                        view,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient:
                    isSelected ? LinearGradient(colors: activeGradient) : null,
                color: isSelected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: activeGradient.first.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                        : null,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap:
            () => ref.read(currentDashboardViewProvider.notifier).state = view,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
          decoration: BoxDecoration(
            gradient:
                isSelected ? LinearGradient(colors: activeGradient) : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: activeGradient.first.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                    : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : activeGradient.first.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : activeGradient.first,
                    ),
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
