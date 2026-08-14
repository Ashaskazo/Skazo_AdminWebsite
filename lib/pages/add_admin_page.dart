import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:skazo_admin/providers/collections_provider.dart';

class AddAdminPage extends ConsumerStatefulWidget {
  const AddAdminPage({super.key});

  @override
  ConsumerState<AddAdminPage> createState() => _AddAdminPageState();
}

class _AddAdminPageState extends ConsumerState<AddAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'admin';
  bool _isActive = true;
  final List<String> _selectedCities = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a name';
    }
    return null;
  }

  Future<void> _createAdminAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();

      // 1. Check if admin already exists in the Firestore 'admin' collection
      final existingAdmin = await FirebaseFirestore.instance
          .collection('admin')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingAdmin.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An admin account with this email already exists'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2. Attempt Firebase Auth user creation using secondary app
      FirebaseApp? secondaryApp;
      String? createdUid;

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
          final userCredential = await tempAuth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          createdUid = userCredential.user?.uid;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            debugPrint('Auth user already exists for $email, granting admin status in Firestore.');
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
        'role': _selectedRole,
        'level': _selectedRole == 'super_admin' ? 'administrator' : 'staff',
        'admin_id': adminId,
        'isActive': _isActive,
        'assignedCities': _selectedRole == 'super_admin' ? [] : _selectedCities,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (createdUid != null) {
        newAdminData['uid'] = createdUid;
      }

      await FirebaseFirestore.instance.collection('admin').add(newAdminData);

      // Invalidate cached admins provider
      ref.invalidate(adminsListProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear the form
      _nameController.clear();
      _emailController.clear();
      _passwordController.clear();
      setState(() {
        _selectedCities.clear();
        _selectedRole = 'admin';
        _isActive = true;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String errorMessage = 'Failed to create admin account';

      if (e.code == 'weak-password') {
        errorMessage = 'The password provided is too weak';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'The email address is not valid';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final systemCitiesAsync = ref.watch(userFilterCitiesProvider);
    final systemCities = systemCitiesAsync.value ?? ['Vijayawada', 'Hyderabad', 'Guntur', 'Bangalore', 'Bheemavaram', 'Tirupathi'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Admin User'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Create New Admin',
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: _validateName,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _selectedRole,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shield),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'admin', child: Text('Sales / Staff Admin')),
                            DropdownMenuItem(value: 'super_admin', child: Text('Super Admin (Unrestricted)')),
                          ],
                          onChanged: _isLoading ? null : (v) => setState(() => _selectedRole = v!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: _validatePassword,
                          enabled: !_isLoading,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Account Active:', style: TextStyle(fontWeight: FontWeight.w500)),
                            Switch(
                              value: _isActive,
                              onChanged: _isLoading ? null : (v) => setState(() => _isActive = v),
                            ),
                          ],
                        ),
                        if (_selectedRole != 'super_admin') ...[
                          const SizedBox(height: 16),
                          const Text('Assign Cities:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: systemCities.map((city) {
                              final isSelected = _selectedCities.contains(city);
                              return FilterChip(
                                label: Text(city),
                                selected: isSelected,
                                onSelected: _isLoading ? null : (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedCities.add(city);
                                    } else {
                                      _selectedCities.remove(city);
                                    }
                                  });
                                },
                                selectedColor: const Color(0xFF2563EB).withValues(alpha: 0.15),
                                checkmarkColor: const Color(0xFF2563EB),
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _createAdminAccount,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child:
                              _isLoading
                                  ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Text('Creating admin account...'),
                                    ],
                                  )
                                  : const Text('Create Admin Account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

