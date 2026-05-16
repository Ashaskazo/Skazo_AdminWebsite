import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/pages/auth_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/widgets/sidebar_nav.dart';
import 'package:skazo_admin/widgets/collection_data_view.dart';
import 'package:skazo_admin/widgets/users_data_view.dart';
import 'package:skazo_admin/widgets/orders_data_view.dart';
import 'package:skazo_admin/widgets/service_posts_data_view.dart';
import 'package:skazo_admin/widgets/rental_properties_data_view.dart';
import 'package:skazo_admin/widgets/admins_data_view.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/widgets/unverified_businesses_grid.dart';

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
                  child: _buildMainContent(currentView),
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

  Widget _buildMainContent(DashboardView view) {
    switch (view) {
      case DashboardView.summary:
        return const _SummaryDashboard();
      case DashboardView.users:
        return const UsersDataView();
      case DashboardView.servicePosts:
        return const ServicePostsDataView();
      case DashboardView.orders:
        return const OrdersDataView();
      case DashboardView.rentalProperties:
        return const RentalPropertiesDataView();
      case DashboardView.tickets:
        return const CollectionDataView(
          collectionName: 'tickets',
          title: 'Support Tickets',
        );
      case DashboardView.verification:
        return const CollectionDataView(
          collectionName: 'verification',
          title: 'Verification Requests',
        );
      case DashboardView.whatsappMessages:
        return const CollectionDataView(
          collectionName: 'whatsappMessages',
          title: 'WhatsApp Logs',
        );
      case DashboardView.admin:
        return const AdminsDataView();
      case DashboardView.appConfig:
        return const CollectionDataView(
          collectionName: 'app_config',
          title: 'Application Config',
        );
      case DashboardView.logs:
        return const CollectionDataView(
          collectionName: 'callLogs',
          title: 'System Logs',
        );
    }
  }
}

class _SummaryDashboard extends ConsumerWidget {
  const _SummaryDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Admin Dashboard',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome back! Here is an overview of your platform.',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 32),

          // Overall Summary Header
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF2563EB),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Overall Summary',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Overall Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                ref,
                'Total Users',
                'users',
                Icons.people,
                Colors.blue,
              ),
              _buildStatCard(
                ref,
                'Call Logs',
                'callLogs',
                Icons.phone_callback,
                Colors.orange,
              ),
              _buildStatCard(
                ref,
                'Service Posts',
                'service_posts',
                Icons.work,
                Colors.green,
              ),
              _buildStatCard(
                ref,
                'Properties',
                'rental_properties',
                Icons.home,
                Colors.purple,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Today Summary Header
          Row(
            children: [
              const Icon(
                Icons.summarize_rounded,
                color: Color(0xFF16A34A),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Today Summary',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Today Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 2,
            crossAxisSpacing: 24,
            mainAxisSpacing: 24,
            childAspectRatio: 1.5,
            children: [
              _buildStatCard(
                ref,
                'Total Users',
                'users',
                Icons.people,
                Colors.blue,
                isToday: true,
              ),
              _buildStatCard(
                ref,
                'Call Logs',
                'callLogs',
                Icons.phone_callback,
                Colors.orange,
                isToday: true,
              ),
              _buildStatCard(
                ref,
                'Service Posts',
                'service_posts',
                Icons.work,
                Colors.green,
                isToday: true,
              ),
              _buildStatCard(
                ref,
                'Properties',
                'rental_properties',
                Icons.home,
                Colors.purple,
                isToday: true,
              ),
            ],
          ),

          const SizedBox(height: 40),
          const SizedBox(height: 40),
          Text(
            'New Registered Businesses (Pending Verification)',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
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
    Color color, {
    bool isToday = false,
  }) {
    final countAsync =
        isToday
            ? ref.watch(collectionTodayCountProvider(collection))
            : ref.watch(collectionCountProvider(collection));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  if (isToday)
                    Text(
                      'Today',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          countAsync.when(
            data:
                (count) => Text(
                  count.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
            loading:
                () => const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            error: (_, __) => const Text('Error'),
          ),
        ],
      ),
    );
  }
}
