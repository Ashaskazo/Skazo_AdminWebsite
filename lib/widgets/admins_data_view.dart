import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/services/backfill_service.dart';

class AdminsDataView extends ConsumerWidget {
  const AdminsDataView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final adminsAsync = ref.watch(adminsStreamProvider);
    final systemCitiesAsync = ref.watch(userFilterCitiesProvider);

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
                    'Manage administrative access, assigned cities, and active statuses.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              if (isSuperAdmin)
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showBackfillDialog(context, ref),
                      icon: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFD97706)),
                      label: const Text(
                        'Run City Migration',
                        style: TextStyle(
                          color: Color(0xFFD97706),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFD97706), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        final systemCities = systemCitiesAsync.value ?? ['Vijayawada', 'Hyderabad', 'Guntur', 'Bangalore', 'Bheemavaram', 'Tirupathi'];
                        _showAddAdminDialog(context, ref, systemCities);
                      },
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
                  final role = (data['role'] ?? data['level'] ?? 'admin').toString();
                  final isCurrentSuperAdmin = role.toLowerCase() == 'super_admin' || role.toLowerCase() == 'administrator';
                  final isActive = data['isActive'] != false && data['status'] != 'inactive';

                  // Extract assigned cities
                  List<String> assignedCities = [];
                  final rawCities = data['assignedCities'] ?? data['assigned_cities'];
                  if (rawCities is List) {
                    assignedCities = rawCities.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
                  } else if (data['assignedCity'] != null && data['assignedCity'].toString().trim().isNotEmpty) {
                    assignedCities = [data['assignedCity'].toString().trim()];
                  } else if (data['city'] != null && data['city'].toString().trim().isNotEmpty) {
                    assignedCities = [data['city'].toString().trim()];
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isActive ? const Color(0xFFF1F5F9) : Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isCurrentSuperAdmin
                                ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                                : (isActive ? const Color(0xFFF1F5F9) : Colors.red.withValues(alpha: 0.1)),
                            child: Icon(
                              isCurrentSuperAdmin ? Icons.shield : Icons.person,
                              color: isCurrentSuperAdmin
                                  ? const Color(0xFF2563EB)
                                  : (isActive ? const Color(0xFF64748B) : Colors.red),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status Chip
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isActive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isActive ? 'Active' : 'Inactive',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isActive ? Colors.green[700] : Colors.red[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
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
                                const SizedBox(height: 8),
                                // Assigned Cities Badges
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: isCurrentSuperAdmin
                                      ? [
                                          Chip(
                                            avatar: const Icon(Icons.star, size: 12, color: Color(0xFF2563EB)),
                                            label: Text(
                                              'All Cities (Super Admin)',
                                              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF2563EB)),
                                            ),
                                            backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.08),
                                            visualDensity: VisualDensity.compact,
                                            padding: EdgeInsets.zero,
                                          ),
                                        ]
                                      : (assignedCities.isEmpty
                                          ? [
                                              Chip(
                                                avatar: const Icon(Icons.location_off, size: 12, color: Colors.orange),
                                                label: Text(
                                                  'No Cities Assigned',
                                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.orange[800]),
                                                ),
                                                backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                                visualDensity: VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                              ),
                                            ]
                                          : assignedCities
                                              .map(
                                                (c) => Chip(
                                                  avatar: const Icon(Icons.location_city, size: 12, color: Color(0xFF0284C7)),
                                                  label: Text(
                                                    c,
                                                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF0369A1)),
                                                  ),
                                                  backgroundColor: const Color(0xFFE0F2FE),
                                                  visualDensity: VisualDensity.compact,
                                                  padding: EdgeInsets.zero,
                                                ),
                                              )
                                              .toList()),
                                ),
                              ],
                            ),
                          ),
                          Row(
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
                                const SizedBox(width: 8),
                                // Edit Admin Button
                                IconButton(
                                  onPressed: () {
                                    final systemCities = systemCitiesAsync.value ?? ['Vijayawada', 'Hyderabad', 'Guntur', 'Bangalore', 'Bheemavaram', 'Tirupathi'];
                                    _showEditAdminDialog(context, ref, id, data, systemCities);
                                  },
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 20),
                                  tooltip: 'Edit Admin & Assigned Cities',
                                ),
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
                                  icon: const Icon(Icons.lock_reset, color: Color(0xFF475569), size: 20),
                                  tooltip: 'Send Password Reset Email',
                                ),
                              ],
                              if (isSuperAdmin && !isCurrentSuperAdmin) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  onPressed: () => _deleteAdmin(context, ref, id, name),
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                  tooltip: 'Remove Admin',
                                ),
                              ],
                            ],
                          ),
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

  Future<void> _showAddAdminDialog(BuildContext context, WidgetRef ref, List<String> availableCities) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'admin';
    bool isActive = true;
    List<String> selectedCities = [];
    bool isCreating = false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Add New Admin', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'John Doe',
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
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Sales / Staff Admin')),
                    DropdownMenuItem(value: 'super_admin', child: Text('Super Admin (Unrestricted)')),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Account Status:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setState(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
                if (selectedRole != 'super_admin') ...[
                  const SizedBox(height: 16),
                  Text('Assign Cities:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: availableCities.map((city) {
                      final isSelected = selectedCities.contains(city);
                      return FilterChip(
                        label: Text(city),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedCities.add(city);
                            } else {
                              selectedCities.remove(city);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (isCreating) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text('Creating admin account...', style: GoogleFonts.poppins(fontSize: 12)),
                ],
              ],
            ),
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
                  // 1. Check if admin document already exists in Firestore
                  final existingAdminDoc = await FirebaseFirestore.instance
                      .collection('admin')
                      .where('email', isEqualTo: email)
                      .limit(1)
                      .get();

                  if (existingAdminDoc.docs.isNotEmpty) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('An admin account with this email already exists.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                    return;
                  }

                  // 2. Attempt Firebase Auth user creation using a secondary FirebaseApp instance
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
                    'isActive': isActive,
                    'assignedCities': selectedRole == 'super_admin' ? [] : selectedCities,
                    'createdAt': FieldValue.serverTimestamp(),
                  };
                  if (createdUid != null) {
                    newAdminData['uid'] = createdUid;
                  }

                  await FirebaseFirestore.instance.collection('admin').add(newAdminData);

                  ref.invalidate(adminsListProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                    final successMessage = isExistingAuthUser
                        ? 'Admin created successfully! (Existing Firebase Auth password preserved)'
                        : 'Admin account added successfully!';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(successMessage),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating admin: $e'), backgroundColor: Colors.red),
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
              child: Text(isCreating ? 'Creating...' : 'Add Admin'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditAdminDialog(
    BuildContext context,
    WidgetRef ref,
    String docId,
    Map<String, dynamic> data,
    List<String> availableCities,
  ) async {
    final nameController = TextEditingController(text: data['name'] ?? '');
    String selectedRole = (data['role'] ?? data['level'] ?? 'admin').toString();
    if (selectedRole.toLowerCase() == 'administrator') selectedRole = 'super_admin';
    bool isActive = data['isActive'] != false && data['status'] != 'inactive';

    // Parse existing assigned cities
    List<String> selectedCities = [];
    final rawCities = data['assignedCities'] ?? data['assigned_cities'];
    if (rawCities is List) {
      selectedCities = rawCities.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (data['assignedCity'] != null && data['assignedCity'].toString().trim().isNotEmpty) {
      selectedCities = [data['assignedCity'].toString().trim()];
    }

    bool isSaving = false;

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Edit Admin Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: ${data['email']}', style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'admin', child: Text('Sales / Staff Admin')),
                    DropdownMenuItem(value: 'super_admin', child: Text('Super Admin (Unrestricted)')),
                  ],
                  onChanged: (v) => setState(() => selectedRole = v!),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Account Status:', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    Row(
                      children: [
                        Text(isActive ? 'Active' : 'Inactive', style: TextStyle(color: isActive ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        Switch(
                          value: isActive,
                          onChanged: (v) => setState(() => isActive = v),
                        ),
                      ],
                    ),
                  ],
                ),
                if (selectedRole != 'super_admin') ...[
                  const SizedBox(height: 16),
                  Text('Assign Cities:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: availableCities.map((city) {
                      final isSelected = selectedCities.contains(city);
                      return FilterChip(
                        label: Text(city),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              selectedCities.add(city);
                            } else {
                              selectedCities.remove(city);
                            }
                          });
                        },
                        selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (isSaving) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name cannot be empty')),
                  );
                  return;
                }

                setState(() => isSaving = true);

                try {
                  final updateData = <String, dynamic>{
                    'name': name,
                    'role': selectedRole,
                    'level': selectedRole == 'super_admin' ? 'administrator' : 'staff',
                    'isActive': isActive,
                    'assignedCities': selectedRole == 'super_admin' ? [] : selectedCities,
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  await FirebaseFirestore.instance.collection('admin').doc(docId).update(updateData);
                  ref.invalidate(adminsListProvider);

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Admin details updated successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating admin: $e'), backgroundColor: Colors.red),
                    );
                  }
                } finally {
                  if (context.mounted) setState(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(isSaving ? 'Saving...' : 'Save Changes'),
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

  Future<void> _showBackfillDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _BackfillDialogContent(),
    );
  }
}

class _BackfillDialogContent extends StatefulWidget {
  const _BackfillDialogContent();

  @override
  State<_BackfillDialogContent> createState() => _BackfillDialogContentState();
}

class _BackfillDialogContentState extends State<_BackfillDialogContent> {
  final BackfillService _service = BackfillService();
  bool _isRunning = false;
  bool _isComplete = false;
  int _processed = 0;
  int _updated = 0;
  int _skipped = 0;
  int _errors = 0;
  String? _lastError;
  int? _pendingEstimate;
  bool _isLoadingPreview = true;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final count = await _service.previewPendingCount();
    if (mounted) {
      setState(() {
        _pendingEstimate = count;
        _isLoadingPreview = false;
      });
    }
  }

  void _startMigration() {
    setState(() {
      _isRunning = true;
      _isComplete = false;
      _processed = 0;
      _updated = 0;
      _skipped = 0;
      _errors = 0;
      _lastError = null;
    });

    _service.run().listen(
      (progress) {
        if (mounted) {
          setState(() {
            _processed = progress.processed;
            _updated = progress.updated;
            _skipped = progress.skipped;
            _errors = progress.errors;
            _lastError = progress.lastError;
            if (progress.isComplete) {
              _isRunning = false;
              _isComplete = true;
            }
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _isRunning = false;
            _lastError = e.toString();
            _errors++;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFD97706).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 12),
          Text(
            'Performance & City Migration',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This one-time migration indexes all users for instant city filtering:',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBullet('1. Classifies users strictly into Customers vs Service Providers (isuser bool)'),
                  const SizedBox(height: 4),
                  _buildBullet('2. Normalizes 6-digit business pincodes & phone strings'),
                  const SizedBox(height: 4),
                  _buildBullet('3. Maps pincodes & address strings to universal cityKey for indexed queries'),
                  const SizedBox(height: 4),
                  _buildBullet('4. Completely eliminates full-collection scans in Dashboard & Users'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingPreview)
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total users in collection:',
                      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1E40AF)),
                    ),
                    Text(
                      '${_pendingEstimate ?? 0}',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1E40AF)),
                    ),
                  ],
                ),
              ),
            if (_isRunning || _isComplete) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _isComplete ? 1.0 : null,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isComplete ? Colors.green : const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Processed', '$_processed', Colors.blue),
                  _buildStatItem('Updated', '$_updated', Colors.green),
                  _buildStatItem('Skipped', '$_skipped', Colors.grey),
                  _buildStatItem('Errors', '$_errors', Colors.red),
                ],
              ),
            ],
            if (_lastError != null) ...[
              const SizedBox(height: 10),
              Text(
                'Error: $_lastError',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (_isComplete) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Migration completed successfully! All future queries will use indexed Firestore lookups.',
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isRunning)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isComplete ? 'Close' : 'Cancel'),
          ),
        if (!_isRunning && !_isComplete)
          ElevatedButton.icon(
            onPressed: _startMigration,
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('Start Migration Now'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
      ],
    );
  }

  Widget _buildBullet(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B))),
      ],
    );
  }
}

