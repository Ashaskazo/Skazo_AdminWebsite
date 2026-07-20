import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/filter_providers.dart';
import 'package:skazo_admin/utils/time_filter.dart';

/// Reusable time filter dropdown wired to [globalTimeFilterProvider].
class TimeFilterDropdown extends ConsumerWidget {
  const TimeFilterDropdown({
    super.key,
    this.height = 42,
    this.hint = 'Registration Filter',
    this.compact = false,
    this.borderRadius = 12,
  });

  final double height;
  final String hint;
  final bool compact;
  final double borderRadius;

  static const _options = [
    TimeFilterOption.all,
    TimeFilterOption.today,
    TimeFilterOption.yesterday,
    TimeFilterOption.last7Days,
    TimeFilterOption.last30Days,
    TimeFilterOption.last3Months,
    TimeFilterOption.last6Months,
    TimeFilterOption.last1Year,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(globalTimeFilterProvider);

    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TimeFilterOption>(
          value: selected,
          hint: Text(
            hint,
            style: GoogleFonts.poppins(
              fontSize: compact ? 13 : 14,
              color: const Color(0xFF64748B),
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
          onChanged: (value) {
            if (value != null) {
              ref.read(globalTimeFilterProvider.notifier).state = value;
            }
          },
          items: _options
              .map(
                (option) => DropdownMenuItem<TimeFilterOption>(
                  value: option,
                  child: Text(
                    option.label,
                    style: GoogleFonts.poppins(
                      fontSize: compact ? 13 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Call-log sidebar variant with the same global filter options.
class CallLogsTimeFilterDropdown extends ConsumerWidget {
  const CallLogsTimeFilterDropdown({
    super.key,
    required this.onChanged,
  });

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(globalTimeFilterProvider);

    return DropdownButtonFormField<TimeFilterOption>(
      initialValue: selected,
      decoration: InputDecoration(
        labelText: 'Date Range',
        labelStyle: GoogleFonts.poppins(fontSize: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      style: GoogleFonts.poppins(fontSize: 13),
      items: TimeFilterDropdown._options
          .map(
            (option) => DropdownMenuItem<TimeFilterOption>(
              value: option,
              child: Text(option.label),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          ref.read(globalTimeFilterProvider.notifier).state = value;
          onChanged();
        }
      },
    );
  }
}
