import 'package:flutter_riverpod/flutter_riverpod.dart';

enum DashboardView {
  summary,
  users,
  servicePosts,
  orders,
  rentalProperties,
  tickets,
  verification,
  whatsappMessages,
  admin,
  appConfig,
  logs,
  payments,
}

// Manual StateProvider for the current dashboard view
final currentDashboardViewProvider = StateProvider<DashboardView>((ref) {
  return DashboardView.summary;
});
