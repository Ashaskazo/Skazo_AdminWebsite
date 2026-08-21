/// Centralized service responsible for:
///   - Provider classification (using existing isServiceProviderDoc logic)
///   - Pincode normalization and extraction
///   - Computing `serviceProviderCities` for a user document
///   - Providing a shared, cached pincode map from Property_Pincodes
///
/// All pages (Dashboard, Users, Call Logs) MUST use this service for
/// city-membership logic. Never duplicate the business rule elsewhere.

import 'package:skazo_admin/models/user_model.dart' show UserModel;
import 'package:skazo_admin/utils/property_pincodes_cache.dart';

// -- Re-exported so callers never need to touch the raw helpers --------------

/// Returns `true` if the Firestore document map represents a Service Provider.
/// Source of truth: non-empty businessname + businesspic + businessaddress.
bool isServiceProviderData(Map<String, dynamic> data) =>
    UserModel.isServiceProviderDoc(data);

// -- Pincode helpers ----------------------------------------------------------

/// Normalizes a raw pincode-like string to exactly 6 digits, or `null`.
/// Strips whitespace and non-digits; rejects anything that is not 6 digits.
String? normalizePincode(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return digits.length == 6 ? digits : null;
}

/// Extracts a 6-digit Indian pincode from a user/provider document map.
///
/// Priority:
///   1. `businesspincode` / `businessPincode` / `business_pincode`
///   2. First 6-digit number found in `businessaddress` / `businessAddress`
///   3. `pincode` / `pinCode` / `pin`
///   4. First 6-digit number found in any other address field
String? extractBusinessPincode(Map<String, dynamic> data) {
  // 1. Explicit business pincode field (case-insensitive key variants)
  for (final key in const [
    'businesspincode',
    'businessPincode',
    'business_pincode',
    'BusinessPincode',
  ]) {
    final raw = data[key]?.toString().trim();
    final normalized = normalizePincode(raw);
    if (normalized != null) return normalized;
  }

  // 2. Extract from business address
  for (final key in const [
    'businessaddress',
  ]) {
    final address = data[key]?.toString() ?? '';
    if (address.isNotEmpty) {
      final match = RegExp(r'\b\d{6}\b').firstMatch(address);
      final normalized = normalizePincode(match?.group(0));
      if (normalized != null) return normalized;
    }
  }

  // 3. Generic pincode fields
  for (final key in const ['pincode', 'pinCode', 'pin']) {
    final raw = data[key]?.toString().trim();
    final normalized = normalizePincode(raw);
    if (normalized != null) return normalized;
  }

  // 4. Any other address field
  for (final key in const [
    'address',
    'customerAddress',
    'customeraddress',
    'customer_address',
  ]) {
    final address = data[key]?.toString() ?? '';
    if (address.isNotEmpty) {
      final match = RegExp(r'\b\d{6}\b').firstMatch(address);
      final normalized = normalizePincode(match?.group(0));
      if (normalized != null) return normalized;
    }
  }

  return null;
}

// -- City membership computation ----------------------------------------------

String _normalizeCityKey(String city) =>
    city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Returns the list of city names this provider belongs to, based on:
///   - **Method A (Pincode match)**: provider pincode in city pincode set
///   - **Method B (Address string match)**: city name appears in businessAddress
///
/// [pincodesMap] is `Map<cityName, List<pincode>>` (canonical capitalised keys,
/// as returned by [loadPropertyPincodes]).
///
/// A provider may appear in MULTIPLE cities if a pincode is shared or the
/// address mentions multiple known city names.
///
/// Returns an empty list for documents that are not Service Providers.
List<String> computeServiceProviderCities(
  Map<String, dynamic> data,
  Map<String, List<String>> pincodesMap,
) {
  if (!isServiceProviderData(data)) return const [];
  if (pincodesMap.isEmpty) return const [];

  final providerPin = extractBusinessPincode(data);
  final businessAddress = (data['businessaddress'] ??
          data['businessAddress'] ??
          data['business_address'] ??
          '')
      .toString()
      .toLowerCase();

  final matchedCities = <String>{};

  for (final entry in pincodesMap.entries) {
    final cityName = entry.key; // canonical, e.g. "Hyderabad"
    final normalizedCityKey = _normalizeCityKey(cityName);

    // Method A: pincode match
    if (providerPin != null) {
      for (final pin in entry.value) {
        if (normalizePincode(pin) == providerPin) {
          matchedCities.add(cityName);
          break;
        }
      }
    }

    // Method B: city name appears in business address
    if (businessAddress.isNotEmpty && normalizedCityKey.isNotEmpty) {
      if (businessAddress.contains(normalizedCityKey)) {
        matchedCities.add(cityName);
      }
    }
  }

  return matchedCities.toList()..sort();
}

// -- Shared pincode map access ------------------------------------------------

/// Loads and caches the Property_Pincodes map.
/// Uses the existing [loadPropertyPincodes] cache — never fetches twice.
Future<Map<String, List<String>>> loadCityPincodesMap({
  bool forceRefresh = false,
}) {
  return loadPropertyPincodes(forceRefresh: forceRefresh);
}

// -- Admin city scope validation ----------------------------------------------

/// Returns `true` if [selectedCity] is within the admin's [assignedCities].
/// Super admins (empty assignedCities) are always allowed.
bool isSelectedCityAuthorized(
  String selectedCity,
  List<String> assignedCities,
) {
  if (assignedCities.isEmpty) return true; // Super Admin — unrestricted
  final norm = _normalizeCityKey(selectedCity);
  return assignedCities.any((c) => _normalizeCityKey(c) == norm);
}