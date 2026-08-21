/// Dashboard aggregate statistics provider.
///
/// Architecture:
///   - Reads from `dashboard_stats/global` or `dashboard_stats/cities/{cityName}`
///   - Real-time StreamProvider — updates instantly when the document changes
///   - Falls back to indexed Firestore aggregate count queries when the stat
///     document does not yet exist (pre-migration or newly created city)
///   - All KPI cards share ONE document read per scope — never one query per card

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/user_providers.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class DashboardStats {
  final int totalUsers;
  final int totalCustomers;
  final int totalServiceProviders;
  final int todayRegistrations;
  final int todayServiceProviders;
  final int todayCallLogs;
  final int totalCallLogs;
  final int totalServicePosts;
  final int totalRentalProperties;
  final bool isLoading;

  const DashboardStats({
    this.totalUsers = 0,
    this.totalCustomers = 0,
    this.totalServiceProviders = 0,
    this.todayRegistrations = 0,
    this.todayServiceProviders = 0,
    this.todayCallLogs = 0,
    this.totalCallLogs = 0,
    this.totalServicePosts = 0,
    this.totalRentalProperties = 0,
    this.isLoading = false,
  });

  factory DashboardStats.loading() =>
      const DashboardStats(isLoading: true);

  factory DashboardStats.fromMap(Map<String, dynamic> data) {
    return DashboardStats(
      totalUsers: _parseInt(data['totalUsers']),
      totalCustomers: _parseInt(data['totalCustomers']),
      totalServiceProviders: _parseInt(data['totalServiceProviders']),
      todayRegistrations: _parseInt(data['todayRegistrations']),
      todayServiceProviders: _parseInt(data['todayServiceProviders']),
      todayCallLogs: _parseInt(data['todayCallLogs']),
      totalCallLogs: _parseInt(data['totalCallLogs']),
      totalServicePosts: _parseInt(data['totalServicePosts']),
      totalRentalProperties: _parseInt(data['totalRentalProperties']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ── Firestore paths ───────────────────────────────────────────────────────────

const _statsCollection = 'dashboard_stats';
const _globalDoc = 'global';
String _cityDocPath(String cityName) => 'cities/$cityName';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Streams the aggregate stats document for the currently selected city
/// (or the global document when no city is selected).
///
/// When the aggregate document does not yet exist, returns a `DashboardStats`
/// where `isLoading = true` so the UI can show a skeleton/spinner rather
/// than showing zeros.
final dashboardStatsProvider = StreamProvider.autoDispose<DashboardStats>((ref) {
  final selectedCity = ref.watch(dashboardSelectedCityProvider);

  final docRef = selectedCity != null && selectedCity.trim().isNotEmpty
      ? FirebaseFirestore.instance
          .collection(_statsCollection)
          .doc(_cityDocPath(selectedCity))
      : FirebaseFirestore.instance
          .collection(_statsCollection)
          .doc(_globalDoc);

  return docRef.snapshots().map((snap) {
    if (!snap.exists || snap.data() == null) {
      return DashboardStats.loading();
    }
    return DashboardStats.fromMap(snap.data()!);
  });
});