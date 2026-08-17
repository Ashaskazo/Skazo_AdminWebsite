import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:skazo_admin/providers/user_pagination_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/providers/admin_providers.dart';

class _ServiceRateCardItemControllers {
  final TextEditingController serviceController;
  final TextEditingController rateController;

  _ServiceRateCardItemControllers({String service = '', String rate = ''})
    : serviceController = TextEditingController(text: service),
      rateController = TextEditingController(text: rate);

  void dispose() {
    serviceController.dispose();
    rateController.dispose();
  }
}

class BusinessProfilePage extends ConsumerStatefulWidget {
  final Map<String, dynamic> businessData;

  const BusinessProfilePage({super.key, required this.businessData});

  @override
  ConsumerState<BusinessProfilePage> createState() =>
      _BusinessProfilePageState();
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
  late TextEditingController _transactionIdController;
  late TextEditingController _paymentPlanController;
  late TextEditingController _paymentCountController;
  late TextEditingController _payPerLeadChargeController;

  // Editable Service Rate Card
  late List<_ServiceRateCardItemControllers> _serviceRateCardControllers;

  // Status variables
  late bool _isVerified;
  late bool _isActive;
  late bool _isOnline;
  late bool _isUser;
  late bool _profileComplete;
  late bool _categoryBoostEnabled;
  late bool _paymentLinkSend;
  late bool _isStarServiceProvider;

  @override
  void initState() {
    super.initState();
    final data = widget.businessData;

    _nameController = TextEditingController(text: data['businessname'] ?? '');
    _bioController = TextEditingController(text: data['businessbio'] ?? '');
    _addressController = TextEditingController(
      text: data['businessaddress'] ?? '',
    );
    _firstNameController = TextEditingController(text: data['firstname'] ?? '');
    _lastNameController = TextEditingController(text: data['lastname'] ?? '');
    _phoneController = TextEditingController(
      text: data['phone']?.toString() ?? '',
    );
    _emailController = TextEditingController(text: data['email'] ?? '');
    _planController = TextEditingController(
      text:
          data['AtivePlan']?.toString() ??
          // data['ActivePlan']?.toString() ??
          '0',
    );
    _priorityController = TextEditingController(
      text: data['priority']?.toString() ?? '0',
    );
    _genderController = TextEditingController(text: data['gender'] ?? '');
    _usernameController = TextEditingController(text: data['username'] ?? '');
    _ownerPaidController = TextEditingController(
      text: data['ownerPropertyPaid']?.toString() ?? '0',
    );
    _userPaidController = TextEditingController(
      text: data['userPropertyPaid']?.toString() ?? '0',
    );
    _fcmTokenController = TextEditingController(text: data['fcmtoken'] ?? '');
    _totalAmountController = TextEditingController(
      text: data['totalAmount']?.toString() ?? '0',
    );
    _transactionIdController = TextEditingController(
      text: data['transactionId'] ?? '',
    );
    _paymentPlanController = TextEditingController(
      text: data['paymentPlanDuration'] ?? '',
    );
    _paymentCountController = TextEditingController(
      text: data['paymentCount']?.toString() ?? '0',
    );

    final rawLeadCharge = data['payperLeadCharge'];
    _payPerLeadChargeController = TextEditingController(
      text: rawLeadCharge?.toString() ?? '',
    );

    // Parse Service Rate Card
    _serviceRateCardControllers = [];
    final rawRateCard = data['ServiceRateCard'];
    if (rawRateCard is List) {
      for (var item in rawRateCard) {
        if (item is Map) {
          _serviceRateCardControllers.add(
            _ServiceRateCardItemControllers(
              service: item['service']?.toString() ?? '',
              rate: item['rate']?.toString() ?? '',
            ),
          );
        }
      }
    }

    _isVerified =
        data['isverified'] == true ||
        data['isverified'] == 1 ||
        data['isverified'] == 'true';
    _isActive =
        data['isactive'] == true ||
        data['isactive'] == 1 ||
        data['isactive'] == 'true';
    _isOnline =
        data['isonline'] == true ||
        data['isonline'] == 1 ||
        data['isonline'] == 'true';
    _profileComplete =
        data['profileComplete'] == true ||
        data['profileComplete'] == 1 ||
        data['profileComplete'] == 'true';
    _categoryBoostEnabled =
        data['categoryBoostEnabled'] == true ||
        data['categoryBoostEnabled'] == 1 ||
        data['categoryBoostEnabled'] == 'true';
    _paymentLinkSend =
        data['paymentLinkSend'] == true ||
        data['paymentLinkSend'] == 1 ||
        data['paymentLinkSend'] == 'true';

    final rawStar = data['StarServiceprovider'] ?? data['starServiceProvider'];
    _isStarServiceProvider =
        rawStar == true ||
        rawStar == 1 ||
        rawStar.toString().toLowerCase() == 'true' ||
        rawStar.toString().toLowerCase() == 'yes' ||
        rawStar.toString().toLowerCase() == 'gold' ||
        rawStar.toString().toLowerCase() == 'star';

    if (data.containsKey('isuser') && data['isuser'] != null) {
      _isUser =
          data['isuser'] == true ||
          data['isuser'] == 1 ||
          data['isuser'] == 'true' ||
          data['isuser'] == '1';
    } else {
      final bName = data['businessname']?.toString().trim() ?? '';
      final bPic = data['businesspic']?.toString().trim() ?? '';
      final cat = data['category'];
      final looksLikeProvider =
          bName.isNotEmpty ||
          bPic.isNotEmpty ||
          (cat != null && cat.toString().isNotEmpty);
      _isUser = !looksLikeProvider;
    }
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
    _transactionIdController.dispose();
    _paymentPlanController.dispose();
    _paymentCountController.dispose();
    _payPerLeadChargeController.dispose();

    for (var item in _serviceRateCardControllers) {
      item.dispose();
    }
    super.dispose();
  }

  void _addServiceRateCardItem() {
    setState(() {
      _serviceRateCardControllers.add(_ServiceRateCardItemControllers());
    });
  }

  void _removeServiceRateCardItem(int index) {
    setState(() {
      final item = _serviceRateCardControllers.removeAt(index);
      item.dispose();
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final docId =
          (widget.businessData['id'] ??
                  widget.businessData['uid'] ??
                  widget.businessData['docId'])
              ?.toString()
              .trim();
      if (docId == null || docId.isEmpty) {
        throw 'Document ID is missing. Cannot update profile in Firebase.';
      }

      final adminProfile = ref.read(currentAdminProfileProvider).value;
      final senderId =
          adminProfile?['admin_id'] ?? adminProfile?['id'] ?? 'Unknown';
      final senderName = adminProfile?['name'] ?? 'Unknown';

      final phoneText = _phoneController.text.trim();
      final dynamic phoneValue =
          phoneText.isEmpty ? null : (int.tryParse(phoneText) ?? phoneText);

      final planVal = int.tryParse(_planController.text.trim()) ?? 0;

      // Build Rate Card List
      final List<Map<String, String>> rateCardList = [];
      for (var item in _serviceRateCardControllers) {
        final sName = item.serviceController.text.trim();
        final rVal = item.rateController.text.trim();
        if (sName.isNotEmpty || rVal.isNotEmpty) {
          rateCardList.add({'service': sName, 'rate': rVal});
        }
      }

      final leadChargeText = _payPerLeadChargeController.text.trim();
      final dynamic leadChargeVal =
          leadChargeText.isEmpty
              ? 0
              : (num.tryParse(leadChargeText) ?? leadChargeText);

      final Map<String, dynamic> updatedData = {
        'businessname': _nameController.text.trim(),
        'businessbio': _bioController.text.trim(),
        'businessaddress': _addressController.text.trim(),
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'AtivePlan': planVal,
        // 'ActivePlan': planVal,
        'priority': int.tryParse(_priorityController.text.trim()) ?? 0,
        'gender': _genderController.text.trim(),
        'username': _usernameController.text.trim(),
        'ownerPropertyPaid':
            int.tryParse(_ownerPaidController.text.trim()) ?? 0,
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
        // 'StarServiceprovider': _isStarServiceProvider ? 'true' : 'false',
        'starServiceProvider': _isStarServiceProvider,
        // 'payPerLeadCharge': leadChargeVal,
        'payperLeadcharge': leadChargeVal,
        'ServiceRateCard': rateCardList,
        'transactionId': _transactionIdController.text.trim(),
        'paymentPlanDuration': _paymentPlanController.text.trim(),
        'paymentCount': int.tryParse(_paymentCountController.text.trim()) ?? 0,
        'totalAmount': int.tryParse(_totalAmountController.text.trim()) ?? 0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (phoneValue != null) {
        updatedData['phone'] = phoneValue;
      }

      final bool wasSent = widget.businessData['paymentLinkSend'] == true;
      if (_paymentLinkSend && !wasSent) {
        updatedData['paymentLinkSenderId'] = senderId;
        updatedData['paymentLinkSenderName'] = senderName;
        updatedData['paymentLinkSentAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .set(updatedData, SetOptions(merge: true));
      await ref.read(userPaginationProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'Profile updated with super style! ✨🚀',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oops! Error updating profile: $e 😅'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    Color accentColor = const Color(0xFF6366F1),
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: Icon(icon, color: accentColor, size: 20),
      labelStyle: GoogleFonts.poppins(
        color: const Color(0xFF64748B),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String subtitle,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradientColors.first.withValues(alpha: 0.12),
              gradientColors.last.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: gradientColors.first.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF64748B)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.edit_note_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'User Profile Studio ✨',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _saveChanges,
                  // icon: const Icon(Icons.rocket_launch_rounded, size: 18),
                  label: Text(
                    'Save Changes 🚀',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 50),
          child: Center(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Super Vibrant Hero Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1E1B4B),
                          Color(0xFF312E81),
                          Color(0xFF4338CA),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF312E81).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: data['businesspic'] ?? '',
                                  fit: BoxFit.cover,
                                  memCacheWidth: 240,
                                  memCacheHeight: 240,
                                  maxWidthDiskCache: 480,
                                  errorWidget:
                                      (context, url, error) => const Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                        size: 48,
                                      ),
                                ),
                              ),
                            ),
                            if (_isOnline)
                              Positioned(
                                right: 4,
                                bottom: 4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      data['businessname'] ??
                                          data['firstname'] ??
                                          'Anonymous VIP User 👑',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(
                                        color: Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (_isStarServiceProvider) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFFF59E0B,
                                            ).withValues(alpha: 0.4),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'STAR PROVIDER',
                                            style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "UID: ${data['uid'] ?? data['id'] ?? 'No UID'}",
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildBadgeChip(
                                    _isVerified
                                        ? 'VERIFIED LEGEND'
                                        : 'UNVERIFIED',
                                    _isVerified
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B),
                                    _isVerified
                                        ? Icons.verified_rounded
                                        : Icons.help_outline_rounded,
                                  ),
                                  _buildBadgeChip(
                                    _isActive
                                        ? 'ACTIVE ACCOUNT'
                                        : 'DEACTIVATED',
                                    _isActive
                                        ? const Color(0xFF3B82F6)
                                        : const Color(0xFFEF4444),
                                    _isActive
                                        ? Icons.bolt_rounded
                                        : Icons.pause_circle_rounded,
                                  ),
                                  _buildBadgeChip(
                                    _isUser
                                        ? 'REGULAR USER'
                                        : 'SERVICE PROVIDER 🛠️',
                                    const Color(0xFF8B5CF6),
                                    Icons.badge_rounded,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Switches Bar
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              color: Color(0xFF6366F1),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Account Status & Badges Control 🎛️',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildToggle(
                              'Verified User',
                              _isVerified,
                              (v) => setState(() => _isVerified = v),
                              activeColor: const Color(0xFF10B981),
                              icon: Icons.verified_rounded,
                            ),
                            _buildToggle(
                              'Star Service Provider',
                              _isStarServiceProvider,
                              (v) => setState(() => _isStarServiceProvider = v),
                              activeColor: const Color(0xFFF59E0B),
                              icon: Icons.star_rounded,
                            ),
                            _buildToggle(
                              'Active Status',
                              _isActive,
                              (v) => setState(() => _isActive = v),
                              activeColor: const Color(0xFF3B82F6),
                              icon: Icons.power_settings_new_rounded,
                            ),
                            _buildToggle(
                              'Online Now',
                              _isOnline,
                              (v) => setState(() => _isOnline = v),
                              activeColor: const Color(0xFF10B981),
                              icon: Icons.circle_rounded,
                            ),
                            _buildToggle(
                              'Is User',
                              _isUser,
                              (v) => setState(() => _isUser = v),
                              activeColor: const Color(0xFF8B5CF6),
                              icon: Icons.person_rounded,
                            ),
                            _buildToggle(
                              'Profile Complete',
                              _profileComplete,
                              (v) => setState(() => _profileComplete = v),
                              activeColor: const Color(0xFF06B6D4),
                              icon: Icons.check_circle_rounded,
                            ),
                            _buildToggle(
                              'Category Boost',
                              _categoryBoostEnabled,
                              (v) => setState(() => _categoryBoostEnabled = v),
                              activeColor: const Color(0xFFEC4899),
                              icon: Icons.auto_awesome_rounded,
                            ),
                            _buildToggle(
                              'Payment Link Sent',
                              _paymentLinkSend,
                              (v) => setState(() => _paymentLinkSend = v),
                              activeColor: const Color(0xFF6366F1),
                              icon: Icons.send_rounded,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Business Information Section
                  _buildSectionHeader(
                    'Business Information 🏢',
                    'Manage company branding, bio, and business address',
                    Icons.business_rounded,
                    [const Color(0xFF4F46E5), const Color(0xFF6366F1)],
                  ),
                  TextFormField(
                    controller: _nameController,
                    decoration: _buildInputDecoration(
                      'Business Name',
                      Icons.storefront_rounded,
                      accentColor: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 2,
                    decoration: _buildInputDecoration(
                      'Business Bio',
                      Icons.description_rounded,
                      accentColor: const Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressController,
                    maxLines: 2,
                    decoration: _buildInputDecoration(
                      'Business Address',
                      Icons.location_on_rounded,
                      accentColor: const Color(0xFF4F46E5),
                    ),
                  ),

                  // Personal Information Section
                  _buildSectionHeader(
                    'Personal Information 👤',
                    'Contact details and personal identifiers',
                    Icons.person_rounded,
                    [const Color(0xFF0EA5E9), const Color(0xFF0284C7)],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameController,
                          decoration: _buildInputDecoration(
                            'First Name',
                            Icons.person_outline_rounded,
                            accentColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameController,
                          decoration: _buildInputDecoration(
                            'Last Name',
                            Icons.person_outline_rounded,
                            accentColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _usernameController,
                          decoration: _buildInputDecoration(
                            'Username',
                            Icons.alternate_email_rounded,
                            accentColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _genderController,
                          decoration: _buildInputDecoration(
                            'Gender',
                            Icons.wc_rounded,
                            accentColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _buildInputDecoration(
                            'Phone Number',
                            Icons.phone_android_rounded,
                            accentColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildInputDecoration(
                            'Email Address',
                            Icons.email_rounded,
                            accentColor: const Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Editable Service Rate Card & Pay Per Lead Charge Section
                  _buildSectionHeader(
                    'Service Rate Card & Lead Pricing ⚡💰',
                    'Edit service rate list & configure pay per lead charge (₹)',
                    Icons.payments_rounded,
                    [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  ),

                  // Pay per lead charge card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFFFBEB),
                          const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.monetization_on_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pay Per Lead Charge (₹)',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF78350F),
                                ),
                              ),
                              Text(
                                'Amount charged to service provider per generated lead',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 180,
                          child: TextFormField(
                            controller: _payPerLeadChargeController,
                            keyboardType: TextInputType.number,
                            decoration: _buildInputDecoration(
                              'Charge / Lead (₹)',
                              Icons.currency_rupee_rounded,
                              accentColor: const Color(0xFFF59E0B),
                              hintText: 'e.g. 50',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Editable Service Rate Card List
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.receipt_long_rounded,
                                  color: Color(0xFFF59E0B),
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Service Rate Card Items (${_serviceRateCardControllers.length})',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            ElevatedButton.icon(
                              onPressed: _addServiceRateCardItem,
                              icon: const Icon(
                                Icons.add_circle_rounded,
                                size: 18,
                              ),
                              label: Text(
                                'Add Service',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF59E0B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_serviceRateCardControllers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.miscellaneous_services_rounded,
                                  color: Color(0xFF94A3B8),
                                  size: 36,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'No rate card services added yet!',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Text(
                                  'Click "+ Add Service" to add custom service rates.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _serviceRateCardControllers.length,
                            separatorBuilder:
                                (c, i) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _serviceRateCardControllers[index];
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '#${index + 1}',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: item.serviceController,
                                        decoration: _buildInputDecoration(
                                          'Service Name',
                                          Icons.build_rounded,
                                          accentColor: const Color(0xFFF59E0B),
                                          hintText: 'e.g. AC Repair',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: item.rateController,
                                        decoration: _buildInputDecoration(
                                          'Rate (₹)',
                                          Icons.currency_rupee_rounded,
                                          accentColor: const Color(0xFFF59E0B),
                                          hintText: 'e.g. 499',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed:
                                          () =>
                                              _removeServiceRateCardItem(index),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFEF4444),
                                      ),
                                      tooltip: 'Delete Service',
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),

                  // Categories Overview
                  const SizedBox(height: 16),
                  _buildReadOnlyField(
                    'Categories Assigned 🏷️',
                    (data['category'] is List)
                        ? (data['category'] as List).join(', ')
                        : (data['category']?.toString() ?? 'None'),
                    Icons.category_rounded,
                  ),

                  // Subscription & Financials
                  _buildSectionHeader(
                    'Account Plan & Financials 💳',
                    'Active subscription plan, total amount paid, and property credits',
                    Icons.card_membership_rounded,
                    [const Color(0xFF10B981), const Color(0xFF059669)],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _planController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'Active Plan Code',
                            Icons.card_membership_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _priorityController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'Search Priority',
                            Icons.low_priority_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ownerPaidController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'Owner Paid Property Count',
                            Icons.monetization_on_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _userPaidController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'User Paid Property Count',
                            Icons.account_balance_wallet_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _transactionIdController,
                          decoration: _buildInputDecoration(
                            'Transaction ID',
                            Icons.receipt_long_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _paymentPlanController,
                          decoration: _buildInputDecoration(
                            'Payment Plan Duration',
                            Icons.workspace_premium_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _paymentCountController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'Payment Count',
                            Icons.numbers_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _totalAmountController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'Total Amount Paid (₹)',
                            Icons.payments_rounded,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Usage Statistics Section
                  _buildSectionHeader(
                    'Usage Statistics & Activity 📊',
                    'Call metrics, lead performance, and user ratings',
                    Icons.insights_rounded,
                    [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Total Call Logs',
                          data['totalCallLogs']?.toString() ?? '0',
                          Icons.call_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Today Calls',
                          data['todayCallLogs']?.toString() ?? '0',
                          Icons.today_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Calls Post Payment',
                          data['callsAfterLastPayment']?.toString() ?? '0',
                          Icons.phone_callback_rounded,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Average Rating ⭐',
                          "${data['avgRating']?.toString() ?? '0.0'} / 5.0",
                          Icons.star_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Total Ratings Received',
                          data['totalRatings']?.toString() ?? '0',
                          Icons.reviews_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Total Calls Generated',
                          data['totalCallsGenerated']?.toString() ?? '0',
                          Icons.trending_up_rounded,
                        ),
                      ),
                    ],
                  ),

                  // Activity Timestamps Section
                  _buildSectionHeader(
                    'Activity Timeline ⏳',
                    'Historical timestamps for verification and payments',
                    Icons.history_rounded,
                    [const Color(0xFFEC4899), const Color(0xFFDB2777)],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Verified At',
                          _formatTimestamp(data['verifiedAt']),
                          Icons.verified_user_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Last Call At',
                          _formatTimestamp(data['lastCallAt']),
                          Icons.history_rounded,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Last Payment At',
                          _formatTimestamp(data['lastPaymentAt']),
                          Icons.payment_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Category Boost Updated',
                          _formatTimestamp(data['categoryBoostUpdatedAt']),
                          Icons.auto_awesome_rounded,
                        ),
                      ),
                    ],
                  ),

                  // Technical Metadata Section
                  _buildSectionHeader(
                    'Technical Metadata 🛠️',
                    'FCM Push Tokens, Geolocation & Geohashes',
                    Icons.developer_board_rounded,
                    [const Color(0xFF64748B), const Color(0xFF334155)],
                  ),
                  TextFormField(
                    controller: _fcmTokenController,
                    decoration: _buildInputDecoration(
                      'FCM Token',
                      Icons.key_rounded,
                      accentColor: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Location (Geopoint)',
                          data['location']?['geopoint']?.toString() ?? 'N/A',
                          Icons.map_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Coordinates',
                          "${data['coordinates']?[0] ?? '0'}, ${data['coordinates']?[1] ?? '0'}",
                          Icons.gps_fixed_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Geohash (5/7)',
                          "${data['geohash5'] ?? 'N/A'} / ${data['geohash7'] ?? 'N/A'}",
                          Icons.language_rounded,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildBadgeChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(
    String label,
    bool value,
    Function(bool) onChanged, {
    Color activeColor = const Color(0xFF6366F1),
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:
            value
                ? activeColor.withValues(alpha: 0.1)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              value
                  ? activeColor.withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: value ? activeColor : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: value ? FontWeight.w700 : FontWeight.w500,
              color: value ? activeColor : const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 6),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: activeColor,
            ),
          ),
        ],
      ),
    );
  }
}
