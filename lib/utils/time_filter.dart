/// Shared time-range filter used across dashboard, users, rentals, promotions, and call logs.
enum TimeFilterOption {
  all,
  today,
  yesterday,
  last7Days,
  last30Days,
  last3Months,
  last6Months,
  last1Year,
}

extension TimeFilterOptionLabel on TimeFilterOption {
  String get label {
    switch (this) {
      case TimeFilterOption.all:
        return 'All Time';
      case TimeFilterOption.today:
        return 'Today';
      case TimeFilterOption.yesterday:
        return 'Yesterday';
      case TimeFilterOption.last7Days:
        return 'Last 7 Days';
      case TimeFilterOption.last30Days:
        return 'Last 30 Days';
      case TimeFilterOption.last3Months:
        return 'Last 3 Months';
      case TimeFilterOption.last6Months:
        return 'Last 6 Months';
      case TimeFilterOption.last1Year:
        return 'Last 1 Year';
    }
  }
}

DateTime _todayStart() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _nowLocal() => DateTime.now();

DateTime _asLocalDateTime(DateTime dateTime) {
  return dateTime.isUtc ? dateTime.toLocal() : dateTime;
}

DateTime _rollingWindowStartFromNow(int days) {
  return _nowLocal().subtract(Duration(days: days));
}

/// Returns true when [date] falls within the selected [filter] range.
bool matchesTimeFilter(DateTime? date, TimeFilterOption filter) {
  if (filter == TimeFilterOption.all) return true;
  if (date == null) return false;

  final localDate = _asLocalDateTime(date);
  final now = _nowLocal();
  final todayStart = _todayStart();
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));

  switch (filter) {
    case TimeFilterOption.all:
      return true;
    case TimeFilterOption.today:
      return !localDate.isBefore(todayStart) && !localDate.isAfter(now);
    case TimeFilterOption.yesterday:
      return !localDate.isBefore(yesterdayStart) &&
          localDate.isBefore(todayStart);
    case TimeFilterOption.last7Days:
      final start = _rollingWindowStartFromNow(7);
      return !localDate.isBefore(start) && !localDate.isAfter(now);
    case TimeFilterOption.last30Days:
      final start = _rollingWindowStartFromNow(30);
      return !localDate.isBefore(start) && !localDate.isAfter(now);
    case TimeFilterOption.last3Months:
      final start = _rollingWindowStartFromNow(90);
      return !localDate.isBefore(start) && !localDate.isAfter(now);
    case TimeFilterOption.last6Months:
      final start = _rollingWindowStartFromNow(180);
      return !localDate.isBefore(start) && !localDate.isAfter(now);
    case TimeFilterOption.last1Year:
      final start = _rollingWindowStartFromNow(365);
      return !localDate.isBefore(start) && !localDate.isAfter(now);
  }
}

/// Earliest timestamp for Firestore `>=` queries. Returns null for "All Time".
DateTime? timeFilterQueryStart(TimeFilterOption filter) {
  final todayStart = _todayStart();
  switch (filter) {
    case TimeFilterOption.all:
      return null;
    case TimeFilterOption.today:
      return todayStart;
    case TimeFilterOption.yesterday:
      return todayStart.subtract(const Duration(days: 1));
    case TimeFilterOption.last7Days:
      return _rollingWindowStartFromNow(7);
    case TimeFilterOption.last30Days:
      return _rollingWindowStartFromNow(30);
    case TimeFilterOption.last3Months:
      return _rollingWindowStartFromNow(90);
    case TimeFilterOption.last6Months:
      return _rollingWindowStartFromNow(180);
    case TimeFilterOption.last1Year:
      return _rollingWindowStartFromNow(365);
  }
}

/// Exclusive upper bound for Firestore `<` queries. Returns null when no cap is needed.
DateTime? timeFilterQueryEndExclusive(TimeFilterOption filter) {
  final todayStart = _todayStart();
  switch (filter) {
    case TimeFilterOption.all:
      return null;
    case TimeFilterOption.today:
      return null;
    case TimeFilterOption.yesterday:
      return todayStart;
    case TimeFilterOption.last7Days:
    case TimeFilterOption.last30Days:
    case TimeFilterOption.last3Months:
    case TimeFilterOption.last6Months:
    case TimeFilterOption.last1Year:
      return null;
  }
}

/// Inclusive upper bound for Firestore `<=` queries when the range should stop at "now".
DateTime? timeFilterQueryEndInclusive(TimeFilterOption filter) {
  final now = _nowLocal();
  switch (filter) {
    case TimeFilterOption.all:
    case TimeFilterOption.yesterday:
      return null;
    case TimeFilterOption.today:
    case TimeFilterOption.last7Days:
    case TimeFilterOption.last30Days:
    case TimeFilterOption.last3Months:
    case TimeFilterOption.last6Months:
    case TimeFilterOption.last1Year:
      return now;
  }
}

/// Legacy string values used by the users page / dashboard stat cards (`null` = all).
TimeFilterOption timeFilterFromLegacyUserValue(String? value) {
  switch (value) {
    case 'today':
      return TimeFilterOption.today;
    case 'yesterday':
      return TimeFilterOption.yesterday;
    case 'week':
      return TimeFilterOption.last7Days;
    case 'month':
      return TimeFilterOption.last30Days;
    case '3months':
      return TimeFilterOption.last3Months;
    case '6months':
      return TimeFilterOption.last6Months;
    case '1year':
      return TimeFilterOption.last1Year;
    default:
      return TimeFilterOption.all;
  }
}

String? timeFilterToLegacyUserValue(TimeFilterOption filter) {
  switch (filter) {
    case TimeFilterOption.all:
      return null;
    case TimeFilterOption.today:
      return 'today';
    case TimeFilterOption.yesterday:
      return 'yesterday';
    case TimeFilterOption.last7Days:
      return 'week';
    case TimeFilterOption.last30Days:
      return 'month';
    case TimeFilterOption.last3Months:
      return '3months';
    case TimeFilterOption.last6Months:
      return '6months';
    case TimeFilterOption.last1Year:
      return '1year';
  }
}

/// Legacy rental/promotions string labels.
TimeFilterOption timeFilterFromRentalLabel(String label) {
  switch (label) {
    case 'Today':
      return TimeFilterOption.today;
    case 'Yesterday':
      return TimeFilterOption.yesterday;
    case 'Last 7 Days':
      return TimeFilterOption.last7Days;
    case 'Last 30 Days':
    case 'Last 1 Month':
      return TimeFilterOption.last30Days;
    case 'Last 3 Months':
      return TimeFilterOption.last3Months;
    case 'Last 6 Months':
      return TimeFilterOption.last6Months;
    case 'Last 1 Year':
      return TimeFilterOption.last1Year;
    default:
      return TimeFilterOption.all;
  }
}

String timeFilterToRentalLabel(TimeFilterOption filter) => filter.label;
