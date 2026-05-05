import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Generic provider for fetching data from any Firestore collection
final collectionDataProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, collectionName) async {
  final snapshot = await FirebaseFirestore.instance
      .collection(collectionName)
      .orderBy('timestamp', descending: true)
      .limit(50)
      .get()
      .catchError((e) async {
    // If 'timestamp' field doesn't exist, try without ordering
    return await FirebaseFirestore.instance
        .collection(collectionName)
        .limit(50)
        .get();
  });

  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
});

// Generic provider for fetching the count of documents in any collection
final collectionCountProvider = FutureProvider.family<int, String>((ref, collectionName) async {
  final snapshot = await FirebaseFirestore.instance.collection(collectionName).count().get();
  return snapshot.count ?? 0;
});
