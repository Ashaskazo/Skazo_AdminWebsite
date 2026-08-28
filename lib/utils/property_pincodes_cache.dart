import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const _firestoreTimeout = Duration(seconds: 45);
const _propertyPincodesCollectionCandidates = ['Property_Pincodes'];

Map<String, List<String>>? _propertyPincodesCache;
Future<Map<String, List<String>>>? _propertyPincodesInFlight;

String _normalizePincodeCityName(String city) => city.trim().toLowerCase();

Set<String> _extractNormalizedPincodes(dynamic value) {
  final pins = <String>{};

  if (value == null) {
    return pins;
  }

  if (value is List) {
    for (final item in value) {
      pins.addAll(_extractNormalizedPincodes(item));
    }
    return pins;
  }

  if (value is Map) {
    for (final item in value.values) {
      pins.addAll(_extractNormalizedPincodes(item));
    }
    return pins;
  }

  final source = value.toString();
  for (final match in RegExp(r'\b\d{6}\b').allMatches(source)) {
    final normalized = match.group(0);
    if (normalized != null) {
      pins.add(normalized);
    }
  }
  return pins;
}

List<String> _extractDeclaredCities(Map<String, dynamic> data) {
  final rawCities = data['cities'];
  if (rawCities is! List) {
    return const [];
  }

  return rawCities
      .map((value) => value?.toString().trim() ?? '')
      .where((value) => value.isNotEmpty)
      .toList();
}

void _registerPincodeCity(
  Map<String, String> canonicalNames,
  Map<String, Set<String>> pinsByCity,
  String cityName, [
  Iterable<String> pins = const [],
]) {
  final trimmed = cityName.trim();
  if (trimmed.isEmpty) {
    return;
  }

  final normalized = _normalizePincodeCityName(trimmed);
  canonicalNames.putIfAbsent(normalized, () => trimmed);
  pinsByCity.putIfAbsent(normalized, () => <String>{}).addAll(pins);
}

Future<Map<String, List<String>>> _loadPropertyPincodesFromFirestore() async {
  try {
    QuerySnapshot<Map<String, dynamic>>? fallbackSnapshot;
    final snapshot =
        await (() async {
          for (final collectionName in _propertyPincodesCollectionCandidates) {
            final currentSnapshot = await FirebaseFirestore.instance
                .collection(collectionName)
                .get()
                .timeout(_firestoreTimeout);
            fallbackSnapshot ??= currentSnapshot;
            if (currentSnapshot.docs.isNotEmpty) {
              return currentSnapshot;
            }
          }
          return fallbackSnapshot!;
        })();

    final canonicalNames = <String, String>{};
    final pinsByCity = <String, Set<String>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final declaredCities = _extractDeclaredCities(data);
      final isCitiesCatalogDoc =
          _normalizePincodeCityName(doc.id) == 'cities' &&
          declaredCities.isNotEmpty;

      for (final city in declaredCities) {
        _registerPincodeCity(canonicalNames, pinsByCity, city);
      }

      if (isCitiesCatalogDoc) {
        continue;
      }

      final cityName =
          (data['displayName'] ?? data['city'] ?? data['cityName'] ?? data['name'] ?? doc.id)
              .toString()
              .trim();
      final pins = _extractNormalizedPincodes(
        data['pincodes'] ?? data['pincode'] ?? data['pins'],
      );

      if (cityName.isEmpty) {
        continue;
      }

      _registerPincodeCity(canonicalNames, pinsByCity, cityName, pins);
    }

    final result = <String, List<String>>{};
    for (final entry in canonicalNames.entries) {
      final cityName = entry.value;
      final pins = (pinsByCity[entry.key] ?? <String>{}).toList()..sort();
      result[cityName] = pins;
    }

    _propertyPincodesCache = result;
    return result;
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Error fetching property pincodes: $e');
    }
    return _propertyPincodesCache ?? {};
  }
}

Future<Map<String, List<String>>> loadPropertyPincodes({
  bool forceRefresh = false,
}) async {
  if (forceRefresh) {
    clearPropertyPincodesCache();
  }

  final cached = _propertyPincodesCache;
  if (cached != null) {
    return cached;
  }

  final inFlight = _propertyPincodesInFlight;
  if (inFlight != null) {
    return inFlight;
  }

  final future = _loadPropertyPincodesFromFirestore();
  _propertyPincodesInFlight = future;

  try {
    return await future;
  } finally {
    if (identical(_propertyPincodesInFlight, future)) {
      _propertyPincodesInFlight = null;
    }
  }
}

void clearPropertyPincodesCache() {
  _propertyPincodesCache = null;
  _propertyPincodesInFlight = null;
}
