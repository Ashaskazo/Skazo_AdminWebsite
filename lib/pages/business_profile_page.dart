import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/providers/admin_providers.dart';

class BusinessProfilePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> businessData;

  const BusinessProfilePage({super.key, required this.businessData});

  @override
  ConsumerState<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends ConsumerState<BusinessProfilePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  late TextEditingController _addressController;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _planController;
  late TextEditingController _priorityController;
  late TextEditingController _genderController;
  late TextEditingController _usernameController;
  late TextEditingController _ownerPaidController;
  late TextEditingController _userPaidController;
  late TextEditingController _fcmTokenController;
  late TextEditingController _totalAmountController;

  // Status variables
  late bool _isVerified;
  late bool _isActive;
  late bool _isOnline;
  late bool _isUser;
  late bool _profileComplete;
  late bool _categoryBoostEnabled;
  late bool _paymentLinkSend;

  @override
  void initState() {
    super.initState();
    final data = widget.businessData;
    _nameController = TextEditingController(text: data['businessname'] ?? '');
    _bioController = TextEditingController(text: data['businessbio'] ?? '');
    _addressController = TextEditingController(text: data['businessaddress'] ?? '');
    _firstNameController = TextEditingController(text: data['firstname'] ?? '');
    _lastNameController = TextEditingController(text: data['lastname'] ?? '');
    _phoneController = TextEditingController(text: data['phone']?.toString() ?? '');
    _emailController = TextEditingController(text: data['email'] ?? '');
    _planController = TextEditingController(text: data['AtivePlan']?.toString() ?? '0');
    _priorityController = TextEditingController(text: data['priority']?.toString() ?? '0');
    _genderController = TextEditingController(text: data['gender'] ?? '');
    _usernameController = TextEditingController(text: data['username'] ?? '');
    _ownerPaidController = TextEditingController(text: data['ownerPropertyPaid']?.toString() ?? '0');
    _userPaidController = TextEditingController(text: data['userPropertyPaid']?.toString() ?? '0');
    _fcmTokenController = TextEditingController(text: data['fcmtoken'] ?? '');
    _totalAmountController = TextEditingController(text: data['totalAmount']?.toString() ?? '0');

    _isVerified = data['isverified'] ?? false;
    _isActive = data['isactive'] ?? false;
    _isOnline = data['isonline'] ?? false;
    _isUser = data['isuser'] ?? false;
    _profileComplete = data['profileComplete'] ?? false;
    _categoryBoostEnabled = data['categoryBoostEnabled'] ?? false;
    _paymentLinkSend = data['paymentLinkSend'] ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _planController.dispose();
    _priorityController.dispose();
    _genderController.dispose();
    _usernameController.dispose();
    _ownerPaidController.dispose();
    _userPaidController.dispose();
    _fcmTokenController.dispose();
    _totalAmountController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final adminProfile = ref.read(currentAdminProfileProvider).value;
      final senderId = adminProfile?['admin_id'] ?? adminProfile?['id'] ?? 'Unknown';
      final senderName = adminProfile?['name'] ?? 'Unknown';

      final Map<String, dynamic> updatedData = {
        'businessname': _nameController.text.trim(),
        'businessbio': _bioController.text.trim(),
        'businessaddress': _addressController.text.trim(),
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'phone': int.tryParse(_phoneController.text.trim()) ?? 0,
        'email': _emailController.text.trim(),
        'AtivePlan': int.tryParse(_planController.text.trim()) ?? 0,
        'priority': int.tryParse(_priorityController.text.trim()) ?? 0,
        'gender': _genderController.text.trim(),
        'username': _usernameController.text.trim(),
        'ownerPropertyPaid': int.tryParse(_ownerPaidController.text.trim()) ?? 0,
        'userPropertyPaid': int.tryParse(_userPaidController.text.trim()) ?? 0,
        'fcmtoken': _fcmTokenController.text.trim(),
        'isverified': _isVerified,
        'isactive': _isActive,
        'isDeactivated': !_isActive,
        'isonline': _isOnline,
        'isuser': _isUser,
        'profileComplete': _profileComplete,
        'categoryBoostEnabled': _categoryBoostEnabled,
        'paymentLinkSend': _paymentLinkSend,
        'totalAmount': int.tryParse(_totalAmountController.text.trim()) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final bool wasSent = widget.businessData['paymentLinkSend'] ?? false;
      if (_paymentLinkSend && !wasSent) {
        updatedData['paymentLinkSenderId'] = senderId;
        updatedData['paymentLinkSenderName'] = senderName;
        updatedData['paymentLinkSentAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance.collection('users').doc(widget.businessData['id']).update(updatedData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating profile: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      labelStyle: GoogleFonts.poppins(color: const Color(0xFF64748B), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 16),
      child: Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9).withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xFF0F172A), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    return timestamp.toString();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.businessData;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('User Profile Editor', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF0F172A))),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [const Color(0xFF2563EB), const Color(0xFF1E40AF)]),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 4)),
                      child: ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: data['businesspic'] ?? '',
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['businessname'] ?? 'No Name', style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                          Text(data['uid'] ?? 'No UID', style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                            child: Text(data['isverified'] == true ? 'Verified' : 'Unverified', style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              _buildSectionHeader('Business Information'),
              TextFormField(controller: _nameController, decoration: _buildInputDecoration('Business Name', Icons.business_rounded)),
              const SizedBox(height: 16),
              TextFormField(controller: _bioController, maxLines: 2, decoration: _buildInputDecoration('Business Bio', Icons.description_rounded)),
              const SizedBox(height: 16),
              TextFormField(controller: _addressController, maxLines: 2, decoration: _buildInputDecoration('Business Address', Icons.location_on_rounded)),
              
              _buildSectionHeader('Personal Information'),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _firstNameController, decoration: _buildInputDecoration('First Name', Icons.person_outline))),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _lastNameController, decoration: _buildInputDecoration('Last Name', Icons.person_outline))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _usernameController, decoration: _buildInputDecoration('Username', Icons.alternate_email_rounded))),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _genderController, decoration: _buildInputDecoration('Gender', Icons.wc_rounded))),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _buildInputDecoration('Phone Number', Icons.phone_android_rounded)),
              const SizedBox(height: 16),
              TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _buildInputDecoration('Email', Icons.email_rounded)),

              _buildSectionHeader('Service Details'),
              // Category (Read only list for now)
              _buildReadOnlyField('Categories', (data['category'] as List?)?.join(', ') ?? 'None', Icons.category_rounded),
              _buildReadOnlyField('Service Rate Card', (data['ServiceRateCard'] as List?)?.map((e) => "${e['service']}: ₹${e['rate']}").join('\n') ?? 'None', Icons.payments_rounded),

              _buildSectionHeader('Account & Subscription'),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _planController, keyboardType: TextInputType.number, decoration: _buildInputDecoration('Active Plan', Icons.card_membership_rounded))),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _priorityController, keyboardType: TextInputType.number, decoration: _buildInputDecoration('Priority', Icons.low_priority_rounded))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _ownerPaidController, keyboardType: TextInputType.number, decoration: _buildInputDecoration('Owner Paid', Icons.monetization_on_rounded))),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _userPaidController, keyboardType: TextInputType.number, decoration: _buildInputDecoration('User Paid', Icons.account_balance_wallet_rounded))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _totalAmountController, keyboardType: TextInputType.number, decoration: _buildInputDecoration('Total Amount Paid (₹)', Icons.payments_rounded))),
                  const SizedBox(width: 16),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  _buildToggle('Verified', _isVerified, (v) => setState(() => _isVerified = v)),
                  _buildToggle('Active', _isActive, (v) => setState(() => _isActive = v)),
                  _buildToggle('Online', _isOnline, (v) => setState(() => _isOnline = v)),
                  _buildToggle('Is User', _isUser, (v) => setState(() => _isUser = v)),
                  _buildToggle('Profile Complete', _profileComplete, (v) => setState(() => _profileComplete = v)),
                  _buildToggle('Category Boost', _categoryBoostEnabled, (v) => setState(() => _categoryBoostEnabled = v)),
                  _buildToggle('Payment Link Sent', _paymentLinkSend, (v) => setState(() => _paymentLinkSend = v)),
                ],
              ),

              _buildSectionHeader('Usage Statistics'),
              Row(
                children: [
                  Expanded(child: _buildReadOnlyField('Total Calls', data['totalCallLogs']?.toString() ?? '0', Icons.call_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildReadOnlyField('Today Calls', data['todayCallLogs']?.toString() ?? '0', Icons.today_rounded)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildReadOnlyField('Avg Rating', data['avgRating']?.toString() ?? '0.0', Icons.star_rounded)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildReadOnlyField('Total Ratings', data['totalRatings']?.toString() ?? '0', Icons.reviews_rounded)),
                ],
              ),
              _buildReadOnlyField('Total Calls Generated', data['totalCallsGenerated']?.toString() ?? '0', Icons.trending_up_rounded),

              _buildSectionHeader('Activity Timestamps'),
              _buildReadOnlyField('Verified At', _formatTimestamp(data['verifiedAt']), Icons.verified_user_rounded),
              _buildReadOnlyField('Last Call At', _formatTimestamp(data['lastCallAt']), Icons.history_rounded),
              _buildReadOnlyField('Last Payment At', _formatTimestamp(data['lastPaymentAt']), Icons.payment_rounded),
              _buildReadOnlyField('Category Boost Updated', _formatTimestamp(data['categoryBoostUpdatedAt']), Icons.auto_awesome_rounded),

              _buildSectionHeader('Technical Metadata'),
              TextFormField(controller: _fcmTokenController, decoration: _buildInputDecoration('FCM Token', Icons.key_rounded)),
              const SizedBox(height: 16),
              _buildReadOnlyField('Location (Geopoint)', data['location']?['geopoint']?.toString() ?? 'N/A', Icons.map_rounded),
              _buildReadOnlyField('Coordinates', "${data['coordinates']?[0] ?? '0'}, ${data['coordinates']?[1] ?? '0'}", Icons.gps_fixed_rounded),
              _buildReadOnlyField('Geohash 5/7', "${data['geohash5'] ?? 'N/A'} / ${data['geohash7'] ?? 'N/A'}", Icons.language_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggle(String label, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF2563EB).withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF0F172A)),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF2563EB),
            ),
          ),
        ],
      ),
    );
  }
}
