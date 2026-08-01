// Shared city parsing and matching for User Management and dashboard filters.

String _normalizeCityKey(String city) =>
    city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _addressSource(Map<String, dynamic> user) {
  final addr = user['businessAddress'] ??
      user['businessaddress'] ??
      user['customerAddress'] ??
      user['address'] ??
      user['business_address'] ??
      user['customer_address'] ??
      '';
  return addr.toString().trim();
}

String? _explicitCityField(Map<String, dynamic> user) {
  final raw = (user['City'] ??
          user['city'] ??
          user['businessCity'] ??
          user['customerCity'] ??
          user['business_city'] ??
          user['customer_city'])
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
    final normalized = _normalizeCityKey(addressCity);
    for (final known in pincodesMap.keys) {
      if (_normalizeCityKey(known) == normalized) return known;
      if (normalized.contains(_normalizeCityKey(known)) ||
          _normalizeCityKey(known).contains(normalized)) {
        return known;
      }
    }
  }

  return addressCity;
}

bool userMatchesCity(
  Map<String, dynamic> user,
  String selectedCity,
  Map<String, List<String>> pincodesMap,
  Map<String, String>? pincodeCityLookup, {
  String? normalizedTargetCity,
  Set<String>? cityPins,
}) {
  final targetCity = normalizedTargetCity ?? _normalizeCityKey(selectedCity);
  if (targetCity.isEmpty) return true;

  final directCityKey = (user['cityKey'] ?? user['city'] ?? user['businessCity'] ?? user['customerCity'])?.toString().trim();

  if (directCityKey != null && directCityKey.isNotEmpty) {
    final normDirect = _normalizeCityKey(directCityKey);
    if (normDirect == targetCity || normDirect.contains(targetCity) || targetCity.contains(normDirect)) {
      return true;
    }
  }

  final pins =
      cityPins ??
      pincodesMap.entries
          .where((entry) {
            final k = _normalizeCityKey(entry.key);
            return k == targetCity || k.contains(targetCity) || targetCity.contains(k);
          })
          .expand((entry) => entry.value)
          .map(_normalizePincode)
          .whereType<String>()
          .toSet();

  final userPin = extractUserPincode(user);
  if (userPin != null && pins.contains(userPin)) {
    return true;
  }

  final resolved = resolveUserCityName(user, pincodesMap, pincodeCityLookup);
  if (resolved != null) {
    final normResolved = _normalizeCityKey(resolved);
    if (normResolved == targetCity || normResolved.contains(targetCity) || targetCity.contains(normResolved)) {
      return true;
    }
  }

  final addressCity = extractUserCityFromAddress(user);
  if (addressCity != null) {
    final normAddrCity = _normalizeCityKey(addressCity);
    if (normAddrCity == targetCity || normAddrCity.contains(targetCity) || targetCity.contains(normAddrCity)) {
      return true;
    }
  }

  final explicitCity = _explicitCityField(user);
  if (explicitCity != null) {
    final normExpCity = _normalizeCityKey(explicitCity);
    if (normExpCity == targetCity || normExpCity.contains(targetCity) || targetCity.contains(normExpCity)) {
      return true;
    }
  }

  final address = _addressSource(user);
  if (address.isNotEmpty) {
    final normAddress = address.toLowerCase();
    if (normAddress.contains(targetCity)) {
      return true;
    }
    for (final segment in _addressSegments(address)) {
      final candidate = _cleanCitySegment(segment);
      if (candidate != null) {
        final normCand = _normalizeCityKey(candidate);
        if (normCand == targetCity || normCand.contains(targetCity) || targetCity.contains(normCand)) {
          return true;
        }
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
