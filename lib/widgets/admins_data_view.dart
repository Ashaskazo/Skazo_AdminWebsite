import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';

class AdminsDataView extends ConsumerWidget {
  const AdminsDataView({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final adminsAsync = ref.watch(adminsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Admin Management',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage administrative access and roles.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (isSuperAdmin)
                ElevatedButton.icon(
                  onPressed: () => _showAddAdminDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Sales Admin'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Admins List
        Expanded(
          child: adminsAsync.when(
            data: (snapshot) {
              final docs = snapshot.docs;
              if (docs.isEmpty) return const Center(child: Text('No admins found'));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  final email = data['email'] ?? 'No email';
                  final name = data['name'] ?? 'No name';
                  final role = data['role'] ?? data['level'] ?? 'admin';
                  final isCurrentSuperAdmin = role == 'super_admin' || role == 'administrator';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: isCurrentSuperAdmin ? const Color(0xFF2563EB).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                        child: Icon(
                          isCurrentSuperAdmin ? Icons.shield : Icons.person,
                          color: isCurrentSuperAdmin ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                        ),
                      ),
                      title: Text(
                        name,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            email,
                            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                          if (data['admin_id'] != null)
                            Text(
                              'ID: ${data['admin_id']}',
                              style: GoogleFonts.poppins(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2563EB),
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCurrentSuperAdmin ? const Color(0xFF2563EB).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCurrentSuperAdmin ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          if (isSuperAdmin) ...[
                            IconButton(
                              onPressed: () async {
                                try {
                                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Password reset email sent to $email.'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to send reset email: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.lock_reset, color: Color(0xFF2563EB), size: 20),
                              tooltip: 'Send Password Reset Email',
                            ),
                          ],
                          if (isSuperAdmin && role != 'super_admin') ...[
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => _deleteAdmin(context, ref, id, name),
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              tooltip: 'Remove Admin',
                            ),
                          ],
                        ],
                      ),
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

  Future<void> _showAddAdminDialog(BuildContext context, WidgetRef ref) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'admin';
    bool isCreating = false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add New Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'admin@example.com',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: const [
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  DropdownMenuItem(value: 'super_admin', child: Text('Super Admin')),
                ],
                onChanged: (v) => setState(() => selectedRole = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter login password',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              if (isCreating) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text('Creating authentication account...', style: GoogleFonts.poppins(fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isCreating ? null : () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim().toLowerCase();
                final password = passwordController.text.trim();

                if (name.isEmpty || email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }
                
                setState(() => isCreating = true);

                try {
                  // 1. Check if admin already exists in the Firestore 'admin' collection
                  final existingAdminDoc = await FirebaseFirestore.instance
                      .collection('admin')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();

                  if (existingAdminDoc.docs.isNotEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('An admin account with this email already exists in Admin Management.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }

                  // 2. Attempt Firebase Auth user creation using a secondary FirebaseApp instance
                  // This prevents the current super admin from being logged out
                  FirebaseApp? secondaryApp;
                  String? createdUid;
                  bool isExistingAuthUser = false;

                  try {
                    try {
                      secondaryApp = Firebase.app('AdminCreationApp');
                    } catch (_) {
                      secondaryApp = await Firebase.initializeApp(
                        name: 'AdminCreationApp',
                        options: Firebase.app().options,
                      );
                    }

                    final tempAuth = FirebaseAuth.instanceFor(app: secondaryApp);
                    try {
                      final userCred = await tempAuth.createUserWithEmailAndPassword(
                        email: email,
                        password: password,
                      );
                      createdUid = userCred.user?.uid;
                    } on FirebaseAuthException catch (authErr) {
                      if (authErr.code == 'email-already-in-use') {
                        isExistingAuthUser = true;
                        debugPrint('Auth account already exists for $email, proceeding to add admin document.');
                      } else {
                        rethrow;
                      }
                    }
                  } finally {
                    await secondaryApp?.delete();
                  }

                  // 3. Add to Firestore admin collection
                  final countSnapshot = await FirebaseFirestore.instance.collection('admin').count().get();
                  final count = countSnapshot.count ?? 0;
                  final adminId = 'ADM${(count + 1).toString().padLeft(3, '0')}';

                  final newAdminData = <String, dynamic>{
                    'name': name,
                    'email': email,
                    'role': selectedRole,
                    'level': selectedRole == 'super_admin' ? 'administrator' : 'staff',
                    'admin_id': adminId,
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  if (createdUid != null) {
                    newAdminData['uid'] = createdUid;
                  }

                  await FirebaseFirestore.instance.collection('admin').add(newAdminData);

                  // Invalidate non-stream cached admins provider
                  ref.invalidate(adminsListProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                    final successMessage = isExistingAuthUser
                        ? 'Admin added! (Note: Email already existed in Firebase Auth — existing password preserved. Click "Forgot Password" to reset if needed.)'
                        : 'Admin account added successfully!';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(successMessage),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    String errorMsg = 'Failed to create admin account: $e';
                    if (e is FirebaseAuthException) {
                      if (e.code == 'weak-password') {
                        errorMsg = 'The password provided is too weak.';
                      } else if (e.code == 'invalid-email') {
                        errorMsg = 'The email address is invalid.';
                      }
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (context.mounted) setState(() => isCreating = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isCreating ? 'Creating...' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteAdmin(BuildContext context, WidgetRef ref, String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Admin'),
        content: Text('Are you sure you want to remove $name as an administrator?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('admin').doc(id).delete();
      ref.invalidate(adminsListProvider);
    }
  }
}
