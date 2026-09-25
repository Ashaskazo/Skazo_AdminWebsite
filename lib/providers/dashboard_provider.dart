import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardView {
  summary,
  users,
  serviceProviders,
  deactivatedList,
  servicePosts,
  // orders,
  rentalProperties,
  localPromotions,
  tickets,
  verification,
  whatsappMessages,
  admin,
  appConfig,
  logs,
  payments,
  payPerLead,
}

// Manual StateProvider for the current dashboard view
final currentDashboardViewProvider = StateProvider<DashboardView>((ref) {
  return DashboardView.summary;
});

// StateProvider for sidebar collapse state
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
