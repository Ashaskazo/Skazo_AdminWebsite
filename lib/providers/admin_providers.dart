import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that checks if a user's email is in the admins collection
final isAuthorizedAdminProvider = FutureProvider.family<bool, String>((ref, email) async {
  try {
    // Check the admin collection for the email
    final snapshot = await FirebaseFirestore.instance
        .collection('admin')
        .where('email', isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();

    // If document exists with matching email, user is authorized
    return snapshot.docs.isNotEmpty;
  } catch (e) {
    // Log error and return false for safety
    print('Error checking admin status: $e');
    return false;
  }
});

/// Provider to get the current admin status
final currentAdminStatusProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;

  // If no user is logged in, they are not an admin
  if (user == null) {
    return false;
  }

  // Check if the current user's email is in the admins collection
  final isAuthorized = await ref.watch(isAuthorizedAdminProvider(user.email ?? '').future);
  return isAuthorized;
});

/// Provider to handle logging out
class AdminAuthNotifier extends StateNotifier<bool> {
  AdminAuthNotifier() : super(false);

  Future<void> signOut() async {
    state = true; // Processing
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    } finally {
      state = false; // Reset state
    }
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, bool>((ref) {
  return AdminAuthNotifier();
});
