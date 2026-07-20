import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/utils/time_filter.dart';

/// Single source of truth for time-range filtering across all admin pages.
final globalTimeFilterProvider = StateProvider<TimeFilterOption>(
  (ref) => TimeFilterOption.all,
);
