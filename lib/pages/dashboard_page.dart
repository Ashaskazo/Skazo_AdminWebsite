import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/pages/auth_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/widgets/pay_per_lead_data_view.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';
import 'package:skazo_admin/utils/responsive.dart';
import 'package:skazo_admin/utils/time_filter.dart';
import 'package:skazo_admin/widgets/sidebar_nav.dart';
import 'package:skazo_admin/widgets/collection_data_view.dart';
import 'package:skazo_admin/widgets/users_data_view.dart';
import 'package:skazo_admin/widgets/deactivated_list_data_view.dart';
import 'package:skazo_admin/widgets/service_posts_data_view.dart';
import 'package:skazo_admin/widgets/rental_properties_data_view.dart';
import 'package:skazo_admin/widgets/local_promotions_data_view.dart';
import 'package:skazo_admin/widgets/admins_data_view.dart';
import 'package:skazo_admin/widgets/unverified_businesses_grid.dart';
import 'package:skazo_admin/widgets/payments_data_view.dart';
import 'package:skazo_admin/widgets/service_providers_data_view.dart';
import '../widgets/call_logs_data_view.dart';
import 'package:skazo_admin/widgets/call_log_sheet_view.dart';
import 'package:skazo_admin/widgets/call_logs_detail_data_view.dart';
import 'package:skazo_admin/widgets/pending_provider_feedback_data_view.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentView = ref.watch(currentDashboardViewProvider);
    final accessScope = ref.watch(cityAccessScopeProvider);

    // Clear stale tenant caches if the authenticated user changes across logins.
    ref.listen<String?>(
      authStateProvider.select((a) => a.value?.email?.toLowerCase().trim()),
      (prevEmail, nextEmail) {
        if (prevEmail != null && nextEmail != null && prevEmail != nextEmail) {
          ref
              .read(sessionCacheCoordinatorProvider)
              .resetAll(includeAuthProfile: false);
        }
      },
    );

    return authState.when(
      data: (user) {
        if (user == null) {
          return const AuthPage();
        }

        // Strict fail-closed access gate before exposing any dashboard UI or data.
        switch (accessScope.status) {
          case AdminAccessStatus.loading:
          case AdminAccessStatus.unauthenticated:
            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Verifying workspace & city permissions...',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            );
          case AdminAccessStatus.deniedInactive:
            return _AccessBlockedScreen(
              icon: Icons.block_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Account Deactivated',
              message:
                  'Your employee access has been deactivated. Please contact your administrator.',
              email: accessScope.email,
              onSignOut: () => ref.read(adminAuthProvider.notifier).signOut(),
            );
          case AdminAccessStatus.deniedUnauthorized:
            return _AccessBlockedScreen(
              icon: Icons.gpp_bad_rounded,
              iconColor: const Color(0xFFEF4444),
              title: 'Access Denied',
              message:
                  accessScope.errorMessage != null
                      ? 'Unable to verify permissions. Access is denied by default.'
                      : 'Your account is not authorized to access this admin portal.',
              email: accessScope.email,
              onSignOut: () => ref.read(adminAuthProvider.notifier).signOut(),
            );
          case AdminAccessStatus.noCitiesAssigned:
            return _AccessBlockedScreen(
              icon: Icons.location_off_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: 'No Cities Assigned',
              message:
                  'No cities have been assigned to your account. Please contact your administrator.',
              email: accessScope.email,
              onSignOut: () => ref.read(adminAuthProvider.notifier).signOut(),
            );
          case AdminAccessStatus.authorized:
            break;
        }

        final isMobile = ResponsiveBreakpoints.isMobile(context);

        final mainContent = Container(
          color: const Color(0xFFF8FAFC),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            child: _buildMainContent(currentView, ref),
          ),
        );

        return Scaffold(
          appBar:
              isMobile
                  ? AppBar(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    scrolledUnderElevation: 1,
                    surfaceTintColor: Colors.white,
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(
                        height: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    title: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF312E81), Color(0xFF4F46E5)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _getViewTitle(currentView),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                  : null,
          drawer:
              isMobile
                  ? const Drawer(
                    width: 285,
                    backgroundColor: Colors.white,
                    child: SafeArea(child: SidebarNav(isDrawer: true)),
                  )
                  : null,
          body:
              isMobile
                  ? SafeArea(top: false, child: mainContent)
                  : Row(
                    children: [
                      const SidebarNav(),
                      Expanded(child: mainContent),
                    ],
                  ),
        );
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth Error: $e'))),
    );
  }

  String _getViewTitle(DashboardView view) {
    switch (view) {
      case DashboardView.summary:
        return 'Dashboard Overview';
      case DashboardView.serviceProviders:
        return 'Service Providers';
      case DashboardView.users:
        return 'Users & Providers';
      case DashboardView.payPerLead:
        return 'Pay Per Lead';
      case DashboardView.deactivatedList:
        return 'Deactivated Providers';
      case DashboardView.callLogSheet:
        return 'Call Log Sheet';
      case DashboardView.callLogsDetails:
        return 'Call Logs Details';
      case DashboardView.servicePosts:
        return 'Service Posts';
      case DashboardView.rentalProperties:
        return 'Rental Properties';
      case DashboardView.localPromotions:
        return 'Local Promotions';
      case DashboardView.tickets:
        return 'Helpdesk Tickets';
      case DashboardView.verification:
        return 'Verification Queue';
      case DashboardView.whatsappMessages:
        return 'WhatsApp Messages';
      case DashboardView.admin:
        return 'Admin Management';
      case DashboardView.appConfig:
        return 'App Configuration';
      case DashboardView.logs:
        return 'Call Logs & Feedback';
      case DashboardView.pendingProviderFeedback:
        return 'Pending Provider Feedback';
      case DashboardView.payments:
        return 'Payments';
    }
  }

  Widget _buildMainContent(DashboardView view, WidgetRef ref) {
    switch (view) {
      case DashboardView.summary:
        return const _SummaryDashboard();
      case DashboardView.users:
        return const UsersDataView();
      case DashboardView.serviceProviders:
        return const ServiceProvidersDataView();
      case DashboardView.deactivatedList:
        return const DeactivatedListDataView();
      case DashboardView.servicePosts:
        return const ServicePostsDataView();
      case DashboardView.rentalProperties:
        return const RentalPropertiesDataView();
      case DashboardView.localPromotions:
        return const LocalPromotionsDataView();
      case DashboardView.tickets:
        return const CollectionDataView(
          collectionName: 'tickets',
          title: 'Support Tickets 🎟️',
        );
      case DashboardView.verification:
        return const CollectionDataView(
          collectionName: 'verification',
          title: 'Verification Requests 🛡️',
        );
      case DashboardView.whatsappMessages:
        return const CollectionDataView(
          collectionName: 'whatsappMessages',
          title: 'WhatsApp Logs 💬',
        );
      case DashboardView.admin:
        final isSuperAdmin = ref.watch(isSuperAdminProvider);
        if (!isSuperAdmin) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Access Denied: Super Admin Only 🛑',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          );
        }
        return const AdminsDataView();
      case DashboardView.appConfig:
        final isSuperAdmin = ref.watch(isSuperAdminProvider);
        if (!isSuperAdmin) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Access Denied: Super Admin Only 🛑',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
          );
        }
        return const CollectionDataView(
          collectionName: 'app_config',
          title: 'Application Configurations ⚙️',
        );
      case DashboardView.callLogSheet:
        return const CallLogSheetView();
      case DashboardView.callLogsDetails:
        return const CallLogsDetailDataView();
      case DashboardView.logs:
        return const CallLogsDataView();
      case DashboardView.pendingProviderFeedback:
        return const PendingProviderFeedbackDataView();
      case DashboardView.payments:
        return const PaymentsDataView();
        case DashboardView.payPerLead:
        return const PayPerLeadDataView();
    }
  }
}

class _SummaryDashboard extends ConsumerWidget {
  const _SummaryDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminProfile = ref.watch(currentAdminProfileProvider).value;
    final adminName = adminProfile?['name'] ?? 'Super Boss';
    final isMobile = ResponsiveBreakpoints.isMobile(context);
    final isTablet = ResponsiveBreakpoints.isTablet(context);

    return SingleChildScrollView(
      padding:
          isMobile
              ? const EdgeInsets.fromLTRB(16, 16, 16, 32)
              : isTablet
              ? const EdgeInsets.fromLTRB(24, 24, 24, 40)
              : const EdgeInsets.fromLTRB(32, 28, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Welcome Header - Serene Midnight Sapphire Theme
          Container(
            padding: EdgeInsets.all(isMobile ? 18 : 28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                  Color(0xFF4338CA),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(isMobile ? 18 : 24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF312E81).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back, $adminName! 👑',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 20 : 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Close the Deal, Own the Win.✨',
                        style: GoogleFonts.poppins(
                          fontSize: isMobile ? 12.5 : 13.5,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Builder(
                        builder: (context) {
                          final scope = ref.watch(cityAccessScopeProvider);
                          final label =
                              scope.isSuperAdmin
                                  ? 'Scope: All Cities (Super Admin)'
                                  : 'Assigned Cities: ${scope.assignedCities.join(', ')}';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  scope.isSuperAdmin
                                      ? Icons.public_rounded
                                      : Icons.location_on_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: IconButton(
                    onPressed: () {
                      final selectedCategory = ref.read(
                        dashboardSelectedCategoryProvider,
                      );
                      ref.invalidate(
                        unverifiedPaginationProvider(selectedCategory),
                      );
                      ref.invalidate(unverifiedPendingCountProvider);
                      ref.invalidate(categoryCountsProvider);
                      ref.invalidate(userStatsProvider);
                      clearPropertyPincodesCache();
                      ref.invalidate(propertyPincodesProvider);
                      ref.invalidate(collectionCountProvider);
                      ref.invalidate(collectionTodayCountProvider);
                      ref.invalidate(collectionPeriodStatsProvider);
                      ref.invalidate(collectionDateFieldInfoProvider);
                    },
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'Sync & Refresh Dashboard Stats ⚡',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Overall Summary Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF4F46E5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Overall Platform Summary ✨',
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Overall Stats Grid
          ResponsiveWrapGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            mobileBreakpoint: 520,
            desktopBreakpoint: 960,
            spacing: isMobile ? 12 : 20,
            runSpacing: isMobile ? 12 : 20,
            children: [
              _buildStatCard(
                ref,
                'Total Users',
                'users',
                Icons.people_alt_rounded,
                const [Color(0xFF3B82F6), Color(0xFF1E40AF)],
                badgeLabel: '👑 VIP USERS',
              ),
              _buildStatCard(
                ref,
                'Call Logs',
                'callLogs',
                Icons.phone_in_talk_rounded,
                const [Color(0xFFF59E0B), Color(0xFFB45309)],
                badgeLabel: '🔥 HOTLINE',
              ),
              _buildStatCard(
                ref,
                'Local Promotions',
                'local_promotions',
                Icons.campaign_rounded,
                const [Color(0xFFEC4899), Color(0xFFBE185D)],
                badgeLabel: '📣 PROMOTIONS',
              ),
              _buildStatCard(
                ref,
                'Rental Properties',
                'rental_properties',
                Icons.holiday_village_rounded,
                const [Color(0xFF8B5CF6), Color(0xFF5B21B6)],
                badgeLabel: '🏡 ESTATES',
              ),
            ],
          ),

          SizedBox(height: isMobile ? 28 : 36),

          // Today Summary Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Today's Live Action Highlights 🚀",
                  style: GoogleFonts.poppins(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Today Stats Grid
          ResponsiveWrapGrid(
            mobileColumns: 1,
            tabletColumns: 2,
            desktopColumns: 4,
            mobileBreakpoint: 520,
            desktopBreakpoint: 960,
            spacing: isMobile ? 12 : 20,
            runSpacing: isMobile ? 12 : 20,
            children: [
              _buildStatCard(
                ref,
                'Users Registered',
                'users',
                Icons.person_add_rounded,
                const [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                isToday: true,
                badgeLabel: 'NEW TODAY ⚡',
              ),
              _buildStatCard(
                ref,
                'Calls Made Today',
                'callLogs',
                Icons.phone_callback_rounded,
                const [Color(0xFFF59E0B), Color(0xFFB45309)],
                isToday: true,
                badgeLabel: 'TALK TIME 📞',
              ),
              _buildStatCard(
                ref,
                'Promotions Added',
                'local_promotions',
                Icons.campaign_rounded,
                const [Color(0xFFEC4899), Color(0xFF9D174D)],
                isToday: true,
                badgeLabel: 'NEW OFFERS ⚡',
              ),
              _buildStatCard(
                ref,
                'Properties Listed',
                'rental_properties',
                Icons.add_location_alt_rounded,
                const [Color(0xFFA855F7), Color(0xFF7E22CE)],
                isToday: true,
                badgeLabel: 'NEW HOMES 🔑',
              ),
            ],
          ),

          SizedBox(height: isMobile ? 28 : 40),
          LayoutBuilder(
            builder: (context, constraints) {
              final stackFilters = constraints.maxWidth < 720;
              final titleRow = Row(
                mainAxisSize: stackFilters ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_user_rounded,
                      color: Color(0xFFF59E0B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      'Unverified Businesses Queue 🛡️',
                      style: GoogleFonts.poppins(
                        fontSize: isMobile ? 16 : 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              );

              final filters = Wrap(
                spacing: 12,
                runSpacing: 10,
                children: const [
                  _DashboardCityFilterDropdown(),
                  _DashboardDateFilterDropdown(),
                ],
              );

              if (stackFilters) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleRow, const SizedBox(height: 12), filters],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [Expanded(child: titleRow), const SizedBox(width: 12), filters],
              );
            },
          ),
          const SizedBox(height: 18),
          _buildPendingVerifications(context, ref),
        ],
      ),
    );
  }

  Widget _buildPendingVerifications(BuildContext context, WidgetRef ref) {
    return const UnverifiedBusinessesGrid();
  }

  Widget _buildStatCard(
    WidgetRef ref,
    String title,
    String collection,
    IconData icon,
    List<Color> gradientColors, {
    bool isToday = false,
    String? badgeLabel,
  }) {
    final countAsync =
        isToday
            ? ref.watch(collectionTodayCountProvider(collection))
            : ref.watch(collectionCountProvider(collection));

    final statsAsync =
        isToday ? null : ref.watch(collectionPeriodStatsProvider(collection));

    Widget buildDotDivider() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '•',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.withValues(alpha: 0.4),
          ),
        ),
      );
    }

    final isClickableUserStat = collection == 'users';

    Widget buildPeriodStat(String label, int value) {
      return InkWell(
        onTap:
            isClickableUserStat
                ? () {
                  if (label == 'Today') {
                    ref.read(userDateFilterProvider.notifier).state =
                        timeFilterToLegacyUserValue(TimeFilterOption.today);
                  } else if (label == 'Yesterday') {
                    ref.read(userDateFilterProvider.notifier).state =
                        timeFilterToLegacyUserValue(TimeFilterOption.yesterday);
                  } else if (label == '7d') {
                    ref.read(userDateFilterProvider.notifier).state =
                        timeFilterToLegacyUserValue(TimeFilterOption.last7Days);
                  } else if (label == '30d') {
                    ref
                        .read(userDateFilterProvider.notifier)
                        .state = timeFilterToLegacyUserValue(
                      TimeFilterOption.last30Days,
                    );
                  } else {
                    ref.read(userDateFilterProvider.notifier).state = null;
                  }
                  ref.read(currentDashboardViewProvider.notifier).state =
                      DashboardView.users;
                }
                : null,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Text(
            '$label: $value',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color:
                  isClickableUserStat
                      ? gradientColors.first
                      : const Color(0xFF64748B),
              decoration: isClickableUserStat ? TextDecoration.underline : null,
            ),
          ),
        ),
      );
    }

    final cardContent = _AnimatedStatCardContainer(
      gradientColors: gradientColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (badgeLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        badgeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: gradientColors.first,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              countAsync.when(
                data:
                    (count) => Text(
                      count.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0F172A),
                        height: 1.1,
                      ),
                    ),
                loading:
                    () => const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                error: (_, __) => const Text('Error'),
              ),
              if (!isToday && statsAsync != null) ...[
                const SizedBox(height: 6),
                statsAsync.when(
                  data:
                      (stats) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            buildPeriodStat('Today', stats.today),
                            buildDotDivider(),
                            buildPeriodStat('Yesterday', stats.yesterday),
                            buildDotDivider(),
                            buildPeriodStat('7d', stats.last7Days),
                            buildDotDivider(),
                            buildPeriodStat('30d', stats.last30Days),
                          ],
                        ),
                      ),
                  loading:
                      () => const SizedBox(
                        height: 12,
                        width: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (isClickableUserStat) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            ref.read(userDateFilterProvider.notifier).state =
                isToday
                    ? timeFilterToLegacyUserValue(TimeFilterOption.today)
                    : null;
            ref.read(currentDashboardViewProvider.notifier).state =
                DashboardView.users;
          },
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

class _AnimatedStatCardContainer extends StatefulWidget {
  final Widget child;
  final List<Color> gradientColors;

  const _AnimatedStatCardContainer({
    required this.child,
    required this.gradientColors,
  });

  @override
  State<_AnimatedStatCardContainer> createState() =>
      _AnimatedStatCardContainerState();
}

class _AnimatedStatCardContainerState
    extends State<_AnimatedStatCardContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform:
            _isHovered
                ? Matrix4.translationValues(0, -4, 0)
                : Matrix4.identity(),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                _isHovered
                    ? widget.gradientColors.first.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  _isHovered
                      ? widget.gradientColors.first.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.03),
              blurRadius: _isHovered ? 16 : 8,
              offset: Offset(0, _isHovered ? 8 : 3),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class _DashboardCityFilterDropdown extends ConsumerWidget {
  const _DashboardCityFilterDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    if (!isSuperAdmin) {
      return const SizedBox.shrink();
    }

    final selectedCity = ref.watch(dashboardSelectedCityProvider);
    final citiesAsync = ref.watch(unverifiedCitiesProvider);

    return citiesAsync.when(
      data:
          (cities) => Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                ),
              ],
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selectedCity,
                hint: Text(
                  'All Cities 🌆',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF4F46E5),
                ),
                onChanged: (value) {
                  ref.read(dashboardSelectedCityProvider.notifier).state =
                      value;
                },
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_city_rounded,
                          size: 18,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All Cities 🌆',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...cities.map(
                    (city) => DropdownMenuItem<String?>(
                      value: city,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 18,
                            color: Color(0xFF3B82F6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            city,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      loading:
          () => const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _DashboardDateFilterDropdown extends ConsumerWidget {
  const _DashboardDateFilterDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFilter = ref.watch(dashboardSelectedDateFilterProvider);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: dateFilter,
          hint: Text(
            'Registration Filter 📅',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF4F46E5),
          ),
          onChanged: (value) {
            ref.read(dashboardSelectedDateFilterProvider.notifier).state =
                value;
          },
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'All Time ⏳',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem<String?>(
              value: 'today',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.today_rounded,
                    size: 18,
                    color: Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Today ⚡',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem<String?>(
              value: 'yesterday',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.history_rounded,
                    size: 18,
                    color: Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Yesterday 🕰️',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem<String?>(
              value: 'week',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: Color(0xFF7C3AED),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last 7 Days 📆',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem<String?>(
              value: 'month',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last 30 Days 📅',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem<String?>(
              value: '3months',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_view_month_rounded,
                    size: 18,
                    color: Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last 3 Months 🗓️',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem<String?>(
              value: '6months',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_note_rounded,
                    size: 18,
                    color: Color(0xFF9333EA),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last 6 Months 📊',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem<String?>(
              value: '1year',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.event_available_rounded,
                    size: 18,
                    color: Color(0xFFCA8A04),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Last 1 Year 🏆',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
}

class _AccessBlockedScreen extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? email;
  final VoidCallback onSignOut;

  const _AccessBlockedScreen({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.email,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 36, color: iconColor),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      if (email != null && email!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          email!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onSignOut,
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Sign Out'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
