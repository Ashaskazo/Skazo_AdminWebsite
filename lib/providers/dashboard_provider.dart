import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardView {
  summary,
  users,
  payPerLead,
  deactivatedList,
  callLogSheet,
  callLogsDetails,
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
  pendingProviderFeedback,
  payments,
    serviceProviders,
}

// Manual StateProvider for the current dashboard view
final currentDashboardViewProvider = StateProvider<DashboardView>((ref) {
  return DashboardView.summary;
});

// StateProvider for sidebar collapse state
final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);
