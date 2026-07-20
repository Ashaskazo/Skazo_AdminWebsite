import 'package:cloud_firestore/cloud_firestore.dart';

/// A single page of Firestore query results with cursor metadata.
class PageResult<T> {
  final List<T> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PageResult({
    required this.items,
    this.lastDocument,
    required this.hasMore,
  });

  static PageResult<T> empty<T>() => PageResult<T>(items: const [], hasMore: false);
}
