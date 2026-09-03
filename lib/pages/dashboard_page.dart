import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/pages/auth_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';
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
import '../widgets/call_logs_data_view.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentView = ref.watch(currentDashboardViewProvider);

    return authState.when(
      data: (user) {
        if (user == null) {
          return const AuthPage();
        }
        return Scaffold(
          body: Row(
            children: [
              const SidebarNav(),
              Expanded(
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    child: _buildMainContent(currentView, ref),
                  ),
                ),
              ),
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

  Widget _buildMainContent(DashboardView view, WidgetRef ref) {
    switch (view) {
      case DashboardView.summary:
        return const _SummaryDashboard();
      case DashboardView.users:
        return const UsersDataView();
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
      case DashboardView.logs:
        return const CallLogsDataView();
      case DashboardView.payments:
        return const PaymentsDataView();
    }
  }
}

class _SummaryDashboard extends ConsumerWidget {
  const _SummaryDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminProfile = ref.watch(currentAdminProfileProvider).value;
    final adminName = adminProfile?['name'] ?? 'Super Boss';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Welcome Header - Serene Midnight Sapphire Theme
          Container(
            padding: const EdgeInsets.all(28),
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
              borderRadius: BorderRadius.circular(24),
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
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Welcome Back, $adminName! 👑',
                            style: GoogleFonts.poppins(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            // child: Text(
                            //   'COMMAND CENTER 🚀',
                            //   style: GoogleFonts.poppins(
                            //     color: Colors.white,
                            //     fontSize: 10,
                            //     fontWeight: FontWeight.w800,
                            //     letterSpacing: 0.5,
                            //   ),
                            // ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Close the Deal, Own the Win.✨',
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
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
              Text(
                'Overall Platform Summary ✨',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Overall Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.35,
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

          const SizedBox(height: 36),

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
              Text(
                "Today's Live Action Highlights 🚀",
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Today Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.45,
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

          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
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
                    Text(
                      'Unverified Businesses Queue 🛡️',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _DashboardCityFilterDropdown(),
              const SizedBox(width: 12),
              const _DashboardDateFilterDropdown(),
            ],
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: gradientColors.first,
                      ),
                    ),
                  ],
                ],
              ),
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
