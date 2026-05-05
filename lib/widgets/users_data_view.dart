import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';

class UsersDataView extends ConsumerWidget {
  const UsersDataView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(collectionDataProvider('users'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Area
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Verify and manage business/service providers.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed:
                    () => ref.invalidate(collectionDataProvider('users')),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Data List
        Expanded(
          child: dataAsync.when(
            data: (users) {
              if (users.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final bool isVerified = user['isverified'] ?? false;
                  final bool isUser = user['isuser'] ?? false;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Profile Pic
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child:
                                user['businesspic'] != null
                                    ? Image.network(
                                      user['businesspic'],
                                      fit: BoxFit.cover,
                                    )
                                    : const Icon(
                                      Icons.business,
                                      color: Color(0xFF64748B),
                                    ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    user['businessname'] ??
                                        user['name'] ??
                                        'Unknown User',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (isVerified)
                                    const Icon(
                                      Icons.verified,
                                      color: Colors.blue,
                                      size: 16,
                                    )
                                  else if (!isUser)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Unverified',
                                        style: TextStyle(
                                          color: Colors.orange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                user['email'] ?? 'No email available',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Actions
                        Row(
                          children: [
                            if (!isVerified && !isUser)
                              TextButton.icon(
                                onPressed:
                                    () => _verifyUser(context, ref, user['id']),
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  size: 18,
                                ),
                                label: const Text('Verify'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green,
                                ),
                              ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => BusinessProfilePage(
                                          businessData: user,
                                        ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.visibility_outlined,
                                size: 20,
                                color: Color(0xFF64748B),
                              ),
                              tooltip: 'View Profile',
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No users found'),
        ],
      ),
    );
  }

  Future<void> _verifyUser(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final success = await ref
        .read(userVerificationProvider.notifier)
        .verifyUser(userId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'User verified successfully' : 'Verification failed',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
      if (success) {
        ref.invalidate(collectionDataProvider('users'));
      }
    }
  }
}
