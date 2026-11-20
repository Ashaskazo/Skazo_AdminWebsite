// ignore_for_file: deprecated_member_use
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/utils/responsive.dart';

/// Complete Edit Promotional Details Page.
/// Displays and allows editing/copying of every field in the Firestore `local_promotions` document.
class PromotionDetailsPage extends ConsumerStatefulWidget {
  final Map<String, dynamic> promotionData;

  const PromotionDetailsPage({super.key, required this.promotionData});

  @override
  ConsumerState<PromotionDetailsPage> createState() => _PromotionDetailsPageState();
}

class _PromotionDetailsPageState extends ConsumerState<PromotionDetailsPage> {
  late Map<String, dynamic> _originalData;
  bool _isSaving = false;

  // Controllers for editable string and numeric fields
  late TextEditingController _brandNameController;
  late TextEditingController _descriptionController;
  late TextEditingController _activePlanController;
  late TextEditingController _transactionIdController;
  late TextEditingController _uidController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;
  late TextEditingController _socialLinksController;
  late TextEditingController _bannerUrlController;
  late TextEditingController _logoUrlController;
  late TextEditingController _viewsController;
  late TextEditingController _clicksController;
  late TextEditingController _contactedCountController;
  late TextEditingController _targetViewsController;
  late TextEditingController _maxViewsController;
  late TextEditingController _geohashController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  late TextEditingController _salesFeedbackController;

  // Status booleans
  bool _isVerified = false;
  bool _islocalbbaner = false;
  bool _paymentInitiated = false;
  bool _paymentLinkSend = false;
  bool _isVisible = true;
  bool _isBoosted = false;
  String _status = 'under_review';

  // Dates
  DateTime? _paymentDate;
  DateTime? _planExpiredDate;
  DateTime? _createdAt;
  DateTime? _timestamp;

  @override
  void initState() {
    super.initState();
    _originalData = Map<String, dynamic>.from(widget.promotionData);
    _initControllersFromData(_originalData);
  }

  void _initControllersFromData(Map<String, dynamic> data) {
    // Brand Name (with fallback to title)
    final brand = (data['brandName'] ?? data['title'] ?? '').toString();
    _brandNameController = TextEditingController(text: brand);

    _descriptionController = TextEditingController(text: (data['description'] ?? '').toString());
    _activePlanController = TextEditingController(text: (data['activePlan'] ?? '').toString());
    _transactionIdController = TextEditingController(text: (data['transactionId'] ?? '').toString());
    _uidController = TextEditingController(text: (data['uid'] ?? '').toString());
    _mobileNumberController = TextEditingController(text: (data['mobileNumber'] ?? '').toString());
    _addressController = TextEditingController(text: (data['address'] ?? '').toString());
    _cityController = TextEditingController(text: (data['city'] ?? '').toString());
    _socialLinksController = TextEditingController(text: (data['socialLinks'] ?? '').toString());

    // Banner and Logo URLs
    final banner = (data['bannerUrl'] ?? data['imageUrl'] ?? data['image'] ?? '').toString();
    final logo = (data['logoUrl'] ?? '').toString();
    _bannerUrlController = TextEditingController(text: banner);
    _logoUrlController = TextEditingController(text: logo);

    // Performance numbers
    final views = data['views'] ?? data['viewsCount'] ?? 0;
    final clicks = data['clicks'] ?? data['clicksCount'] ?? 0;
    final contacted = data['contactedCount'] ?? 0;
    final targetViews = data['targetViews'] ?? 0;
    final maxViews = data['maxViews'] ?? 0;

    _viewsController = TextEditingController(text: views.toString());
    _clicksController = TextEditingController(text: clicks.toString());
    _contactedCountController = TextEditingController(text: contacted.toString());
    _targetViewsController = TextEditingController(text: targetViews.toString());
    _maxViewsController = TextEditingController(text: maxViews.toString());

    // Location parsing (geohash & geopoint)
    String geohash = '';
    double? latitude;
    double? longitude;

    final rawLocation = data['location'];
    if (rawLocation is Map) {
      geohash = (rawLocation['geohash'] ?? '').toString();
      final gp = rawLocation['geopoint'];
      if (gp is GeoPoint) {
        latitude = gp.latitude;
        longitude = gp.longitude;
      } else if (gp is Map) {
        latitude = (gp['latitude'] ?? gp['lat'] as num?)?.toDouble();
        longitude = (gp['longitude'] ?? gp['lng'] as num?)?.toDouble();
      } else {
        latitude = (rawLocation['latitude'] ?? rawLocation['lat'] as num?)?.toDouble();
        longitude = (rawLocation['longitude'] ?? rawLocation['lng'] as num?)?.toDouble();
      }
    } else if (rawLocation is GeoPoint) {
      latitude = rawLocation.latitude;
      longitude = rawLocation.longitude;
    }

    _geohashController = TextEditingController(text: geohash);
    _latitudeController = TextEditingController(text: latitude != null ? latitude.toString() : '');
    _longitudeController = TextEditingController(text: longitude != null ? longitude.toString() : '');

    _salesFeedbackController = TextEditingController(text: (data['salesFeedback'] ?? '').toString());

    // Statuses
    _isVerified = data['isVerified'] == true;
    _islocalbbaner = data['islocalbbaner'] == true;
    _paymentInitiated = data['paymentInitiated'] == true;
    _paymentLinkSend = data['paymentLinkSend'] == true;
    _isVisible = data['isVisible'] == true || data['status'] == 'live';
    _isBoosted = data['isBoosted'] == true;
    _status = (data['status'] ?? 'under_review').toString();

    // Dates
    _paymentDate = _parseDateTime(data['paymentDate']);
    _planExpiredDate = _parseDateTime(data['planExpiredDate']);
    _createdAt = _parseDateTime(data['createdAt']);
    _timestamp = _parseDateTime(data['timestamp']);

    // Re-render when image URL text changes to show live preview
    _bannerUrlController.addListener(_onImageUrlChanged);
    _logoUrlController.addListener(_onImageUrlChanged);
  }

  void _onImageUrlChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _bannerUrlController.removeListener(_onImageUrlChanged);
    _logoUrlController.removeListener(_onImageUrlChanged);
    _brandNameController.dispose();
    _descriptionController.dispose();
    _activePlanController.dispose();
    _transactionIdController.dispose();
    _uidController.dispose();
    _mobileNumberController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _socialLinksController.dispose();
    _bannerUrlController.dispose();
    _logoUrlController.dispose();
    _viewsController.dispose();
    _clicksController.dispose();
    _contactedCountController.dispose();
    _targetViewsController.dispose();
    _maxViewsController.dispose();
    _geohashController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _salesFeedbackController.dispose();
    super.dispose();
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  void _copyToClipboard(String label, dynamic value) {
    final text = value?.toString() ?? '';
    if (text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label is empty'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDateTime({
    required BuildContext context,
    required DateTime? initialDateTime,
    required void Function(DateTime?) onSelected,
  }) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initialDateTime ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date == null) return;

    if (!context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: initialDateTime != null
          ? TimeOfDay(hour: initialDateTime.hour, minute: initialDateTime.minute)
          : TimeOfDay.fromDateTime(now),
    );
    if (time == null) return;

    final combined = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    onSelected(combined);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final docId = _originalData['id'] ?? widget.promotionData['id'];
      if (docId == null || docId.toString().isEmpty) {
        throw 'Document ID not found';
      }

      // City-wise admin security verification
      final scope = ref.read(cityAccessScopeProvider);
      final pincodesMap = ref.read(propertyPincodesProvider).valueOrNull ?? const {};
      if (!scope.isAuthorized) {
        throw 'Access denied: your account is not authorized for city-scoped updates.';
      }
      if (!scope.isUnrestricted) {
        if (!scope.allowsRecord(widget.promotionData, pincodesMap: pincodesMap) ||
            !scope.allowsRecord(_originalData, pincodesMap: pincodesMap)) {
          throw 'Access denied: this promotion belongs to an unassigned city.';
        }
        final candidateRecord = <String, dynamic>{
          ..._originalData,
          'city': _cityController.text.trim(),
          'address': _addressController.text.trim(),
        };
        if (!scope.allowsRecord(candidateRecord, pincodesMap: pincodesMap)) {
          throw 'Access denied: cannot reassign this promotion outside your assigned cities.';
        }
      }

      // Build partial updates map containing ONLY modified fields
      final Map<String, dynamic> updates = {};

      // Promotion Information
      final newBrand = _brandNameController.text.trim();
      final origBrand = (_originalData['brandName'] ?? _originalData['title'] ?? '').toString().trim();
      if (newBrand != origBrand) {
        updates['brandName'] = newBrand;
        updates['title'] = newBrand;
      }

      final newDesc = _descriptionController.text.trim();
      final origDesc = (_originalData['description'] ?? '').toString().trim();
      if (newDesc != origDesc) {
        updates['description'] = newDesc;
      }

      final newPlan = _activePlanController.text.trim();
      final origPlan = (_originalData['activePlan'] ?? '').toString().trim();
      if (newPlan != origPlan) {
        updates['activePlan'] = newPlan;
      }

      final newTxn = _transactionIdController.text.trim();
      final origTxn = (_originalData['transactionId'] ?? '').toString().trim();
      if (newTxn != origTxn) {
        updates['transactionId'] = newTxn;
      }

      final newUid = _uidController.text.trim();
      final origUid = (_originalData['uid'] ?? '').toString().trim();
      if (newUid != origUid) {
        updates['uid'] = newUid;
      }

      // Contact Information
      final newMobile = _mobileNumberController.text.trim();
      final origMobile = (_originalData['mobileNumber'] ?? '').toString().trim();
      if (newMobile != origMobile) {
        updates['mobileNumber'] = newMobile;
      }

      final newAddress = _addressController.text.trim();
      final origAddress = (_originalData['address'] ?? '').toString().trim();
      if (newAddress != origAddress) {
        updates['address'] = newAddress;
      }

      final newCity = _cityController.text.trim();
      final origCity = (_originalData['city'] ?? '').toString().trim();
      if (newCity != origCity) {
        updates['city'] = newCity;
      }

      final newSocial = _socialLinksController.text.trim();
      final origSocial = (_originalData['socialLinks'] ?? '').toString().trim();
      if (newSocial != origSocial) {
        updates['socialLinks'] = newSocial;
      }

      // Images and Media
      final newBanner = _bannerUrlController.text.trim();
      final origBanner = (_originalData['bannerUrl'] ?? _originalData['imageUrl'] ?? '').toString().trim();
      if (newBanner != origBanner) {
        updates['bannerUrl'] = newBanner;
        updates['imageUrl'] = newBanner;
      }

      final newLogo = _logoUrlController.text.trim();
      final origLogo = (_originalData['logoUrl'] ?? '').toString().trim();
      if (newLogo != origLogo) {
        updates['logoUrl'] = newLogo;
      }

      // Performance Statistics (Protected from accidental overwriting)
      // Only include if user explicitly altered the value on screen
      final newViewsStr = _viewsController.text.trim();
      final origViews = _originalData['views'] ?? _originalData['viewsCount'];
      if (newViewsStr != (origViews?.toString() ?? '0')) {
        final parsedViews = int.tryParse(newViewsStr) ?? 0;
        updates['views'] = parsedViews;
        if (_originalData.containsKey('viewsCount')) {
          updates['viewsCount'] = parsedViews;
        }
      }

      final newClicksStr = _clicksController.text.trim();
      final origClicks = _originalData['clicks'] ?? _originalData['clicksCount'];
      if (newClicksStr != (origClicks?.toString() ?? '0')) {
        final parsedClicks = int.tryParse(newClicksStr) ?? 0;
        updates['clicks'] = parsedClicks;
        if (_originalData.containsKey('clicksCount')) {
          updates['clicksCount'] = parsedClicks;
        }
      }

      final newContactedStr = _contactedCountController.text.trim();
      final origContacted = _originalData['contactedCount'];
      if (newContactedStr != (origContacted?.toString() ?? '0')) {
        updates['contactedCount'] = int.tryParse(newContactedStr) ?? 0;
      }

      final newTargetStr = _targetViewsController.text.trim();
      final origTarget = _originalData['targetViews'];
      if (newTargetStr != (origTarget?.toString() ?? '0')) {
        updates['targetViews'] = int.tryParse(newTargetStr) ?? 0;
      }

      final newMaxStr = _maxViewsController.text.trim();
      final origMax = _originalData['maxViews'];
      if (newMaxStr != (origMax?.toString() ?? '0')) {
        updates['maxViews'] = int.tryParse(newMaxStr) ?? 0;
      }

      // Status Booleans
      if (_isVerified != (_originalData['isVerified'] == true)) {
        updates['isVerified'] = _isVerified;
      }
      if (_islocalbbaner != (_originalData['islocalbbaner'] == true)) {
        updates['islocalbbaner'] = _islocalbbaner;
      }
      if (_paymentInitiated != (_originalData['paymentInitiated'] == true)) {
        updates['paymentInitiated'] = _paymentInitiated;
      }
      if (_paymentLinkSend != (_originalData['paymentLinkSend'] == true)) {
        updates['paymentLinkSend'] = _paymentLinkSend;
      }
      if (_isVisible != (_originalData['isVisible'] == true)) {
        updates['isVisible'] = _isVisible;
      }
      if (_isBoosted != (_originalData['isBoosted'] == true)) {
        updates['isBoosted'] = _isBoosted;
      }
      if (_status != (_originalData['status']?.toString() ?? 'under_review')) {
        updates['status'] = _status;
      }

      // Payment and Expiry Dates
      final origPaymentDate = _parseDateTime(_originalData['paymentDate']);
      if (_paymentDate != origPaymentDate) {
        updates['paymentDate'] = _paymentDate != null ? Timestamp.fromDate(_paymentDate!) : null;
      }

      final origPlanExpiredDate = _parseDateTime(_originalData['planExpiredDate']);
      if (_planExpiredDate != origPlanExpiredDate) {
        updates['planExpiredDate'] =
            _planExpiredDate != null ? Timestamp.fromDate(_planExpiredDate!) : null;
      }

      // Location Information (Geohash & GeoPoint)
      final newGeohash = _geohashController.text.trim();
      final newLatStr = _latitudeController.text.trim();
      final newLngStr = _longitudeController.text.trim();
      final newLat = double.tryParse(newLatStr);
      final newLng = double.tryParse(newLngStr);

      final origLocation = _originalData['location'];
      String origGeohash = '';
      double? origLat;
      double? origLng;
      if (origLocation is Map) {
        origGeohash = (origLocation['geohash'] ?? '').toString();
        final gp = origLocation['geopoint'];
        if (gp is GeoPoint) {
          origLat = gp.latitude;
          origLng = gp.longitude;
        } else if (gp is Map) {
          origLat = (gp['latitude'] ?? gp['lat'] as num?)?.toDouble();
          origLng = (gp['longitude'] ?? gp['lng'] as num?)?.toDouble();
        }
      } else if (origLocation is GeoPoint) {
        origLat = origLocation.latitude;
        origLng = origLocation.longitude;
      }

      if (newGeohash != origGeohash || newLat != origLat || newLng != origLng) {
        final locationMap = (origLocation is Map)
            ? Map<String, dynamic>.from(origLocation)
            : <String, dynamic>{};
        locationMap['geohash'] = newGeohash;
        if (newLat != null && newLng != null) {
          locationMap['geopoint'] = GeoPoint(newLat, newLng);
        } else if (newLat == null && newLng == null) {
          locationMap.remove('geopoint');
        }
        updates['location'] = locationMap;
      }

      // Sales Feedback
      final newFeedback = _salesFeedbackController.text.trim();
      final origFeedback = (_originalData['salesFeedback'] ?? '').toString().trim();
      if (newFeedback != origFeedback) {
        updates['salesFeedback'] = newFeedback;
      }

      if (updates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No changes detected to save.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // Execute partial update on Firestore
      await FirebaseFirestore.instance
          .collection('local_promotions')
          .doc(docId.toString())
          .update(updates);

      // Refresh displayed document directly from Firestore
      final freshSnap = await FirebaseFirestore.instance
          .collection('local_promotions')
          .doc(docId.toString())
          .get();

      if (freshSnap.exists && freshSnap.data() != null) {
        if (mounted) {
          setState(() {
            _originalData = {'id': docId, ...freshSnap.data()!};
            _initControllersFromData(_originalData);
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Promotion updated successfully!'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating promotion: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final docId = (_originalData['id'] ?? widget.promotionData['id'] ?? '--').toString();
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    // City-wise access verification
    final scope = ref.watch(cityAccessScopeProvider);
    final pincodesMap = ref.watch(propertyPincodesProvider).valueOrNull ?? const {};
    final isAllowed = scope.isUnrestricted ||
        (scope.isAuthorized &&
            scope.allowsRecord(widget.promotionData, pincodesMap: pincodesMap) &&
            scope.allowsRecord(_originalData, pincodesMap: pincodesMap));

    if (!isAllowed) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Edit Promotional Details',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: isMobile ? 16 : 18),
          ),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0F172A),
          elevation: 0,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded, size: 40, color: Color(0xFFEF4444)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to view or edit promotional details for this assigned city.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Edit Promotional Details',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: isMobile ? 16 : 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  'Save Changes',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: ResponsiveBreakpoints.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Overview Card
            _buildTopOverviewCard(docId: docId),
            const SizedBox(height: 24),

            // A. Promotion Information
            _buildSectionCard(
              title: 'A. Promotion Information',
              subtitle: 'Core brand identity, plan details, and unique identifiers',
              icon: Icons.campaign_rounded,
              iconColor: const Color(0xFF0284C7),
              child: ResponsiveWrapGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 2,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildTextField(
                    controller: _brandNameController,
                    label: 'Brand Name',
                    firestoreKey: 'brandName',
                  ),
                  _buildTextField(
                    controller: _activePlanController,
                    label: 'Active Plan',
                    firestoreKey: 'activePlan',
                  ),
                  _buildTextField(
                    controller: _transactionIdController,
                    label: 'Transaction ID',
                    firestoreKey: 'transactionId',
                  ),
                  _buildTextField(
                    controller: _uidController,
                    label: 'Provider UID (User ID)',
                    firestoreKey: 'uid',
                  ),
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Description',
                    firestoreKey: 'description',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // B. Contact Information
            _buildSectionCard(
              title: 'B. Contact Information',
              subtitle: 'Business phone, physical address, and social links',
              icon: Icons.contact_phone_rounded,
              iconColor: const Color(0xFF10B981),
              child: ResponsiveWrapGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 2,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildTextField(
                    controller: _mobileNumberController,
                    label: 'Mobile Number',
                    firestoreKey: 'mobileNumber',
                    keyboardType: TextInputType.phone,
                  ),
                  _buildTextField(
                    controller: _cityController,
                    label: 'City',
                    firestoreKey: 'city',
                  ),
                  _buildTextField(
                    controller: _addressController,
                    label: 'Full Address',
                    firestoreKey: 'address',
                    maxLines: 2,
                  ),
                  _buildTextField(
                    controller: _socialLinksController,
                    label: 'Social Links / Web URL',
                    firestoreKey: 'socialLinks',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // C. Images and Media
            _buildSectionCard(
              title: 'C. Images and Media',
              subtitle: 'Promotional banner and logo URLs with live previews',
              icon: Icons.photo_library_rounded,
              iconColor: const Color(0xFF8B5CF6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Preview & Input
                  _buildImagePreviewAndInput(
                    label: 'Banner Image',
                    firestoreKey: 'bannerUrl',
                    controller: _bannerUrlController,
                    aspectRatio: 16 / 7,
                    placeholderIcon: Icons.panorama_rounded,
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 16),

                  // Logo Preview & Input
                  _buildImagePreviewAndInput(
                    label: 'Logo Image',
                    firestoreKey: 'logoUrl',
                    controller: _logoUrlController,
                    aspectRatio: 1 / 1,
                    imageWidth: 140,
                    placeholderIcon: Icons.storefront_rounded,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // D. Promotion Performance
            _buildSectionCard(
              title: 'D. Promotion Performance',
              subtitle: 'Views, clicks, contacts, and reach limits (live counters protected)',
              icon: Icons.insights_rounded,
              iconColor: const Color(0xFFF59E0B),
              child: ResponsiveWrapGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 3,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildTextField(
                    controller: _viewsController,
                    label: 'Views (views / viewsCount)',
                    firestoreKey: 'views',
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(
                    controller: _clicksController,
                    label: 'Clicks (clicks / clicksCount)',
                    firestoreKey: 'clicks',
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(
                    controller: _contactedCountController,
                    label: 'Contacted Count',
                    firestoreKey: 'contactedCount',
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(
                    controller: _targetViewsController,
                    label: 'Target Views',
                    firestoreKey: 'targetViews',
                    keyboardType: TextInputType.number,
                  ),
                  _buildTextField(
                    controller: _maxViewsController,
                    label: 'Max Views',
                    firestoreKey: 'maxViews',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // E. Promotion Status
            _buildSectionCard(
              title: 'E. Promotion Status',
              subtitle: 'Verification, local banner, payment dispatch flags, and visibility',
              icon: Icons.toggle_on_rounded,
              iconColor: const Color(0xFF06B6D4),
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Verified Promotion',
                    firestoreKey: 'isVerified',
                    subtitle: 'Admin badge signifying verified vendor/promotion',
                    value: _isVerified,
                    onChanged: (val) => setState(() => _isVerified = val),
                  ),
                  const Divider(color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Local Banner',
                    firestoreKey: 'islocalbbaner',
                    subtitle: 'Designates promotion for local banner placements',
                    value: _islocalbbaner,
                    onChanged: (val) => setState(() => _islocalbbaner = val),
                  ),
                  const Divider(color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Payment Initiated',
                    firestoreKey: 'paymentInitiated',
                    subtitle: 'Indicates user/system has triggered payment checkout',
                    value: _paymentInitiated,
                    onChanged: (val) => setState(() => _paymentInitiated = val),
                  ),
                  const Divider(color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Payment Link Sent',
                    firestoreKey: 'paymentLinkSend',
                    subtitle: 'Payment link has been dispatched to customer',
                    value: _paymentLinkSend,
                    onChanged: (val) => setState(() => _paymentLinkSend = val),
                  ),
                  const Divider(color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Visible on App',
                    firestoreKey: 'isVisible',
                    subtitle: 'Controls whether promotion appears in customer app feeds',
                    value: _isVisible,
                    onChanged: (val) => setState(() => _isVisible = val),
                  ),
                  const Divider(color: Color(0xFFF1F5F9)),
                  _buildSwitchTile(
                    title: 'Boosted Promotion',
                    firestoreKey: 'isBoosted',
                    subtitle: 'Prominently highlighted in search and top spots',
                    value: _isBoosted,
                    onChanged: (val) => setState(() => _isBoosted = val),
                  ),
                  const Divider(color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),
                  _buildDropdownField(
                    label: 'Workflow Status',
                    firestoreKey: 'status',
                    value: _status,
                    options: const ['under_review', 'live', 'rejected', 'hidden'],
                    onChanged: (val) => setState(() => _status = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // F. Payment and Expiry Information
            _buildSectionCard(
              title: 'F. Payment and Expiry Information',
              subtitle: 'Transaction date, expiry timestamp, active plan, and transaction ID',
              icon: Icons.payments_rounded,
              iconColor: const Color(0xFFEC4899),
              child: ResponsiveWrapGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 2,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildDateTimePickerField(
                    label: 'Payment Date',
                    firestoreKey: 'paymentDate',
                    dateTime: _paymentDate,
                    onSelected: (dt) => setState(() => _paymentDate = dt),
                    onCleared: () => setState(() => _paymentDate = null),
                  ),
                  _buildDateTimePickerField(
                    label: 'Plan Expiry Date',
                    firestoreKey: 'planExpiredDate',
                    dateTime: _planExpiredDate,
                    onSelected: (dt) => setState(() => _planExpiredDate = dt),
                    onCleared: () => setState(() => _planExpiredDate = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // G. Location Information
            _buildSectionCard(
              title: 'G. Location Information',
              subtitle: 'Geohash and Firestore GeoPoint coordinates (latitude & longitude)',
              icon: Icons.location_on_rounded,
              iconColor: const Color(0xFFEF4444),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ResponsiveWrapGrid(
                    mobileColumns: 1,
                    tabletColumns: 3,
                    desktopColumns: 3,
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildTextField(
                        controller: _geohashController,
                        label: 'Geohash',
                        firestoreKey: 'location.geohash',
                      ),
                      _buildTextField(
                        controller: _latitudeController,
                        label: 'Latitude (GeoPoint)',
                        firestoreKey: 'location.geopoint.latitude',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                      _buildTextField(
                        controller: _longitudeController,
                        label: 'Longitude (GeoPoint)',
                        firestoreKey: 'location.geopoint.longitude',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        final lat = _latitudeController.text.trim();
                        final lng = _longitudeController.text.trim();
                        if (lat.isNotEmpty && lng.isNotEmpty) {
                          _copyToClipboard('GeoPoint Coordinates', '$lat, $lng');
                        } else {
                          _copyToClipboard('GeoPoint Coordinates', '');
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: Text(
                        'Copy GeoPoint (Lat, Lng)',
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF0284C7)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // H. Date Information
            _buildSectionCard(
              title: 'H. Date Information',
              subtitle: 'Original creation timestamp and last updated timestamp (Firestore Timestamp)',
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF64748B),
              child: ResponsiveWrapGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 2,
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildReadOnlyDateField(
                    label: 'Created Date',
                    firestoreKey: 'createdAt',
                    dateTime: _createdAt,
                  ),
                  _buildReadOnlyDateField(
                    label: 'Timestamp (Last Event/Update)',
                    firestoreKey: 'timestamp',
                    dateTime: _timestamp,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sales Feedback Section
            _buildSectionCard(
              title: 'Sales Team Feedback & Notes',
              subtitle: 'Internal remarks, CRM follow-ups, and special instructions',
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF6366F1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField(
                    controller: _salesFeedbackController,
                    label: 'Notes / Remarks',
                    firestoreKey: 'salesFeedback',
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            // Bottom Save Button Bar
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveChanges,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Saving Changes...' : 'Save All Changes',
                      style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// TOP OVERVIEW CARD
  /// ---------------------------------------------------------------------------
  Widget _buildTopOverviewCard({required String docId}) {
    final brand = _brandNameController.text.trim().isNotEmpty
        ? _brandNameController.text.trim()
        : 'Untitled Promotion';
    final city = _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : 'Unknown City';
    final uid = _uidController.text.trim().isNotEmpty ? _uidController.text.trim() : '--';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.campaign_rounded, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // City Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 11, color: Colors.white70),
                              const SizedBox(width: 3),
                              Text(
                                city,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Verification Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _isVerified
                                ? const Color(0xFF10B981).withValues(alpha: 0.25)
                                : const Color(0xFFEF4444).withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _isVerified ? 'VERIFIED' : 'UNVERIFIED',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: _isVerified ? const Color(0xFF34D399) : const Color(0xFFF87171),
                            ),
                          ),
                        ),
                        // Local Banner Badge
                        if (_islocalbbaner)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'LOCAL BANNER',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),

          // Document ID & Provider UID Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final chipMaxWidth = constraints.maxWidth > 50 ? constraints.maxWidth - 8 : 200.0;
              return Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => _copyToClipboard('Document ID', docId),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chipMaxWidth),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tag_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Doc ID: $docId',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFFCBD5E1),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => _copyToClipboard('Provider UID', uid),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: chipMaxWidth),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'UID: $uid',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: const Color(0xFFCBD5E1),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// SECTION CARD WRAPPER
  /// ---------------------------------------------------------------------------
  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// REUSABLE TEXT FIELD WITH FIRESTORE KEY BADGE AND COPY BUTTON
  /// ---------------------------------------------------------------------------
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String firestoreKey,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      firestoreKey,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
              tooltip: 'Copy $label',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copyToClipboard(label, controller.text),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: GoogleFonts.poppins(fontSize: 13.5, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// IMAGE PREVIEW AND URL INPUT
  /// ---------------------------------------------------------------------------
  Widget _buildImagePreviewAndInput({
    required String label,
    required String firestoreKey,
    required TextEditingController controller,
    required double aspectRatio,
    double? imageWidth,
    required IconData placeholderIcon,
  }) {
    final url = controller.text.trim();
    final hasValidUrl = url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      firestoreKey,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
              tooltip: 'Copy Complete $label URL',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copyToClipboard(label, url),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Live Image Preview Card
        Container(
          width: imageWidth ?? double.infinity,
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasValidUrl
              ? AspectRatio(
                  aspectRatio: aspectRatio,
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7)),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image_rounded, size: 36, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 6),
                          Text(
                            'Invalid or unreachable image URL',
                            style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : AspectRatio(
                  aspectRatio: aspectRatio,
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(placeholderIcon, size: 40, color: const Color(0xFFCBD5E1)),
                        const SizedBox(height: 6),
                        Text(
                          'No $label URL provided',
                          style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 10),

        // URL Input Field
        TextField(
          controller: controller,
          style: GoogleFonts.poppins(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Paste complete $label image URL here...',
            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            prefixIcon: const Icon(Icons.link_rounded, size: 18, color: Color(0xFF94A3B8)),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFF94A3B8)),
                    onPressed: () {
                      controller.clear();
                      setState(() {});
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// STATUS SWITCH TILE
  /// ---------------------------------------------------------------------------
  Widget _buildSwitchTile({
    required String title,
    required String firestoreKey,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        firestoreKey,
                        style: GoogleFonts.poppins(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
            tooltip: 'Copy $title value',
            onPressed: () => _copyToClipboard(title, value.toString()),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFF0284C7),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------------------
  /// DROPDOWN FIELD
  /// ---------------------------------------------------------------------------
  Widget _buildDropdownField({
    required String label,
    required String firestoreKey,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
  }) {
    final effectiveValue = options.contains(value) ? value : options.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      firestoreKey,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
              tooltip: 'Copy $label',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copyToClipboard(label, value),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: effectiveValue,
              isExpanded: true,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F172A),
              ),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
              items: options
                  .map((opt) => DropdownMenuItem(
                        value: opt,
                        child: Text(opt.toUpperCase()),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// DATE & TIME PICKER FIELD (WITH CLEAR AND COPY BUTTONS)
  /// ---------------------------------------------------------------------------
  Widget _buildDateTimePickerField({
    required String label,
    required String firestoreKey,
    required DateTime? dateTime,
    required void Function(DateTime?) onSelected,
    required VoidCallback onCleared,
  }) {
    final formatted = dateTime != null ? DateFormat('dd MMM yyyy, hh:mm a').format(dateTime) : 'Not Set (null)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      firestoreKey,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
              tooltip: 'Copy $label',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copyToClipboard(label, dateTime != null ? dateTime.toIso8601String() : 'null'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatted,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: dateTime != null ? FontWeight.w600 : FontWeight.w400,
                    color: dateTime != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _pickDateTime(
                  context: context,
                  initialDateTime: dateTime,
                  onSelected: onSelected,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0284C7),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Change'),
              ),
              if (dateTime != null)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 16, color: Color(0xFFEF4444)),
                  tooltip: 'Clear (set to null)',
                  onPressed: onCleared,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// ---------------------------------------------------------------------------
  /// READ-ONLY DATE FIELD
  /// ---------------------------------------------------------------------------
  Widget _buildReadOnlyDateField({
    required String label,
    required String firestoreKey,
    required DateTime? dateTime,
  }) {
    final formatted = dateTime != null
        ? DateFormat('dd MMM yyyy, hh:mm:ss a').format(dateTime)
        : 'Not Available / Null';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF334155),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      firestoreKey,
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF94A3B8)),
              tooltip: 'Copy $label',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => _copyToClipboard(label, formatted),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: Color(0xFF64748B)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatted,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
