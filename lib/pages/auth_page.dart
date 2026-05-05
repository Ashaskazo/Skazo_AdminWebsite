import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/pages/dashboard_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final bool _isLogin = true;
  bool _isInitialized = false;
  bool _isCheckingAdminStatus = false;

  @override
  void initState() {
    super.initState();
    // Delay Firebase auth check to post-frame callback to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  void _checkAuthState() {
    if (!mounted) return;

    setState(() {
      _isInitialized = true;
    });

    // Check if user is already logged in
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null && mounted) {
        // Check if user is an admin before navigating
        await _checkAdminAccess(user);
      }
    });
  }

  Future<void> _checkAdminAccess(User user) async {
    if (!mounted) return;

    setState(() {
      _isCheckingAdminStatus = true;
    });

    try {
      // Check if the user's email exists in the admin collection
      final snapshot =
          await FirebaseFirestore.instance
              .collection('admin')
              .where('email', isEqualTo: user.email?.toLowerCase().trim())
              .limit(1)
              .get();

      if (!mounted) return;

      // Add this extra safety check to prevent the common "List<object> is not pigeon" error
      if (snapshot.docs.isNotEmpty) {
        // Use a simpler approach that avoids complex data transformations
        // which can trigger the pigeon serialization error
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const DashboardPage()),
        );
      } else {
        // User is not an admin, sign them out and show error
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unauthorized access. Please contact the administrator.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying admin status: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Sign out the user for safety
        await FirebaseAuth.instance.signOut();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingAdminStatus = false;
        });
      }
    }
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    // Email regex pattern
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    if (!_isLogin && value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String _getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email. The admin account may not exist in Firebase Authentication.';
      case 'wrong-password':
        return 'Wrong password provided. Please check your password.';
      case 'invalid-credential':
        return 'The supplied auth credential is incorrect, malformed or has expired. Please verify your email and password.';
      case 'email-already-in-use':
        return 'An account already exists with this email';
      case 'invalid-email':
        return 'Please provide a valid email address';
      case 'user-disabled':
        return 'This account has been disabled. Please contact the administrator.';
      case 'operation-not-allowed':
        return 'Email & Password accounts are not enabled. Please contact the administrator.';
      case 'weak-password':
        return 'Please provide a stronger password';
      case 'invalid-verification-code':
        return 'Invalid verification code';
      case 'invalid-verification-id':
        return 'Invalid verification ID';
      default:
        return '${e.message ?? 'An error occurred'} (Error code: ${e.code})';
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        if (_isLogin) {
          final email = _emailController.text.trim();
          final password = _passwordController.text.trim();

          // Normalize email to lowercase for consistency
          final normalizedEmail = email.toLowerCase();

          debugPrint('Attempting login with email: $normalizedEmail');

          final userCredential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(
                email: normalizedEmail,
                password: password,
              );

          if (mounted) {
            // Wrap the admin access check in a try-catch to handle serialization errors
            try {
              // Check admin status after successful login
              await _checkAdminAccess(userCredential.user!);
            } catch (adminError) {
              debugPrint('Error during admin verification: $adminError');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Error verifying admin status. Please contact support.',
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
                // Sign out on error to prevent being stuck in a bad state
                await FirebaseAuth.instance.signOut();
              }
            }
          }
        } else {
          // Disable sign up functionality
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('New registration is not allowed'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
        // Navigation is handled by _checkAdminAccess
      } on FirebaseAuthException catch (e) {
        debugPrint(
          'FirebaseAuthException: ${e.code} - ${e.message}',
        ); // Debug log
        debugPrint(
          'Attempted login with email: ${_emailController.text.trim()}',
        );

        // Additional diagnostic: Check if admin exists in Firestore for user-not-found errors
        if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
          try {
            final adminCheck =
                await FirebaseFirestore.instance
                    .collection('admin')
                    .where(
                      'email',
                      isEqualTo: _emailController.text.trim().toLowerCase(),
                    )
                    .limit(1)
                    .get();

            if (adminCheck.docs.isNotEmpty) {
              debugPrint('Admin exists in Firestore but not in Firebase Auth');
              // Don't reveal this to user for security, but log it
            }
          } catch (firestoreError) {
            debugPrint('Error checking Firestore: $firestoreError');
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_getErrorMessage(e)),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        // } catch (e) {
        //   debugPrint('Unexpected error: $e'); // Debug log
        //   if (mounted) {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       SnackBar(
        //         content: Text('Unexpected error: $e'),
        //         backgroundColor: Colors.red,
        //       ),
        //     );
        //   }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _isLoading || _isCheckingAdminStatus;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade300, Colors.blue.shade600],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Card(
                margin: const EdgeInsets.all(20),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Admin Login',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Only authorized administrators can access this application',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                            autocorrect: false,
                            enabled: _isInitialized && !isProcessing,
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
                            enabled: _isInitialized && !isProcessing,
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  (!_isInitialized || isProcessing)
                                      ? null
                                      : _submitForm,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child:
                                  isProcessing
                                      ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            _isCheckingAdminStatus
                                                ? 'Verifying admin...'
                                                : 'Logging in...',
                                            style: const TextStyle(
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      )
                                      : const Text(
                                        'Login',
                                        style: TextStyle(fontSize: 16),
                                      ),
                            ),
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
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
