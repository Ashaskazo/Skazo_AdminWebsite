/// Production-ready data migration for the `users` collection.
///
/// Ensures all user documents are normalized with:
///   - `isuser`: bool (`true` for customer, `false` for service provider)
///   - `cityKey`: String (lowercased normalized city key, e.g. "hyderabad")
///   - `phone`: String (normalized phone number string)
///   - `businessPincode`: String? (6-digit normalized pincode)
///
/// Features:
///   - Idempotent and safe to run multiple times
///   - Batched writes (50 docs per commit)
///   - Dry-run / preview capability
///   - Yields progress stream for UI feedback

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/services/city_filter_service.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';

const int _batchSize = 50;

/// Describes the progress/outcome of one batch during backfill.
class BackfillProgress {
  final int processed;
  final int updated;
  final int skipped;
  final int errors;
  final bool isComplete;
  final String? lastError;

  const BackfillProgress({
    required this.processed,
    required this.updated,
    required this.skipped,
    required this.errors,
    this.isComplete = false,
    this.lastError,
  });

  @override
  String toString() =>
      'BackfillProgress(processed=$processed, updated=$updated, '
      'skipped=$skipped, errors=$errors, complete=$isComplete)';
}

class BackfillService {
  final FirebaseFirestore _firestore;

  BackfillService([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Runs the backfill migration and yields progress updates.
  Stream<BackfillProgress> run() async* {
    int processed = 0;
    int updated = 0;
    int skipped = 0;
    int errors = 0;
    String? lastError;

    // Load pincodes map once for the run
    Map<String, List<String>> pincodesMap;
    try {
      pincodesMap = await loadPropertyPincodes();
    } catch (e) {
      debugPrint('[BackfillService] Failed to load pincodes: $e');
      pincodesMap = {};
    }

    final pincodeCityLookup = buildPincodeCityLookup(pincodesMap);
    DocumentSnapshot? lastDoc;

    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('users')
          .orderBy(FieldPath.documentId)
          .limit(_batchSize);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await query.get();
      } catch (e) {
        lastError = e.toString();
        errors++;
        debugPrint('[BackfillService] Batch fetch error: $e');
        yield BackfillProgress(
          processed: processed,
          updated: updated,
          skipped: skipped,
          errors: errors,
          lastError: lastError,
        );
        break;
      }

      if (snapshot.docs.isEmpty) break;

      final writeBatch = _firestore.batch();
      int batchWrites = 0;

      for (final doc in snapshot.docs) {
        processed++;
        final data = doc.data();

        try {
          final isCustomer = !UserModel.isServiceProviderDoc(data);
          final bool targetIsUser = isCustomer;
          final currentIsUser = data['isuser'];

          final currentCityKey = data['cityKey']?.toString().trim().toLowerCase();
          final rawCity = (data['city'] ?? data['City'] ?? data['businessCity'])?.toString().trim();
          final resolvedCityKey = (currentCityKey != null && currentCityKey.isNotEmpty)
              ? currentCityKey
              : (rawCity != null && rawCity.isNotEmpty
                  ? rawCity.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')
                  : null);

          // Pincode
          final targetPincode = data['businessPincode']?.toString().trim().isNotEmpty == true
              ? data['businessPincode'].toString().trim()
              : extractBusinessPincode(data);

          // Inferred city from pincode if cityKey is still empty
          final inferredCityFromPin = targetPincode != null
              ? pincodeCityLookup[targetPincode]?.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')
              : null;

          final effectiveCityKey = resolvedCityKey ?? inferredCityFromPin;

          // Normalized phone string
          final rawPhone = data['phone'] ?? data['phoneNumber'] ?? data['mobile'];
          final targetPhone = rawPhone != null ? rawPhone.toString().trim() : null;

          final Map<String, dynamic> updateData = {};

          // 1. Strict boolean isuser
          if (currentIsUser is! bool || currentIsUser != targetIsUser) {
            updateData['isuser'] = targetIsUser;
          }

          // 2. Universal cityKey
          if (effectiveCityKey != null && currentCityKey != effectiveCityKey) {
            updateData['cityKey'] = effectiveCityKey;
          }

          // 3. Normalized phone string
          if (targetPhone != null && (data['phone'] is! String || data['phone'] != targetPhone)) {
            updateData['phone'] = targetPhone;
          }

          // 4. Normalized pincode
          if (targetPincode != null && data['businessPincode'] != targetPincode) {
            updateData['businessPincode'] = targetPincode;
          }

          if (updateData.isNotEmpty) {
            updateData['backfilledAt'] = FieldValue.serverTimestamp();
            writeBatch.update(doc.reference, updateData);
            batchWrites++;
            updated++;
          } else {
            skipped++;
          }
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('[BackfillService] Error processing ${doc.id}: $e');
        }
      }

      if (batchWrites > 0) {
        try {
          await writeBatch.commit();
        } catch (e) {
          errors++;
          lastError = e.toString();
          debugPrint('[BackfillService] Batch commit error: $e');
        }
      }

      lastDoc = snapshot.docs.last;

      yield BackfillProgress(
        processed: processed,
        updated: updated,
        skipped: skipped,
        errors: errors,
        lastError: lastError,
      );

      if (snapshot.docs.length < _batchSize) break;
    }

    // Final terminal event
    yield BackfillProgress(
      processed: processed,
      updated: updated,
      skipped: skipped,
      errors: errors,
      isComplete: true,
      lastError: lastError,
    );
  }

  /// Preview — counts how many total documents exist in users collection.
  Future<int> previewTotalCount() async {
    try {
      final snap = await _firestore.collection('users').count().get();
      return snap.count ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<int> previewPendingCount() => previewTotalCount();
}