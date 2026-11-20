// Shared city parsing, normalization, and centralized city-access evaluation
// across all entities, repositories, and UI screens.

const Map<String, String> _kCityAliasCanonical = {
  'bheemavaram': 'bhimavaram',
  'bhimavaram': 'bhimavaram',
  'tirupathi': 'tirupati',
  'tirupati': 'tirupati',
  'bengaluru': 'bangalore',
  'bangalore': 'bangalore',
  'vijaywada': 'vijayawada',
  'vijayawada': 'vijayawada',
  'vishakhapatnam': 'visakhapatnam',
  'visakhapatnam': 'visakhapatnam',
  'vizag': 'visakhapatnam',
};

const Map<String, List<String>> _kCityKeyQueryVariants = {
  'bhimavaram': ['bhimavaram', 'bheemavaram'],
  'tirupati': ['tirupati', 'tirupathi'],
  'bangalore': ['bangalore', 'bengaluru'],
  'vijayawada': ['vijayawada', 'vijaywada'],
  'visakhapatnam': ['visakhapatnam', 'vishakhapatnam', 'vizag'],
};

const String kMissingCityFilterValue = '__MISSING_CITY__';

String _normalizeCityKey(String city) =>
    city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Normalizes a city string and maps known spelling variants to a canonical key.
String canonicalizeCityKey(String city) {
  final normalized = _normalizeCityKey(city);
  if (normalized.isEmpty) return '';
  return _kCityAliasCanonical[normalized] ?? normalized;
}

/// Expands assigned cities into unique Firestore `cityKey` query values
/// (including known spelling variants such as `bhimavaram`/`bheemavaram`).
List<String> expandQueryableCityKeys(Iterable<String> cities) {
  final keys = <String>{};
  for (final raw in cities) {
    final normalized = _normalizeCityKey(raw);
    if (normalized.isEmpty) continue;
    keys.add(normalized);
    final canonical = canonicalizeCityKey(normalized);
    keys.add(canonical);
    final variants = _kCityKeyQueryVariants[canonical];
    if (variants != null) {
      keys.addAll(variants);
    }
  }
  return keys.toList(growable: false);
}

/// Splits a list into fixed-size chunks (e.g. for Firestore `whereIn` limit of 30).
List<List<T>> chunkList<T>(List<T> items, [int chunkSize = 30]) {
  if (items.isEmpty || chunkSize <= 0) return const [];
  final chunks = <List<T>>[];
  for (var i = 0; i < items.length; i += chunkSize) {
    final end = (i + chunkSize < items.length) ? i + chunkSize : items.length;
    chunks.add(items.sublist(i, end));
  }
  return chunks;
}

enum AdminAccessStatus {
  loading,
  unauthenticated,
  deniedUnauthorized,
  deniedInactive,
  noCitiesAssigned,
  authorized,
}

/// Centralized representation of the logged-in admin/employee access scope.
class CityAccessScope {
  final AdminAccessStatus status;
  final bool isSuperAdmin;
  final bool isActive;
  final List<String> assignedCities;
  final List<String> normalizedCityKeys;
  final String? adminId;
  final String? email;
  final String? displayName;
  final String? role;
  final String? errorMessage;

  const CityAccessScope({
    required this.status,
    required this.isSuperAdmin,
    required this.isActive,
    this.assignedCities = const [],
    this.normalizedCityKeys = const [],
    this.adminId,
    this.email,
    this.displayName,
    this.role,
    this.errorMessage,
  });

  const CityAccessScope.loading({String? email})
    : this(
        status: AdminAccessStatus.loading,
        isSuperAdmin: false,
        isActive: false,
        email: email,
      );

  const CityAccessScope.unauthenticated()
    : this(
        status: AdminAccessStatus.unauthenticated,
        isSuperAdmin: false,
        isActive: false,
      );

  const CityAccessScope.deniedUnauthorized({
    String? email,
    String? errorMessage,
  }) : this(
         status: AdminAccessStatus.deniedUnauthorized,
         isSuperAdmin: false,
         isActive: false,
         email: email,
         errorMessage: errorMessage,
       );

  const CityAccessScope.deniedInactive({
    String? email,
    String? adminId,
    String? displayName,
    String? role,
  }) : this(
         status: AdminAccessStatus.deniedInactive,
         isSuperAdmin: false,
         isActive: false,
         email: email,
         adminId: adminId,
         displayName: displayName,
         role: role,
       );

  const CityAccessScope.noCitiesAssigned({
    String? email,
    String? adminId,
    String? displayName,
    String? role,
  }) : this(
         status: AdminAccessStatus.noCitiesAssigned,
         isSuperAdmin: false,
         isActive: true,
         email: email,
         adminId: adminId,
         displayName: displayName,
         role: role,
       );

  factory CityAccessScope.authorized({
    required bool isSuperAdmin,
    List<String> assignedCities = const [],
    String? adminId,
    String? email,
    String? displayName,
    String? role,
  }) {
    final cleanedCities = <String>[];
    final seenCanonical = <String>{};
    for (final city in assignedCities) {
      final trimmed = city.trim();
      final canonical = canonicalizeCityKey(trimmed);
      if (trimmed.isNotEmpty && seenCanonical.add(canonical)) {
        cleanedCities.add(trimmed);
      }
    }

    if (!isSuperAdmin && cleanedCities.isEmpty) {
      return CityAccessScope.noCitiesAssigned(
        email: email,
        adminId: adminId,
        displayName: displayName,
        role: role,
      );
    }

    return CityAccessScope(
      status: AdminAccessStatus.authorized,
      isSuperAdmin: isSuperAdmin,
      isActive: true,
      assignedCities: isSuperAdmin ? const [] : List.unmodifiable(cleanedCities),
      normalizedCityKeys:
          isSuperAdmin
              ? const []
              : List.unmodifiable(expandQueryableCityKeys(cleanedCities)),
      adminId: adminId,
      email: email,
      displayName: displayName,
      role: role,
    );
  }

  bool get isAuthorized => status == AdminAccessStatus.authorized;
  bool get isUnrestricted => isAuthorized && isSuperAdmin;
  bool get hasNoCities =>
      status == AdminAccessStatus.noCitiesAssigned ||
      (isAuthorized && !isSuperAdmin && assignedCities.isEmpty);

  /// Returns true if the requested city string is permitted for this scope.
  bool canAccessCityName(String? city) {
    if (!isAuthorized) return false;
    if (isSuperAdmin) return true;
    if (city == null || city.trim().isEmpty) return false;
    final target = canonicalizeCityKey(city);
    if (target.isEmpty) return false;
    return assignedCities.any((c) {
      final normAssigned = canonicalizeCityKey(c);
      return normAssigned == target ||
          normAssigned.contains(target) ||
          target.contains(normAssigned);
    });
  }

  /// Checks whether this scope permits reading/modifying [record].
  bool allowsRecord(
    Map<String, dynamic> record, {
    String? selectedCity,
    Map<String, List<String>> pincodesMap = const {},
    Map<String, String>? pincodeCityLookup,
    Map<String, Map<String, dynamic>>? relatedEntityLookup,
  }) {
    return recordMatchesCityScope(
      record,
      this,
      selectedCity: selectedCity,
      pincodesMap: pincodesMap,
      pincodeCityLookup: pincodeCityLookup,
      relatedEntityLookup: relatedEntityLookup,
    );
  }
}

String _addressSource(Map<String, dynamic> user) {
  final rawLocation = user['location'];
  final locationStr = rawLocation is String ? rawLocation : null;
  final addr = user['businessAddress'] ??
      user['businessaddress'] ??
      user['customerAddress'] ??
      user['address'] ??
      user['business_address'] ??
      user['customer_address'] ??
      locationStr ??
      '';
  return addr.toString().trim();
}

String? _explicitCityField(Map<String, dynamic> user) {
  final raw = (user['City'] ??
          user['city'] ??
          user['serviceCity'] ??
          user['service_city'] ??
          user['providerCity'] ??
          user['businessCity'] ??
          user['customerCity'] ??
          user['business_city'] ??
          user['customer_city'] ??
          user['cityKey'])
      ?.toString()
      .trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}

String? _normalizePincode(String? value) {
  if (value == null) {
    return null;
  }
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 6) {
    return null;
  }
  return digits;
}

bool _isPlusCodeSegment(String value) {
  final compact = value.replaceAll(' ', '');
  return RegExp(
    r'^[A-Z0-9]{4,}\+[A-Z0-9]{2,}$',
    caseSensitive: false,
  ).hasMatch(compact);
}

bool _isNonCitySegment(String value) {
  final normalized = value.trim().toLowerCase();
  if (normalized.isEmpty) {
    return true;
  }
  if (_normalizePincode(normalized) != null) {
    return true;
  }
  if (_isPlusCodeSegment(normalized)) {
    return true;
  }
  const nonCityNames = {
    'india',
    'andhra pradesh',
    'telangana',
    'karnataka',
    'tamil nadu',
    'ap',
    'ts',
  };
  if (nonCityNames.contains(normalized)) {
    return true;
  }
  return normalized.startsWith('h.no') ||
      normalized.startsWith('d.no') ||
      normalized.startsWith('door no') ||
      normalized.startsWith('doorno') ||
      normalized.startsWith('flat') ||
      normalized.startsWith('plot');
}

String? _cleanCitySegment(String value) {
  final withoutPincode = value.replaceAll(RegExp(r'\b\d{6}\b'), ' ');
  final cleaned =
      withoutPincode
          .replaceAll(RegExp(r'^[\s,.\-_/]+|[\s,.\-_/]+$'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  if (cleaned.isEmpty || _isNonCitySegment(cleaned)) {
    return null;
  }

  return cleaned;
}

List<String> _addressSegments(String address) {
  return address
      .split(',')
      .map((segment) => segment.trim())
      .where((segment) => segment.isNotEmpty)
      .toList();
}

String? _guessCityFromKnownPincodeRanges(String? pincode) {
  final pin = int.tryParse(pincode ?? '') ?? 0;
  if (pin >= 520001 && pin <= 520099) return 'Vijayawada';
  if (pin >= 500001 && pin <= 500096) return 'Hyderabad';
  if (pin >= 534201 && pin <= 534299) return 'Bheemavaram';
  if ((pin >= 560001 && pin <= 560111) || (pin >= 562000 && pin <= 562999)) {
    return 'Bangalore';
  }
  if (pin >= 517501 && pin <= 517599) return 'Tirupathi';
  if (pin == 522001 || pin == 522007 || pin == 522004) return 'Guntur';
  return null;
}

String? extractUserCityFromAddress(Map<String, dynamic> user) {
  final address = _addressSource(user);
  if (address.isEmpty) {
    return _explicitCityField(user);
  }

  final parts = _addressSegments(address);
  if (parts.isEmpty) {
    return _explicitCityField(user);
  }

  final pincodeIndex = parts.indexWhere(
    (segment) => _normalizePincode(segment) != null,
  );
  if (pincodeIndex > 0) {
    for (var index = pincodeIndex - 1; index >= 0; index--) {
      final candidate = _cleanCitySegment(parts[index]);
      if (candidate != null) {
        return candidate;
      }
    }
  }

  for (var index = parts.length - 1; index >= 0; index--) {
    final candidate = _cleanCitySegment(parts[index]);
    if (candidate != null) {
      return candidate;
    }
  }

  return _explicitCityField(user);
}

String getSmartCity(Map<String, dynamic> user) {
  final canonicalCity = (user['city'] ?? user['City'])?.toString().trim();
  if (canonicalCity != null && canonicalCity.isNotEmpty) {
    return canonicalCity;
  }

  final cityKey = user['cityKey']?.toString().trim();
  if (cityKey != null && cityKey.isNotEmpty) {
    return cityKey;
  }

  final explicitCity = _explicitCityField(user);
  if (explicitCity != null) {
    return explicitCity;
  }

  final cityFromAddress = extractUserCityFromAddress(user);
  if (cityFromAddress != null) {
    return cityFromAddress;
  }

  final guessedCity = _guessCityFromKnownPincodeRanges(
    extractUserPincode(user),
  );
  if (guessedCity != null) {
    return guessedCity;
  }

  return 'Unknown';
}

String? deriveUserCity(Map<String, dynamic> user) {
  final resolved = resolveUserCityName(user, const {}, null);
  if (resolved == null) {
    return null;
  }

  final trimmed = resolved.trim();
  if (trimmed.isEmpty || _normalizeCityKey(trimmed) == 'unknown') {
    return null;
  }

  return trimmed;
}

Map<String, String> buildPincodeCityLookup(
  Map<String, List<String>> pincodesMap,
) {
  final lookup = <String, String>{};
  for (final entry in pincodesMap.entries) {
    for (final pin in entry.value) {
      final normalized = _normalizePincode(pin);
      if (normalized != null && normalized.isNotEmpty) {
        lookup[normalized] = entry.key;
      }
    }
  }
  return lookup;
}

String? extractUserPincode(Map<String, dynamic> user) {
  final explicitPin = (user['pincode'] ??
          user['businessPincode'] ??
          user['customerPincode'] ??
          user['pinCode'] ??
          user['business_pincode'] ??
          user['customer_pincode'] ??
          user['pin'])
      ?.toString()
      .trim();
  final normExplicit = _normalizePincode(explicitPin);
  if (normExplicit != null) return normExplicit;

  final address = _addressSource(user);
  final pinMatch = RegExp(r'\b\d{6}\b').firstMatch(address);
  return _normalizePincode(pinMatch?.group(0));
}

/// Maps a user to a known city name from [knownCities] using pincode map + smart city.
String? resolveUserCityName(
  Map<String, dynamic> user,
  Map<String, List<String>> pincodesMap,
  Map<String, String>? pincodeCityLookup,
) {
  final userPin = extractUserPincode(user);

  if (userPin != null && pincodesMap.isNotEmpty) {
    final resolvedByLookup = pincodeCityLookup?[userPin];
    if (resolvedByLookup != null) {
      return resolvedByLookup;
    }

    for (final entry in pincodesMap.entries) {
      if (entry.value.any((pin) => _normalizePincode(pin) == userPin)) {
        return entry.key;
      }
    }
  }

  final addressCity =
      extractUserCityFromAddress(user) ?? _explicitCityField(user);
  if (addressCity == null || addressCity.isEmpty) {
    return _guessCityFromKnownPincodeRanges(userPin);
  }

  if (pincodesMap.isNotEmpty) {
    final normalized = canonicalizeCityKey(addressCity);
    for (final known in pincodesMap.keys) {
      final normKnown = canonicalizeCityKey(known);
      if (normKnown == normalized) return known;
      if (normalized.contains(normKnown) || normKnown.contains(normalized)) {
        return known;
      }
    }
  }

  return addressCity;
}

bool _cityKeysMatch(String candidateRaw, String canonicalTarget) {
  final canonicalCandidate = canonicalizeCityKey(candidateRaw);
  if (canonicalCandidate.isEmpty || canonicalTarget.isEmpty) return false;
  return canonicalCandidate == canonicalTarget ||
      canonicalCandidate.contains(canonicalTarget) ||
      canonicalTarget.contains(canonicalCandidate);
}

bool userMatchesCity(
  Map<String, dynamic> user,
  String selectedCity,
  Map<String, List<String>> pincodesMap,
  Map<String, String>? pincodeCityLookup, {
  String? normalizedTargetCity,
  Set<String>? cityPins,
}) {
  final targetCity = canonicalizeCityKey(normalizedTargetCity ?? selectedCity);
  if (targetCity.isEmpty) return true;

  final directCityKey =
      (user['cityKey'] ??
              user['city'] ??
              user['serviceCity'] ??
              user['service_city'] ??
              user['providerCity'] ??
              user['businessCity'] ??
              user['customerCity'])
          ?.toString()
          .trim();

  if (directCityKey != null && directCityKey.isNotEmpty) {
    if (_cityKeysMatch(directCityKey, targetCity)) {
      return true;
    }
  }

  final pins =
      cityPins ??
      pincodesMap.entries
          .where((entry) => _cityKeysMatch(entry.key, targetCity))
          .expand((entry) => entry.value)
          .map(_normalizePincode)
          .whereType<String>()
          .toSet();

  final userPin = extractUserPincode(user);
  if (userPin != null && pins.contains(userPin)) {
    return true;
  }

  final resolved = resolveUserCityName(user, pincodesMap, pincodeCityLookup);
  if (resolved != null && _cityKeysMatch(resolved, targetCity)) {
    return true;
  }

  final addressCity = extractUserCityFromAddress(user);
  if (addressCity != null && _cityKeysMatch(addressCity, targetCity)) {
    return true;
  }

  final explicitCity = _explicitCityField(user);
  if (explicitCity != null && _cityKeysMatch(explicitCity, targetCity)) {
    return true;
  }

  final address = _addressSource(user);
  if (address.isNotEmpty) {
    final normAddress = address.toLowerCase();
    final targetVariants = _kCityKeyQueryVariants[targetCity] ?? [targetCity];
    if (targetVariants.any(normAddress.contains)) {
      return true;
    }
    for (final segment in _addressSegments(address)) {
      final candidate = _cleanCitySegment(segment);
      if (candidate != null && _cityKeysMatch(candidate, targetCity)) {
        return true;
      }
    }
  }

  return false;
}

bool userMatchesCategory(Map<String, dynamic> user, String category) {
  final userCategories = user['category'];
  if (userCategories == null) return false;
  if (userCategories is String) return userCategories == category;
  if (userCategories is List) return userCategories.contains(category);
  return false;
}

/// Extracts candidate linked `users` document IDs from child records
/// (such as `callLogs`, `service_posts`, `tickets`, `verification`, `orders`).
List<String> extractAssociatedEntityIds(Map<String, dynamic> record) {
  const keys = [
    'businessId',
    'providerId',
    'userId',
    'uid',
    'ownerId',
    'customerId',
  ];
  final ids = <String>[];
  for (final key in keys) {
    final val = record[key]?.toString().trim();
    if (val != null && val.isNotEmpty && !ids.contains(val)) {
      ids.add(val);
    }
  }
  return ids;
}

/// Resolves a record's city from direct city/pincode/address fields OR, if missing,
/// from an associated parent entity in [relatedEntityLookup] (e.g. `users/{businessId}`).
String? resolveRecordCity(
  Map<String, dynamic> record, {
  Map<String, List<String>> pincodesMap = const {},
  Map<String, String>? pincodeCityLookup,
  Map<String, Map<String, dynamic>>? relatedEntityLookup,
}) {
  final explicit = _explicitCityField(record);
  if (explicit != null && explicit.trim().isNotEmpty) {
    return explicit.trim();
  }

  final direct = resolveUserCityName(record, pincodesMap, pincodeCityLookup);
  if (direct != null && direct.trim().isNotEmpty) {
    return direct.trim();
  }

  if (relatedEntityLookup != null && relatedEntityLookup.isNotEmpty) {
    for (final relatedId in extractAssociatedEntityIds(record)) {
      final related = relatedEntityLookup[relatedId];
      if (related != null) {
        final relatedCity = resolveUserCityName(
          related,
          pincodesMap,
          pincodeCityLookup,
        );
        if (relatedCity != null && relatedCity.trim().isNotEmpty) {
          return relatedCity.trim();
        }
      }
    }
  }

  return null;
}

/// Returns true when [record] resolves to a concrete city (not missing/unknown).
bool hasResolvableCity(
  Map<String, dynamic> record, {
  Map<String, List<String>> pincodesMap = const {},
  Map<String, String>? pincodeCityLookup,
  Map<String, Map<String, dynamic>>? relatedEntityLookup,
}) {
  final resolved = resolveRecordCity(
    record,
    pincodesMap: pincodesMap,
    pincodeCityLookup: pincodeCityLookup,
    relatedEntityLookup: relatedEntityLookup,
  );
  return resolved != null && resolved.trim().isNotEmpty;
}

/// Strict centralized scope evaluation.
/// - Fails closed when `!scope.isAuthorized`.
/// - Missing-city records are DENIED for non-Super-Admin (`false`), and allowed for
///   Super Admin (or selectable via [kMissingCityFilterValue]).
bool recordMatchesCityScope(
  Map<String, dynamic> record,
  CityAccessScope scope, {
  String? selectedCity,
  Map<String, List<String>> pincodesMap = const {},
  Map<String, String>? pincodeCityLookup,
  Map<String, Map<String, dynamic>>? relatedEntityLookup,
}) {
  if (!scope.isAuthorized) return false;

  final trimmedSelected = selectedCity?.trim();
  final isAllCities =
      trimmedSelected == null ||
      trimmedSelected.isEmpty ||
      trimmedSelected == 'All' ||
      trimmedSelected == 'All Cities' ||
      trimmedSelected == 'All Assigned Cities';

  if (scope.isSuperAdmin) {
    if (trimmedSelected == kMissingCityFilterValue) {
      return !hasResolvableCity(
        record,
        pincodesMap: pincodesMap,
        pincodeCityLookup: pincodeCityLookup,
        relatedEntityLookup: relatedEntityLookup,
      );
    }
    if (isAllCities) return true;
    return _recordMatchesSingleCity(
      record,
      trimmedSelected,
      pincodesMap: pincodesMap,
      pincodeCityLookup: pincodeCityLookup,
      relatedEntityLookup: relatedEntityLookup,
    );
  }

  if (scope.assignedCities.isEmpty) {
    return false;
  }

  if (!isAllCities) {
    if (trimmedSelected == kMissingCityFilterValue) {
      return false;
    }
    if (!scope.canAccessCityName(trimmedSelected)) {
      return false;
    }
    return _recordMatchesSingleCity(
      record,
      trimmedSelected,
      pincodesMap: pincodesMap,
      pincodeCityLookup: pincodeCityLookup,
      relatedEntityLookup: relatedEntityLookup,
    );
  }

  for (final city in scope.assignedCities) {
    if (_recordMatchesSingleCity(
      record,
      city,
      pincodesMap: pincodesMap,
      pincodeCityLookup: pincodeCityLookup,
      relatedEntityLookup: relatedEntityLookup,
    )) {
      return true;
    }
  }
  return false;
}

bool _recordMatchesSingleCity(
  Map<String, dynamic> record,
  String targetCity, {
  Map<String, List<String>> pincodesMap = const {},
  Map<String, String>? pincodeCityLookup,
  Map<String, Map<String, dynamic>>? relatedEntityLookup,
}) {
  if (userMatchesCity(record, targetCity, pincodesMap, pincodeCityLookup)) {
    return true;
  }
  if (relatedEntityLookup != null && relatedEntityLookup.isNotEmpty) {
    for (final relatedId in extractAssociatedEntityIds(record)) {
      final related = relatedEntityLookup[relatedId];
      if (related != null &&
          userMatchesCity(related, targetCity, pincodesMap, pincodeCityLookup)) {
        return true;
      }
    }
  }
  return false;
}

/// Evaluates if a user/document matches assigned cities for admins, or an explicitly selected city.
/// Fails closed when `!isSuperAdmin && assignedCities.isEmpty`.
bool userMatchesAssignedCities(
  Map<String, dynamic> user,
  String? selectedCity,
  List<String> assignedCities,
  Map<String, List<String>> pincodesMap,
  Map<String, String>? pincodeCityLookup, {
  bool isSuperAdmin = false,
}) {
  final scope = CityAccessScope(
    status:
        (isSuperAdmin || assignedCities.isNotEmpty)
            ? AdminAccessStatus.authorized
            : AdminAccessStatus.noCitiesAssigned,
    isSuperAdmin: isSuperAdmin,
    isActive: true,
    assignedCities: assignedCities,
    normalizedCityKeys: expandQueryableCityKeys(assignedCities),
  );
  return recordMatchesCityScope(
    user,
    scope,
    selectedCity: selectedCity,
    pincodesMap: pincodesMap,
    pincodeCityLookup: pincodeCityLookup,
  );
}

