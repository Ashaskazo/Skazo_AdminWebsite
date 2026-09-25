import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  late TextEditingController _businessPincodeController;
  late TextEditingController _businessLocationController;
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
  late TextEditingController _extraPlanChargeController;
  late TextEditingController _deactivationReasonController;
  late TextEditingController _aadhaarNumberController;
  late TextEditingController _aadhaarCardUrlController;
  late TextEditingController _panNumberController;
  late TextEditingController _panCardUrlController;
  late TextEditingController _businessPicController;
  late TextEditingController _businessPicsController;
  late TextEditingController _cityController;
  late TextEditingController _cityKeyController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;

  // ---------------------------------------------------------------------------
  // REAL-TIME DOCUMENT STATE
  // ---------------------------------------------------------------------------

  /// Exactly one realtime listener for the currently opened /users/{docId}.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDocumentSubscription;

  /// Latest Firestore document received by the realtime listener.
  Map<String, dynamic>? _liveData;

  /// Whether the Firestore listener is currently receiving snapshots.
  bool _isRealtimeConnected = false;

  /// Whether the currently opened Firestore document was deleted.
  bool _isDocumentDeleted = false;

  /// True while controller/status values are being populated from Firestore.
  /// Prevents those programmatic changes from being treated as admin edits.
  bool _applyingLiveData = false;

  /// True only while the explicit Save operation is running.
  bool _isSaving = false;

  /// Tracks whether the admin has changed anything locally that has not
  /// successfully been persisted to Firestore.
  bool _hasUnsavedChanges = false;

  /// Snapshot waiting to be applied after local edits are saved.
  Map<String, dynamic>? _pendingRealtimeData;

  // Editable Service Rate Card
  late List<_ServiceRateCardItemControllers> _serviceRateCardControllers;

  // Editable Categories
  late List<String> _categories;
  final TextEditingController _newCategoryController = TextEditingController();

  // Editable Category Priority map (category name -> priority int)
  late Map<String, TextEditingController> _categoryPriorityControllers;

  // Star Service Provider as string "0" or "1"
  late TextEditingController _starServiceProviderController;

  // Status variables
  late bool _isVerified;
  late bool _isActive;
  late bool _isProviderTemperoryDeactivatedStatus;
  late bool _basicPlanEnable;
  late bool _priority;
  late bool _isOnline;
  late bool _isUser;
  late bool _profileComplete;
  late bool _categoryBoostEnabled;
  late bool _paymentLinkSend;
  DateTime? _deactivatedAt;
  DateTime? _lastPaymentAt;
  DateTime? _paymentDate;

  @override
  void initState() {
    super.initState();
    final data = widget.businessData;

    _nameController = TextEditingController(
      text: data['businessname']?.toString() ?? '',
    );
    _bioController = TextEditingController(
      text: data['businessbio']?.toString() ?? '',
    );
    _addressController = TextEditingController(
      text:
          data['businessaddress']?.toString() ??
          data['address']?.toString() ??
          '',
    );
    _businessPincodeController = TextEditingController(
      text:
          (data['businessPincode'] ??
                  data['business_pincode'] ??
                  data['pincode'])
              ?.toString() ??
          '',
    );
    _businessLocationController = TextEditingController(
      text: data['businessLocation']?.toString() ?? '',
    );
    _firstNameController = TextEditingController(
      text: data['firstname']?.toString() ?? '',
    );
    _lastNameController = TextEditingController(
      text: data['lastname']?.toString() ?? '',
    );
    _phoneController = TextEditingController(
      text: data['phone']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: data['email']?.toString() ?? '',
    );
    _planController = TextEditingController(
      text: (data['AtivePlan'] ?? data['ActivePlan'])?.toString() ?? '0',
    );
    _priorityController = TextEditingController(
      text: data['priority']?.toString() ?? '0',
    );
    _genderController = TextEditingController(
      text: data['gender']?.toString() ?? '',
    );
    _usernameController = TextEditingController(
      text: data['username']?.toString() ?? '',
    );
    _ownerPaidController = TextEditingController(
      text: data['ownerPropertyPaid']?.toString() ?? '0',
    );
    _userPaidController = TextEditingController(
      text: data['userPropertyPaid']?.toString() ?? '0',
    );
    _fcmTokenController = TextEditingController(
      text: data['fcmtoken']?.toString() ?? '',
    );
    _totalAmountController = TextEditingController(
      text: data['totalAmount']?.toString() ?? '0',
    );
    _transactionIdController = TextEditingController(
      text: data['transactionId']?.toString() ?? '',
    );
    _paymentPlanController = TextEditingController(
      text: data['paymentPlanDuration']?.toString() ?? '',
    );
    _paymentCountController = TextEditingController(
      text: data['paymentCount']?.toString() ?? '0',
    );

    final rawLeadCharge =
        data['payperLeadcharge'] ??
        data['payperLeadCharge'] ??
        data['payPerLeadCharge'];
    _payPerLeadChargeController = TextEditingController(
      text: rawLeadCharge?.toString() ?? '',
    );

    final rawExtraPlan = data['extraPlanCharge'];
    _extraPlanChargeController = TextEditingController(
      text: rawExtraPlan?.toString() ?? '0',
    );

    _deactivationReasonController = TextEditingController(
      text: data['deactivationReason']?.toString() ?? '',
    );

    _aadhaarNumberController = TextEditingController(
      text: data['aadhaarNumber']?.toString() ?? '',
    );
    _aadhaarCardUrlController = TextEditingController(
      text: data['aadhaarCardUrl']?.toString() ?? '',
    );
    _panNumberController = TextEditingController(
      text: data['panNumber']?.toString() ?? '',
    );
    _panCardUrlController = TextEditingController(
      text: data['panCardUrl']?.toString() ?? '',
    );

    _businessPicController = TextEditingController(
      text: data['businesspic']?.toString() ?? '',
    );
    _businessPicsController = TextEditingController(
      text: _stringListToMultiline(data['businesspics']),
    );
    _cityController = TextEditingController(
      text: data['city']?.toString() ?? data['City']?.toString() ?? '',
    );
    _cityKeyController = TextEditingController(
      text: data['cityKey']?.toString() ?? '',
    );

    final initialCoordinates = _extractCoordinates(data);
    _latitudeController = TextEditingController(text: initialCoordinates.$1);
    _longitudeController = TextEditingController(text: initialCoordinates.$2);

    _deactivatedAt = _parseDateTime(data['deactivatedAt']);
    _lastPaymentAt = _parseDateTime(data['lastPaymentAt']);
    _paymentDate = _parseDateTime(data['paymentDate']);

    // Parse Service Rate Card
    _serviceRateCardControllers = [];
    final rawRateCard = data['ServiceRateCard'] ?? data['serviceRateCard'];
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

    // Parse Categories
    _categories = [];
    final rawCats = data['category'];
    if (rawCats is List) {
      for (var c in rawCats) {
        if (c != null && c.toString().trim().isNotEmpty) {
          _categories.add(c.toString().trim());
        }
      }
    } else if (rawCats is String && rawCats.trim().isNotEmpty) {
      _categories.add(rawCats.trim());
    }

    // Parse Category Priority map
    _categoryPriorityControllers = {};
    final rawCatPriority = data['categoryPriority'];
    if (rawCatPriority is Map) {
      rawCatPriority.forEach((k, v) {
        _categoryPriorityControllers[k.toString()] = TextEditingController(
          text: v?.toString() ?? '0',
        );
      });
    }
    for (final cat in _categories) {
      if (!_categoryPriorityControllers.containsKey(cat)) {
        final controller = TextEditingController(text: '0');
        _categoryPriorityControllers[cat] = controller;
        _attachDirtyListener(controller);
      }
    }

    // Star Service Provider
    final rawStar = data['StarServiceprovider'] ?? data['starServiceProvider'];
    _starServiceProviderController = TextEditingController(
      text: rawStar?.toString() ?? '0',
    );

    _isVerified =
        data['isverified'] == true ||
        data['isverified'] == 'true' ||
        data['isverified'] == 1;

    // Deactivation and Active state
    final isDeactivatedRaw =
        data['isProviderDeativatedStatus'] == true ||
        data['isProviderDeativatedStatus'] == 'true' ||
        data['isDeactivated'] == true ||
        data['isDeactivated'] == 'true';
    final isActiveRaw =
        data['isactive'] == true ||
        data['isactive'] == 'true' ||
        data['isactive'] == 1;

    _isActive = !isDeactivatedRaw && isActiveRaw;
    _isProviderTemperoryDeactivatedStatus =
        data['isProviderTemperoryDeactivatedStatus'] == true ||
        data['isProviderTemperoryDeactivatedStatus'] == 'true';

    _basicPlanEnable =
        data['basicplanenable'] == true || data['basicplanenable'] == 'true';
    _priority =
        data['priority'] == true ||
        data['priority'] == 1 ||
        data['priority'] == '1' ||
        data['priority'] == 'true';
    _isOnline = data['isonline'] == true || data['isonline'] == 'true';
    _profileComplete =
        data['profileComplete'] == true || data['profileComplete'] == 'true';
    _categoryBoostEnabled =
        data['categoryBoostEnabled'] == true ||
        data['categoryBoostEnabled'] == 'true';
    _paymentLinkSend =
        data['paymentLinkSend'] == true || data['paymentLinkSend'] == 'true';

    if (data.containsKey('isuser') && data['isuser'] != null) {
      _isUser =
          data['isuser'] == true ||
          data['isuser'] == 'true' ||
          data['isuser'] == 1;
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

    // Keep the page attached to exactly one Firestore document.
    _liveData = Map<String, dynamic>.from(data);
    _attachDirtyListeners();
    _startRealtimeListener();
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _addressController.dispose();
    _businessPincodeController.dispose();
    _businessLocationController.dispose();
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
    _extraPlanChargeController.dispose();
    _deactivationReasonController.dispose();
    _aadhaarNumberController.dispose();
    _aadhaarCardUrlController.dispose();
    _panNumberController.dispose();
    _panCardUrlController.dispose();
    _businessPicController.dispose();
    _businessPicsController.dispose();
    _cityController.dispose();
    _cityKeyController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _newCategoryController.dispose();
    _starServiceProviderController.dispose();

    for (var item in _serviceRateCardControllers) {
      item.dispose();
    }
    for (final ctrl in _categoryPriorityControllers.values) {
      ctrl.dispose();
    }

    _userDocumentSubscription?.cancel();
    super.dispose();
  }

  String? _documentId() {
    final raw =
        widget.businessData['id'] ??
        widget.businessData['uid'] ??
        widget.businessData['docId'];
    final value = raw?.toString().trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String _stringListToMultiline(dynamic value) {
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .join('\n');
    }
    if (value == null) return '';
    return value.toString();
  }

  List<String> _multilineToStringList(String value) {
    return value
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  void _markDirty() {
    if (_applyingLiveData || !mounted) return;

    if (!_hasUnsavedChanges) {
      setState(() {
        _hasUnsavedChanges = true;
      });
    } else {
      // Already dirty. No need to rebuild again just for the flag.
      _hasUnsavedChanges = true;
    }
  }

  void _attachDirtyListener(TextEditingController controller) {
    controller.addListener(_markDirty);
  }

  void _attachDirtyListeners() {
    final controllers = <TextEditingController>[
      _nameController,
      _bioController,
      _addressController,
      _businessPincodeController,
      _businessLocationController,
      _firstNameController,
      _lastNameController,
      _phoneController,
      _emailController,
      _planController,
      _priorityController,
      _genderController,
      _usernameController,
      _ownerPaidController,
      _userPaidController,
      _fcmTokenController,
      _totalAmountController,
      _transactionIdController,
      _paymentPlanController,
      _paymentCountController,
      _payPerLeadChargeController,
      _extraPlanChargeController,
      _deactivationReasonController,
      _aadhaarNumberController,
      _aadhaarCardUrlController,
      _panNumberController,
      _panCardUrlController,
      _businessPicController,
      _businessPicsController,
      _cityController,
      _cityKeyController,
      _latitudeController,
      _longitudeController,
      _starServiceProviderController,
      _newCategoryController,
    ];

    for (final controller in controllers) {
      _attachDirtyListener(controller);
    }

    for (final item in _serviceRateCardControllers) {
      _attachDirtyListener(item.serviceController);
      _attachDirtyListener(item.rateController);
    }

    for (final controller in _categoryPriorityControllers.values) {
      _attachDirtyListener(controller);
    }
  }

  void _startRealtimeListener() {
    final docId = _documentId();

    if (docId == null) {
      debugPrint(
        'BusinessProfilePage: Cannot start realtime listener. '
        'Document ID is missing.',
      );
      return;
    }

    // Always cancel the previous listener before creating another one.
    _userDocumentSubscription?.cancel();
    _userDocumentSubscription = null;

    final docRef = FirebaseFirestore.instance.collection('users').doc(docId);

    debugPrint(
      'BusinessProfilePage: Starting realtime listener for users/$docId',
    );

    _userDocumentSubscription = docRef.snapshots().listen(
      (snapshot) {
        if (!mounted) return;

        // ---------------------------------------------------------------------
        // DOCUMENT DELETED
        // ---------------------------------------------------------------------
        if (!snapshot.exists) {
          debugPrint('BusinessProfilePage: users/$docId no longer exists.');

          setState(() {
            _isDocumentDeleted = true;
            _isRealtimeConnected = true;
            _liveData = null;
            _pendingRealtimeData = null;
          });

          return;
        }

        // ---------------------------------------------------------------------
        // FIRESTORE SNAPSHOT
        // ---------------------------------------------------------------------
        final incoming = <String, dynamic>{
          ...?snapshot.data(),
          'id': snapshot.id,
        };

        debugPrint(
          'BusinessProfilePage: realtime snapshot received for users/$docId '
          '(hasPendingWrites=${snapshot.metadata.hasPendingWrites}, '
          'fromCache=${snapshot.metadata.isFromCache})',
        );

        // Always keep the newest Firestore document.
        _liveData = incoming;

        // ---------------------------------------------------------------------
        // LOCAL UNSAVED EDITS
        // ---------------------------------------------------------------------
        //
        // Never overwrite the administrator's unsaved form.
        //
        // Example:
        // Admin changes business name locally.
        // Firebase Console changes phone number.
        //
        // Result:
        // - business name remains the admin's unsaved value
        // - phone is updated immediately from Firestore
        //
        // For now the page uses a single dirty boundary for the editable form,
        // so we preserve the complete editable form while dirty.
        if (_hasUnsavedChanges) {
          _pendingRealtimeData = incoming;

          if (mounted) {
            setState(() {
              _isDocumentDeleted = false;
              _isRealtimeConnected = true;
            });
          }

          debugPrint(
            'BusinessProfilePage: realtime update stored as pending because '
            'the form contains unsaved local changes.',
          );

          return;
        }

        // ---------------------------------------------------------------------
        // SAFE TO APPLY FIRESTORE STATE
        // ---------------------------------------------------------------------
        _applyingLiveData = true;

        try {
          _syncEditableStateFromFirestore(incoming);
        } catch (error, stackTrace) {
          debugPrint(
            'BusinessProfilePage: failed to apply realtime snapshot: $error',
          );
          debugPrintStack(stackTrace: stackTrace);
        } finally {
          _applyingLiveData = false;
        }

        if (!mounted) return;

        setState(() {
          _liveData = incoming;
          _isDocumentDeleted = false;
          _isRealtimeConnected = true;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;

        debugPrint('BusinessProfilePage realtime listener error: $error');
        debugPrintStack(stackTrace: stackTrace);

        setState(() {
          _isRealtimeConnected = false;
        });
      },
      cancelOnError: false,
    );
  }
void _applyFirestoreSnapshotToUi(
  Map<String, dynamic> data, {
  bool clearDirtyState = false,
}) {
  if (!mounted) return;

  _applyingLiveData = true;

  try {
    _syncEditableStateFromFirestore(data);

    _liveData = Map<String, dynamic>.from(data);

    if (clearDirtyState) {
      _hasUnsavedChanges = false;
      _pendingRealtimeData = null;
    }
  } finally {
    _applyingLiveData = false;
  }

  if (!mounted) return;

  setState(() {
    _liveData = Map<String, dynamic>.from(data);
    _isDocumentDeleted = false;
    _isRealtimeConnected = true;

    if (clearDirtyState) {
      _hasUnsavedChanges = false;
      _pendingRealtimeData = null;
    }
  });
}
  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _syncEditableStateFromFirestore(Map<String, dynamic> data) {
    _setControllerText(_nameController, data['businessname']?.toString() ?? '');
    _setControllerText(_bioController, data['businessbio']?.toString() ?? '');
    _setControllerText(
      _addressController,
      data['businessaddress']?.toString() ?? data['address']?.toString() ?? '',
    );
    _setControllerText(
      _businessPincodeController,
      (data['businessPincode'] ?? data['business_pincode'] ?? data['pincode'])
              ?.toString() ??
          '',
    );
    _setControllerText(
      _businessLocationController,
      data['businessLocation']?.toString() ?? '',
    );
    _setControllerText(
      _firstNameController,
      data['firstname']?.toString() ?? '',
    );
    _setControllerText(_lastNameController, data['lastname']?.toString() ?? '');
    _setControllerText(_phoneController, data['phone']?.toString() ?? '');
    _setControllerText(_emailController, data['email']?.toString() ?? '');
    _setControllerText(
      _planController,
      (data['AtivePlan'] ?? data['ActivePlan'])?.toString() ?? '0',
    );
    _setControllerText(
      _priorityController,
      data['priority']?.toString() ?? '0',
    );
    _setControllerText(_genderController, data['gender']?.toString() ?? '');
    _setControllerText(_usernameController, data['username']?.toString() ?? '');
    _setControllerText(
      _ownerPaidController,
      data['ownerPropertyPaid']?.toString() ?? '0',
    );
    _setControllerText(
      _userPaidController,
      data['userPropertyPaid']?.toString() ?? '0',
    );
    _setControllerText(_fcmTokenController, data['fcmtoken']?.toString() ?? '');
    _setControllerText(
      _totalAmountController,
      data['totalAmount']?.toString() ?? '0',
    );
    _setControllerText(
      _transactionIdController,
      data['transactionId']?.toString() ?? '',
    );
    _setControllerText(
      _paymentPlanController,
      data['paymentPlanDuration']?.toString() ?? '',
    );
    _setControllerText(
      _paymentCountController,
      data['paymentCount']?.toString() ?? '0',
    );
    _setControllerText(
      _payPerLeadChargeController,
      (data['payperLeadcharge'] ??
                  data['payperLeadCharge'] ??
                  data['payPerLeadCharge'])
              ?.toString() ??
          '',
    );
    _setControllerText(
      _extraPlanChargeController,
      data['extraPlanCharge']?.toString() ?? '0',
    );
    _setControllerText(
      _deactivationReasonController,
      data['deactivationReason']?.toString() ?? '',
    );
    _setControllerText(
      _aadhaarNumberController,
      data['aadhaarNumber']?.toString() ?? '',
    );
    _setControllerText(
      _aadhaarCardUrlController,
      data['aadhaarCardUrl']?.toString() ?? '',
    );
    _setControllerText(
      _panNumberController,
      data['panNumber']?.toString() ?? '',
    );
    _setControllerText(
      _panCardUrlController,
      data['panCardUrl']?.toString() ?? '',
    );
    _setControllerText(
      _businessPicController,
      data['businesspic']?.toString() ?? '',
    );
    _setControllerText(
      _businessPicsController,
      _stringListToMultiline(data['businesspics']),
    );
    _setControllerText(
      _cityController,
      data['city']?.toString() ?? data['City']?.toString() ?? '',
    );
    _setControllerText(_cityKeyController, data['cityKey']?.toString() ?? '');

    final coordinates = _extractCoordinates(data);
    _setControllerText(_latitudeController, coordinates.$1);
    _setControllerText(_longitudeController, coordinates.$2);

    final rawStar = data['StarServiceprovider'] ?? data['starServiceProvider'];
    _setControllerText(
      _starServiceProviderController,
      rawStar?.toString() ?? '0',
    );

    _isVerified =
        data['isverified'] == true ||
        data['isverified'] == 'true' ||
        data['isverified'] == 1;

    final isDeactivatedRaw =
        data['isProviderDeativatedStatus'] == true ||
        data['isProviderDeativatedStatus'] == 'true' ||
        data['isDeactivated'] == true ||
        data['isDeactivated'] == 'true';

    final isActiveRaw =
        data['isactive'] == true ||
        data['isactive'] == 'true' ||
        data['isactive'] == 1;

    _isActive = !isDeactivatedRaw && isActiveRaw;

    _isProviderTemperoryDeactivatedStatus =
        data['isProviderTemperoryDeactivatedStatus'] == true ||
        data['isProviderTemperoryDeactivatedStatus'] == 'true';

    _basicPlanEnable =
        data['basicplanenable'] == true || data['basicplanenable'] == 'true';

    _priority =
        data['priority'] == true ||
        data['priority'] == 1 ||
        data['priority'] == '1' ||
        data['priority'] == 'true';

    _isOnline = data['isonline'] == true || data['isonline'] == 'true';

    _profileComplete =
        data['profileComplete'] == true || data['profileComplete'] == 'true';

    _categoryBoostEnabled =
        data['categoryBoostEnabled'] == true ||
        data['categoryBoostEnabled'] == 'true';

    _paymentLinkSend =
        data['paymentLinkSend'] == true || data['paymentLinkSend'] == 'true';

    _isUser =
        data['isuser'] == true ||
        data['isuser'] == 'true' ||
        data['isuser'] == 1;

    _deactivatedAt = _parseDateTime(data['deactivatedAt']);
    _lastPaymentAt = _parseDateTime(data['lastPaymentAt']);
    _paymentDate = _parseDateTime(data['paymentDate']);

    // Rebuild dynamic editors only when there are no unsaved changes.
    for (final item in _serviceRateCardControllers) {
      item.dispose();
    }
    _serviceRateCardControllers = [];

    final rawRateCard = data['ServiceRateCard'] ?? data['serviceRateCard'];
    if (rawRateCard is List) {
      for (final item in rawRateCard) {
        if (item is Map) {
          final controller = _ServiceRateCardItemControllers(
            service: item['service']?.toString() ?? '',
            rate: item['rate']?.toString() ?? '',
          );
          _serviceRateCardControllers.add(controller);
          _attachDirtyListener(controller.serviceController);
          _attachDirtyListener(controller.rateController);
        }
      }
    }

    _categories = [];
    final rawCats = data['category'];
    if (rawCats is List) {
      for (final cat in rawCats) {
        final value = cat?.toString().trim() ?? '';
        if (value.isNotEmpty) _categories.add(value);
      }
    } else if (rawCats is String && rawCats.trim().isNotEmpty) {
      _categories.add(rawCats.trim());
    }

    for (final controller in _categoryPriorityControllers.values) {
      controller.dispose();
    }
    _categoryPriorityControllers = {};

    final rawCatPriority = data['categoryPriority'];
    if (rawCatPriority is Map) {
      rawCatPriority.forEach((key, value) {
        final controller = TextEditingController(
          text: value?.toString() ?? '0',
        );
        _categoryPriorityControllers[key.toString()] = controller;
        _attachDirtyListener(controller);
      });
    }

    for (final cat in _categories) {
      if (!_categoryPriorityControllers.containsKey(cat)) {
        final controller = TextEditingController(text: '0');
        _categoryPriorityControllers[cat] = controller;
        _attachDirtyListener(controller);
      }
    }
  }

  void _addCategory(String cat) {
    final trimmed = cat.trim();
    if (trimmed.isEmpty || _categories.contains(trimmed)) return;
    _markDirty();
    setState(() {
      _categories.add(trimmed);
      final controller = TextEditingController(text: '0');
      _categoryPriorityControllers[trimmed] = controller;
      _attachDirtyListener(controller);
    });
    _newCategoryController.clear();
  }

  void _removeCategory(String cat) {
    _markDirty();
    setState(() {
      _categories.remove(cat);
      _categoryPriorityControllers[cat]?.dispose();
      _categoryPriorityControllers.remove(cat);
    });
  }

  void _addServiceRateCardItem() {
    _markDirty();
    setState(() {
      final item = _ServiceRateCardItemControllers();
      _serviceRateCardControllers.add(item);
      _attachDirtyListener(item.serviceController);
      _attachDirtyListener(item.rateController);
    });
  }

  void _removeServiceRateCardItem(int index) {
    _markDirty();
    setState(() {
      final item = _serviceRateCardControllers.removeAt(index);
      item.dispose();
    });
  }

 Future<void> _saveChanges() async {
  if (_isSaving) return;

  if (!_formKey.currentState!.validate()) {
    return;
  }

  final docId = _documentId();

  if (docId == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Document ID is missing. Cannot update profile in Firebase.',
          ),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return;
  }

  setState(() {
    _isSaving = true;
    _isLoading = true;
  });

  try {
    // -----------------------------------------------------------------------
    // ADMIN INFORMATION
    // -----------------------------------------------------------------------

    final adminProfile =
        ref.read(currentAdminProfileProvider).value;

    final senderId =
        adminProfile?['admin_id'] ??
        adminProfile?['id'] ??
        'Unknown';

    final senderName =
        adminProfile?['name'] ?? 'Unknown';

    // -----------------------------------------------------------------------
    // PHONE
    // -----------------------------------------------------------------------

    final phoneText = _phoneController.text.trim();

    final dynamic phoneValue =
        phoneText.isEmpty
            ? null
            : (int.tryParse(phoneText) ?? phoneText);

    // -----------------------------------------------------------------------
    // PLAN
    // -----------------------------------------------------------------------

    final planVal =
        int.tryParse(_planController.text.trim()) ?? 0;

    // -----------------------------------------------------------------------
    // SERVICE RATE CARD
    // -----------------------------------------------------------------------

    final List<Map<String, String>> rateCardList = [];

    for (final item in _serviceRateCardControllers) {
      final serviceName =
          item.serviceController.text.trim();

      final rate =
          item.rateController.text.trim();

      if (serviceName.isNotEmpty || rate.isNotEmpty) {
        rateCardList.add({
          'service': serviceName,
          'rate': rate,
        });
      }
    }

    // -----------------------------------------------------------------------
    // PAY PER LEAD
    // -----------------------------------------------------------------------

    final leadChargeText =
        _payPerLeadChargeController.text.trim();

    final num leadChargeValue =
        leadChargeText.isEmpty
            ? 0
            : (num.tryParse(leadChargeText) ?? 0);

    // -----------------------------------------------------------------------
    // EXTRA PLAN
    // -----------------------------------------------------------------------

    final extraPlanText =
        _extraPlanChargeController.text.trim();

    final num extraPlanValue =
        extraPlanText.isEmpty
            ? 0
            : (num.tryParse(extraPlanText) ?? 0);

    // -----------------------------------------------------------------------
    // COORDINATES
    // -----------------------------------------------------------------------

    final latitude =
        double.tryParse(_latitudeController.text.trim());

    final longitude =
        double.tryParse(_longitudeController.text.trim());

    if (latitude == null || longitude == null) {
      throw 'Latitude and longitude must be valid numbers.';
    }

    if (latitude < -90 || latitude > 90) {
      throw 'Latitude must be between -90 and 90.';
    }

    if (longitude < -180 || longitude > 180) {
      throw 'Longitude must be between -180 and 180.';
    }

    // -----------------------------------------------------------------------
    // CATEGORY PRIORITY
    // -----------------------------------------------------------------------

    final Map<String, dynamic> categoryPriorityMap = {};

    for (final entry
        in _categoryPriorityControllers.entries) {
      categoryPriorityMap[entry.key] =
          int.tryParse(entry.value.text.trim()) ?? 0;
    }

    // -----------------------------------------------------------------------
    // STAR PROVIDER
    // -----------------------------------------------------------------------

    final starValue =
        _starServiceProviderController.text.trim();

    final normalizedStar =
        starValue == '1' ? '1' : '0';

    // -----------------------------------------------------------------------
    // DEACTIVATION
    // -----------------------------------------------------------------------

    final bool isDeactivatedValue = !_isActive;

    // -----------------------------------------------------------------------
    // PAYMENT LINK STATE
    // -----------------------------------------------------------------------

    final bool previousPaymentLinkSent =
        (_liveData?['paymentLinkSend'] ??
                widget.businessData['paymentLinkSend']) ==
            true;

    // -----------------------------------------------------------------------
    // FIRESTORE UPDATE
    // -----------------------------------------------------------------------

    final Map<String, dynamic> updatedData = {
      'businessname':
          _nameController.text.trim(),

      'businessbio':
          _bioController.text.trim(),

      'businessaddress':
          _addressController.text.trim(),

      'businessPincode':
          _businessPincodeController.text.trim(),

      'businessLocation':
          _businessLocationController.text.trim(),

      'businesspic':
          _businessPicController.text.trim(),

      'businesspics':
          _multilineToStringList(
            _businessPicsController.text,
          ),

      'city':
          _cityController.text.trim(),

      'cityKey':
          _cityKeyController.text.trim(),

      'firstname':
          _firstNameController.text.trim(),

      'lastname':
          _lastNameController.text.trim(),

      'email':
          _emailController.text.trim(),

      'AtivePlan':
          planVal,

      'priority':
          _priority,

      'gender':
          _genderController.text.trim(),

      'username':
          _usernameController.text.trim(),

      'ownerPropertyPaid':
          int.tryParse(
                _ownerPaidController.text.trim(),
              ) ??
              0,

      'userPropertyPaid':
          int.tryParse(
                _userPaidController.text.trim(),
              ) ??
              0,

      'fcmtoken':
          _fcmTokenController.text.trim(),

      'isverified':
          _isVerified,

      'isactive':
          _isActive,

      'isProviderTemperoryDeactivatedStatus':
          _isProviderTemperoryDeactivatedStatus,

      'basicplanenable':
          _basicPlanEnable,

      'isonline':
          _isOnline,

      'isuser':
          _isUser,

      'profileComplete':
          _profileComplete,

      'categoryBoostEnabled':
          _categoryBoostEnabled,

      'paymentLinkSend':
          _paymentLinkSend,

      'StarServiceprovider':
          normalizedStar,

      'starServiceProvider':
          normalizedStar,

      'payperLeadcharge':
          leadChargeValue,

      'extraPlanCharge':
          extraPlanValue,

      'ServiceRateCard':
          rateCardList,

      'category':
          _categories,

      'categoryPriority':
          categoryPriorityMap,

      'coordinates':
          [latitude, longitude],

      // Preserve the rest of location.*
      // while updating only location.geopoint.
      'location.geopoint':
          GeoPoint(latitude, longitude),

      'transactionId':
          _transactionIdController.text.trim(),

      'paymentPlanDuration':
          _paymentPlanController.text.trim(),

      'paymentCount':
          int.tryParse(
                _paymentCountController.text.trim(),
              ) ??
              0,

      'totalAmount':
          int.tryParse(
                _totalAmountController.text.trim(),
              ) ??
              0,

      'aadhaarNumber':
          _aadhaarNumberController.text.trim(),

      'aadhaarCardUrl':
          _aadhaarCardUrlController.text.trim(),

      'panNumber':
          _panNumberController.text.trim(),

      'panCardUrl':
          _panCardUrlController.text.trim(),

      'lastPaymentAt':
          _lastPaymentAt != null
              ? Timestamp.fromDate(_lastPaymentAt!)
              : null,

      'paymentDate':
          _paymentDate != null
              ? Timestamp.fromDate(_paymentDate!)
              : null,

      'updatedAt':
          FieldValue.serverTimestamp(),
    };

    // -----------------------------------------------------------------------
    // DEACTIVATION DATA
    // -----------------------------------------------------------------------

    if (isDeactivatedValue) {
      updatedData['deactivatedAt'] =
          FieldValue.serverTimestamp();

      final reason =
          _deactivationReasonController.text.trim();

      if (reason.isNotEmpty) {
        updatedData['deactivationReason'] =
            reason;
      }
    }

    // -----------------------------------------------------------------------
    // PHONE
    // -----------------------------------------------------------------------

    if (phoneValue != null) {
      updatedData['phone'] = phoneValue;
    }

    // -----------------------------------------------------------------------
    // PAYMENT LINK AUDIT DATA
    // -----------------------------------------------------------------------

    if (_paymentLinkSend &&
        !previousPaymentLinkSent) {
      updatedData['paymentLinkSenderId'] =
          senderId;

      updatedData['paymentLinkSenderName'] =
          senderName;

      updatedData['paymentLinkSentAt'] =
          FieldValue.serverTimestamp();
    }

    final docRef =
        FirebaseFirestore.instance
            .collection('users')
            .doc(docId);

    debugPrint(
      'BusinessProfilePage: saving users/$docId',
    );

    // -----------------------------------------------------------------------
    // WRITE
    // -----------------------------------------------------------------------

    await docRef.update(updatedData);

    debugPrint(
      'BusinessProfilePage: Firestore update completed for users/$docId',
    );

    // -----------------------------------------------------------------------
    // IMPORTANT:
    //
    // Do NOT depend on the realtime listener to finish the save.
    //
    // Explicitly obtain the authoritative server document.
    // This eliminates the listener/update race.
    // -----------------------------------------------------------------------

    final authoritativeSnapshot =
        await docRef.get(
      const GetOptions(
        source: Source.server,
      ),
    );

    if (!authoritativeSnapshot.exists) {
      throw 'The user document disappeared immediately after save.';
    }

    final authoritativeData =
        <String, dynamic>{
      ...?authoritativeSnapshot.data(),
      'id': authoritativeSnapshot.id,
    };

    debugPrint(
      'BusinessProfilePage: authoritative server snapshot received '
      'for users/$docId',
    );

    // -----------------------------------------------------------------------
    // APPLY SERVER STATE TO UI
    // -----------------------------------------------------------------------

    _applyingLiveData = true;

    try {
      _syncEditableStateFromFirestore(
        authoritativeData,
      );

      _liveData =
          Map<String, dynamic>.from(
            authoritativeData,
          );

      _pendingRealtimeData = null;
      _hasUnsavedChanges = false;
    } finally {
      _applyingLiveData = false;
    }

    if (!mounted) return;

    setState(() {
      _liveData =
          Map<String, dynamic>.from(
            authoritativeData,
          );

      _isDocumentDeleted = false;
      _isRealtimeConnected = true;
      _hasUnsavedChanges = false;
      _pendingRealtimeData = null;
    });

    // -----------------------------------------------------------------------
    // SUCCESS
    // -----------------------------------------------------------------------

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.stars_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Text(
              'Profile updated successfully! ✨🚀',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        backgroundColor:
            const Color(0xFF10B981),
        behavior:
            SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(12),
        ),
      ),
    );
  } on FirebaseException catch (e) {
    debugPrint(
      'BusinessProfilePage Firestore save error: '
      '${e.code} - ${e.message}',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Failed to update profile: '
          '${e.message ?? e.code}',
        ),
        backgroundColor:
            const Color(0xFFEF4444),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  } catch (e, stackTrace) {
    debugPrint(
      'BusinessProfilePage save error: $e',
    );
    debugPrintStack(
      stackTrace: stackTrace,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Oops! Error updating profile: $e',
        ),
        backgroundColor:
            const Color(0xFFEF4444),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isSaving = false;
        _isLoading = false;
      });
    } else {
      _isSaving = false;
      _isLoading = false;
    }
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 38),
            child: Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
        ],
      ),
    );
  }

  Future<void> _selectDateTime({
    required DateTime? initialValue,
    required ValueChanged<DateTime?> onChanged,
  }) async {
    final now = DateTime.now();
    final initial = initialValue ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 20),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null) return;
    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedTime == null) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
      initialValue != null ? initialValue.second : 0,
    );
    onChanged(combined);
    _markDirty();
  }

  Widget _buildEditableDateTimeField({
    required String label,
    required DateTime? value,
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
    Color accentColor = const Color(0xFF10B981),
  }) {
    final formattedValue =
        value != null
            ? DateFormat('dd MMM yyyy, hh:mm:ss a').format(value)
            : 'Not set';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        ),
        child: Row(
          children: [
            Icon(icon, color: accentColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedValue,
                    style: GoogleFonts.poppins(
                      color:
                          value != null
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight:
                          value != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null && onClear != null)
              IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: onClear,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Clear $label',
              )
            else
              const Icon(
                Icons.edit_calendar_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
            ),
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
                  SelectableText(
                    value.isNotEmpty ? value : 'N/A',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
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

  String _boolText(dynamic value) {
    if (value == true || value == 1 || value == 'true') return 'Yes';
    if (value == false || value == 0 || value == 'false') return 'No';
    return 'N/A';
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return 'N/A';
    DateTime? dt;
    if (ts is Timestamp) dt = ts.toDate();
    if (ts is DateTime) dt = ts;
    if (ts is int) dt = DateTime.fromMillisecondsSinceEpoch(ts);
    if (ts is String) dt = DateTime.tryParse(ts);
    if (dt == null) return 'N/A';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final data = _liveData ?? widget.businessData;
    final businessPic = data['businesspic']?.toString() ?? '';

    if (_isDocumentDeleted) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            'Business Profile & Settings',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: Center(
          child: Text(
            'This user document no longer exists in Firestore.',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      );
    }
    final businessName =
        _nameController.text.isNotEmpty
            ? _nameController.text
            : (data['displayName'] ?? 'Service Provider');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Business Profile & Settings',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color:
                  _isRealtimeConnected
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    _isRealtimeConnected
                        ? const Color(0xFFA7F3D0)
                        : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color:
                      _isRealtimeConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 6),
                Text(
                  _isRealtimeConnected ? 'REAL-TIME' : 'OFFLINE',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        _isRealtimeConnected
                            ? const Color(0xFF047857)
                            : const Color(0xFFB91C1C),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _saveChanges,
              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.save_rounded, size: 18),
              label: Text(
                _isLoading
                    ? 'Saving...'
                    : (_hasUnsavedChanges ? 'Save Changes' : 'Save Profile'),
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
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
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header Card
                  Container(
                    padding: const EdgeInsets.all(24),
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
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF312E81).withValues(alpha: 0.3),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child:
                                businessPic.isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: businessPic,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (_, __) => const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                      errorWidget:
                                          (_, __, ___) => const Icon(
                                            Icons.business_rounded,
                                            color: Color(0xFF6366F1),
                                            size: 40,
                                          ),
                                    )
                                    : const Icon(
                                      Icons.business_rounded,
                                      color: Color(0xFF6366F1),
                                      size: 40,
                                    ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                businessName,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
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
                                        ? 'VERIFIED PROVIDER'
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
                                  if (_isProviderTemperoryDeactivatedStatus)
                                    _buildBadgeChip(
                                      'TEMPORARILY DEACTIVATED',
                                      const Color(0xFFF97316),
                                      Icons.timelapse_rounded,
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

                  // Deactivated Details Card (if provider is deactivated)
                  if (!_isActive) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFECACA),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFEF4444,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.block_rounded,
                              color: Color(0xFFEF4444),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Provider Status: Deactivated',
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB91C1C),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Deactivated At: ${_deactivatedAt != null ? DateFormat('dd MMM yyyy, hh:mm a').format(_deactivatedAt!) : (_formatTimestamp(data['deactivatedAt']) != 'N/A' ? _formatTimestamp(data['deactivatedAt']) : 'Timestamp pending save')}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF7F1D1D),
                                  ),
                                ),
                                if (_deactivationReasonController.text
                                    .trim()
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Deactivation Reason: ${_deactivationReasonController.text.trim().replaceAll('_', ' ')}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: const Color(0xFF991B1B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Switches & Status Control Bar
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
                            _buildStarProviderField(),
                            _buildToggle(
                              'Active Status',
                              _isActive,
                              (v) => setState(() => _isActive = v),
                              activeColor: const Color(0xFF3B82F6),
                              icon: Icons.power_settings_new_rounded,
                            ),
                            _buildToggle(
                              'Temporary Deactivation',
                              _isProviderTemperoryDeactivatedStatus,
                              (v) => setState(
                                () => _isProviderTemperoryDeactivatedStatus = v,
                              ),
                              activeColor: const Color(0xFFF97316),
                              icon: Icons.timelapse_rounded,
                            ),
                            _buildToggle(
                              'Basic Plan Enable',
                              _basicPlanEnable,
                              (v) => setState(() => _basicPlanEnable = v),
                              activeColor: const Color(0xFF06B6D4),
                              icon: Icons.card_giftcard_rounded,
                            ),
                            _buildToggle(
                              'Priority',
                              _priority,
                              (v) => setState(() => _priority = v),
                              activeColor: const Color(0xFFF59E0B),
                              icon: Icons.star_rounded,
                            ),
                            _buildToggle(
                              'Is User',
                              _isUser,
                              (v) => setState(() => _isUser = v),
                              activeColor: const Color(0xFF8B5CF6),
                              icon: Icons.person_rounded,
                            ),
                            // _buildToggle(
                            //   'Profile Complete',
                            //   _profileComplete,
                            //   (v) => setState(() => _profileComplete = v),
                            //   activeColor: const Color(0xFF0EA5E9),
                            //   icon: Icons.check_circle_rounded,
                            // ),
                            _buildToggle(
                              'Payment Link Sent',
                              _paymentLinkSend,
                              (v) => setState(() => _paymentLinkSend = v),
                              activeColor: const Color(0xFF6366F1),
                              icon: Icons.send_rounded,
                            ),
                            // _buildToggle(
                            //   'Category Boost',
                            //   _categoryBoostEnabled,
                            //   (v) => setState(() => _categoryBoostEnabled = v),
                            //   activeColor: const Color(0xFFEC4899),
                            //   icon: Icons.rocket_launch_rounded,
                            // ),
                          ],
                        ),
                        if (!_isActive) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _deactivationReasonController,
                            decoration: _buildInputDecoration(
                              'Deactivation Reason',
                              Icons.edit_note_rounded,
                              accentColor: const Color(0xFFEF4444),
                              hintText:
                                  'e.g. plan_duration_and_call_limit_exceeded',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Business Information Section
                  _buildSectionHeader(
                    'Business Information 🏢',
                    'Manage company branding, bio, address, and pincode',
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _businessPincodeController,
                          keyboardType: TextInputType.number,
                          decoration: _buildInputDecoration(
                            'Business Pincode',
                            Icons.pin_drop_rounded,
                            accentColor: const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _businessLocationController,
                          decoration: _buildInputDecoration(
                            'Business Location',
                            Icons.place_rounded,
                            accentColor: const Color(0xFF4F46E5),
                          ),
                        ),
                      ),
                    ],
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

                  // Service Rate Card & Pay Per Lead Charge Section
                  // _buildSectionHeader(
                  //   'Service Rate Card & Lead Pricing ⚡💰',
                  //   'Edit service rate list & configure pay per lead charge (₹)',
                  //   Icons.payments_rounded,
                  //   [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                  // ),

                  // Pay per lead & Extra plan charge row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pay Per Lead Charge (₹)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF78350F),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _payPerLeadChargeController,
                                      keyboardType: TextInputType.number,
                                      decoration: _buildInputDecoration(
                                        'Charge (₹)',
                                        Icons.currency_rupee_rounded,
                                        accentColor: const Color(0xFFF59E0B),
                                        hintText: 'e.g. 50',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.add_card_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Extra Plan Charge (₹)',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF78350F),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    TextFormField(
                                      controller: _extraPlanChargeController,
                                      keyboardType: TextInputType.number,
                                      decoration: _buildInputDecoration(
                                        'Extra (₹)',
                                        Icons.currency_rupee_rounded,
                                        accentColor: const Color(0xFFD97706),
                                        hintText: 'e.g. 0',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

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

                  // Editable Categories Section
                  const SizedBox(height: 16),
                  _buildEditableCategoriesSection(),

                  // Editable Category Priority Section
                  const SizedBox(height: 16),
                  _buildCategoryPrioritySection(),

                  // Verification Documents Section
                  // _buildSectionHeader(
                  //   'Identity & Legal Documents 📄',
                  //   'Aadhaar and PAN card details & verification links',
                  //   Icons.badge_rounded,
                  //   [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
                  // ),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _aadhaarNumberController,
                  //         decoration: _buildInputDecoration(
                  //           'Aadhaar Number',
                  //           Icons.credit_card_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 16),
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _aadhaarCardUrlController,
                  //         decoration: _buildInputDecoration(
                  //           'Aadhaar Card Document URL',
                  //           Icons.link_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  // const SizedBox(height: 16),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _panNumberController,
                  //         decoration: _buildInputDecoration(
                  //           'PAN Number',
                  //           Icons.credit_card_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 16),
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _panCardUrlController,
                  //         decoration: _buildInputDecoration(
                  //           'PAN Card Document URL',
                  //           Icons.link_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),

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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildEditableDateTimeField(
                          label: 'Last Payment At',
                          value: _lastPaymentAt,
                          icon: Icons.history_rounded,
                          onTap:
                              () => _selectDateTime(
                                initialValue: _lastPaymentAt,
                                onChanged:
                                    (val) =>
                                        setState(() => _lastPaymentAt = val),
                              ),
                          onClear: () => setState(() => _lastPaymentAt = null),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildEditableDateTimeField(
                          label: 'Payment Date',
                          value: _paymentDate,
                          icon: Icons.calendar_month_rounded,
                          onTap:
                              () => _selectDateTime(
                                initialValue: _paymentDate,
                                onChanged:
                                    (val) => setState(() => _paymentDate = val),
                              ),
                          onClear: () => setState(() => _paymentDate = null),
                        ),
                      ),
                    ],
                  ),

                  // Identity & Media
                  // _buildSectionHeader(
                  //   'Identity, Media & Documents 📄',
                  //   'Profile image, gallery, Aadhaar and PAN information',
                  //   Icons.badge_rounded,
                  //   [const Color(0xFF0D9488), const Color(0xFF14B8A6)],
                  // ),
                  // TextFormField(
                  //   controller: _businessPicController,
                  //   decoration: _buildInputDecoration(
                  //     'Business Profile Picture URL',
                  //     Icons.image_rounded,
                  //     accentColor: const Color(0xFF0D9488),
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  // TextFormField(
                  //   controller: _businessPicsController,
                  //   maxLines: 4,
                  //   decoration: _buildInputDecoration(
                  //     'Business Picture URLs',
                  //     Icons.photo_library_rounded,
                  //     accentColor: const Color(0xFF0D9488),
                  //     hintText: 'One Firebase Storage URL per line',
                  //   ),
                  // ),
                  // const SizedBox(height: 16),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _aadhaarNumberController,
                  //         decoration: _buildInputDecoration(
                  //           'Aadhaar Number',
                  //           Icons.credit_card_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 16),
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _aadhaarCardUrlController,
                  //         decoration: _buildInputDecoration(
                  //           'Aadhaar Card URL',
                  //           Icons.link_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),
                  // const SizedBox(height: 16),
                  // Row(
                  //   children: [
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _panNumberController,
                  //         decoration: _buildInputDecoration(
                  //           'PAN Number',
                  //           Icons.credit_card_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //     const SizedBox(width: 16),
                  //     Expanded(
                  //       child: TextFormField(
                  //         controller: _panCardUrlController,
                  //         decoration: _buildInputDecoration(
                  //           'PAN Card URL',
                  //           Icons.link_rounded,
                  //           accentColor: const Color(0xFF0D9488),
                  //         ),
                  //       ),
                  //     ),
                  //   ],
                  // ),

                  // Payment Metadata
                  _buildSectionHeader(
                    'Payment & Transaction Activity 💰',
                    'Live payment, pay-per-lead and transaction metadata',
                    Icons.receipt_long_rounded,
                    [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Overall Total Amount',
                          data['overaltotalamount']?.toString() ?? '0',
                          Icons.account_balance_wallet_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Payment Initiated At',
                          _formatTimestamp(data['paymentInitiatedAt']),
                          Icons.play_circle_outline_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Transaction Updated At',
                          _formatTimestamp(data['transactionUpdatedAt']),
                          Icons.sync_rounded,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Last PPl Payment Date',
                          _formatTimestamp(data['lastpaymentpayperlead']),
                          Icons.payments_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Last PPL Transaction ID',
                          data['lastpayperleadtransactionid']?.toString() ??
                              'N/A',
                          Icons.confirmation_number_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),

                  // Usage Statistics Section
                  _buildSectionHeader(
                    'Usage Statistics & Activity 📊',
                    'Call metrics, app engagement, and ratings summary',
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
                          'Total Calls Generated',
                          data['totalCallsGenerated']?.toString() ?? '0',
                          Icons.trending_up_rounded,
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Converted Count',
                          data['convertedCount']?.toString() ?? '0',
                          Icons.swap_horiz_rounded,
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
                          'Rating Sum',
                          data['ratingSum']?.toString() ?? '0',
                          Icons.stars_rounded,
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
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Today App Clicks',
                          data['todayApplinkClicks']?.toString() ?? '0',
                          Icons.touch_app_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Total App Clicks',
                          data['totalApplinkClicks']?.toString() ?? '0',
                          Icons.ads_click_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Click Counter Date',
                          data['clickCounterDate']?.toString() ?? 'N/A',
                          Icons.calendar_today_rounded,
                        ),
                      ),
                    ],
                  ),

                  // Activity Timestamps Section
                  _buildSectionHeader(
                    'Activity Timeline ⏳',
                    'Historical timestamps for creation, verification, payments, and deactivations',
                    Icons.history_rounded,
                    [const Color(0xFFEC4899), const Color(0xFFDB2777)],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Created At',
                          _formatTimestamp(data['createdAt']),
                          Icons.calendar_month_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Updated At',
                          _formatTimestamp(data['updatedAt']),
                          Icons.update_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Verified At',
                          _formatTimestamp(data['verifiedAt']),
                          Icons.verified_user_rounded,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          'Last Call At',
                          _formatTimestamp(data['lastCallAt']),
                          Icons.phone_in_talk_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildReadOnlyField(
                          'Last Click At',
                          _formatTimestamp(data['lastClickAt']),
                          Icons.ads_click_rounded,
                        ),
                      ),
                    ],
                  ),
                  if (_deactivatedAt != null ||
                      data['deactivatedAt'] != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildReadOnlyField(
                            'Deactivated At',
                            _formatTimestamp(
                              _deactivatedAt ?? data['deactivatedAt'],
                            ),
                            Icons.pause_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildReadOnlyField(
                            'Deactivation Reason',
                            data['deactivationReason']?.toString() ?? 'N/A',
                            Icons.info_outline_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],

                  Builder(
                    builder: (context) {
                      final (latCoord, lngCoord) = _extractCoordinates(data);
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _latitudeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                  decoration: _buildInputDecoration(
                                    'Latitude',
                                    Icons.north_rounded,
                                    accentColor: const Color(0xFF6366F1),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _longitudeController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                        signed: true,
                                      ),
                                  decoration: _buildInputDecoration(
                                    'Longitude',
                                    Icons.east_rounded,
                                    accentColor: const Color(0xFF8B5CF6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              // Expanded(
                              //   child: _buildReadOnlyField(
                              //     'Location (Geopoint)',
                              //     data['location']?['geopoint']?.toString() ??
                              //         'N/A',
                              //     Icons.map_rounded,
                              //   ),
                              // ),
                              // const SizedBox(width: 12),
                              // Expanded(
                              //   child: _buildCopyableCoordinateField(
                              //     'Combined Coordinates',
                              //     '$latCoord, $lngCoord',
                              //     Icons.gps_fixed_rounded,
                              //     copyLabel: 'Combined Coordinates',
                              //     accentColor: const Color(0xFF10B981),
                              //   ),
                              // ),
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
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String) _extractCoordinates(Map<String, dynamic> data) {
    if (data['coordinates'] is List &&
        (data['coordinates'] as List).isNotEmpty) {
      final list = data['coordinates'] as List;
      final lat = list.isNotEmpty ? list[0]?.toString() ?? '0' : '0';
      final lng = list.length > 1 ? list[1]?.toString() ?? '0' : '0';
      return (lat, lng);
    }
    final gp = data['location']?['geopoint'] ?? data['geopoint'];
    if (gp is GeoPoint) {
      return (gp.latitude.toString(), gp.longitude.toString());
    } else if (gp is Map) {
      final lat = (gp['_latitude'] ?? gp['latitude'] ?? gp['lat'])?.toString();
      final lng =
          (gp['_longitude'] ?? gp['longitude'] ?? gp['lng'])?.toString();
      if (lat != null && lng != null) return (lat, lng);
    }
    final lat = (data['latitude'] ?? data['lat'])?.toString();
    final lng = (data['longitude'] ?? data['lng'])?.toString();
    if (lat != null && lng != null) {
      return (lat, lng);
    }
    return ('0', '0');
  }

  Widget _buildCopyableCoordinateField(
    String label,
    String value,
    IconData icon, {
    String? copyLabel,
    Color accentColor = const Color(0xFF6366F1),
  }) {
    final displayCopyLabel = copyLabel ?? label;
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accentColor),
            ),
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
                  SelectableText(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.copy_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$displayCopyLabel copied!',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: accentColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(Icons.copy_rounded, size: 18, color: accentColor),
              tooltip: 'Copy $displayCopyLabel',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarProviderField() {
    final isStar = _starServiceProviderController.text.trim() == '1';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color:
            isStar
                ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isStar
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                  : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            size: 16,
            color: isStar ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Text(
            'Star Provider',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: isStar ? FontWeight.w700 : FontWeight.w500,
              color: isStar ? const Color(0xFFF59E0B) : const Color(0xFF475569),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            child: TextFormField(
              controller: _starServiceProviderController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '0/1',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFFF59E0B),
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableCategoriesSection() {
    return Container(
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
                Icons.category_rounded,
                color: Color(0xFF8B5CF6),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Categories Assigned 🏷️',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'No categories assigned yet.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _categories.map((cat) {
                    return Chip(
                      label: Text(
                        cat,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4F46E5),
                        ),
                      ),
                      backgroundColor: const Color(
                        0xFF6366F1,
                      ).withValues(alpha: 0.1),
                      side: const BorderSide(
                        color: Color(0xFF6366F1),
                        width: 1,
                      ),
                      deleteIcon: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      onDeleted: () => _removeCategory(cat),
                    );
                  }).toList(),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _newCategoryController,
                  decoration: InputDecoration(
                    hintText: 'Add new category...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(
                      Icons.add_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF8B5CF6),
                        width: 1.5,
                      ),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  onFieldSubmitted: _addCategory,
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _addCategory(_newCategoryController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  'Add',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPrioritySection() {
    if (_categoryPriorityControllers.isEmpty && _categories.isEmpty) {
      return const SizedBox.shrink();
    }
    for (final cat in _categories) {
      if (!_categoryPriorityControllers.containsKey(cat)) {
        _categoryPriorityControllers[cat] = TextEditingController(text: '0');
      }
    }
    final entries = _categoryPriorityControllers.entries.toList();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFF7ED),
            const Color(0xFFFEF3C7).withValues(alpha: 0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
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
                Icons.leaderboard_rounded,
                color: Color(0xFFD97706),
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Category Priority 🏆',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF78350F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Set priority (int) per category. Lower = higher priority.',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF92400E),
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            Text(
              'Add categories above to set priority.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
              ),
            )
          else
            ...entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          entry.key,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: const Color(0xFF78350F),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 90,
                      child: TextFormField(
                        controller: entry.value,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: 'Priority',
                          labelStyle: GoogleFonts.poppins(
                            fontSize: 11,
                            color: const Color(0xFF92400E),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFFDE68A),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: Color(0xFFF59E0B),
                              width: 1.5,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: const Color(0xFFD97706),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
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
              onChanged: (newValue) {
                _markDirty();
                onChanged(newValue);
              },
              activeThumbColor: activeColor,
            ),
          ),
        ],
      ),
    );
  }
}
