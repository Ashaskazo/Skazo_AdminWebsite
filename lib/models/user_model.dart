import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skazo_admin/utils/city_resolver.dart';

/// Typed user document from the Firestore `users` collection.
///
/// SOURCE OF TRUTH:
/// - `isuser == true`  => Customer
/// - `isuser == false` => Service Provider
class UserModel {
  final String id;
  final Map<String, dynamic> rawData;
  final String? uid;
  final String? firstname;
  final String? lastname;
  final String? username;
  final String? name;
  final String? email;
  final String? phone;
  final String? businessname;
  final String? businessbio;
  final String? businessaddress;
  final String? businesspic;
  final String? address;
  final String? city;
  final String? cityCapital;
  final String? cityKey;
  final dynamic category;
  final bool isverified;
  final bool isactive;
  final bool isDeactivated;
  final bool isuser;
  final bool profileComplete;
  final int? priority;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;
  final int? activePlan;
  final String? gender;
  final int? ownerPropertyPaid;
  final int? userPropertyPaid;
  final String? fcmtoken;
  final int? totalAmount;
  final bool categoryBoostEnabled;
  final bool paymentLinkSend;
  final bool isonline;
  final String? StarServiceprovider;
  final num? payperLeadCharge;
  final String? businessPincode;
  final List<String>? serviceProviderCities;

  const UserModel({
    required this.id,
    this.rawData = const {},
    this.uid,
    this.firstname,
    this.lastname,
    this.username,
    this.name,
    this.email,
    this.phone,
    this.businessname,
    this.businessbio,
    this.businessaddress,
    this.businesspic,
    this.address,
    this.city,
    this.cityCapital,
    this.cityKey,
    this.category,
    this.isverified = false,
    this.isactive = true,
    this.isDeactivated = false,
    this.isuser = true,
    this.profileComplete = false,
    this.priority,
    this.createdAt,
    this.updatedAt,
    this.verifiedAt,
    this.activePlan,
    this.gender,
    this.ownerPropertyPaid,
    this.userPropertyPaid,
    this.fcmtoken,
    this.totalAmount,
    this.categoryBoostEnabled = false,
    this.paymentLinkSend = false,
    this.isonline = false,
    this.StarServiceprovider,
    this.payperLeadCharge,
    this.businessPincode,
    this.serviceProviderCities,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromMap(doc.id, data);
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    // ── Canonical isuser resolution ──────────────────────────────────────
    // 1. Check explicit `isuser` field (supports bool, num, string representations)
    // 2. Fallback to `isServiceProvider` field if present
    // 3. Fallback to structural heuristic (business fields) for legacy documents
    final parsedIsUser = _parseBool(data['isuser']);
    final bool resolvedIsUser;
    if (parsedIsUser != null) {
      resolvedIsUser = parsedIsUser;
    } else if (data.containsKey('isServiceProvider')) {
      final isProvider = _parseBool(data['isServiceProvider']) ?? false;
      resolvedIsUser = !isProvider;
    } else {
      resolvedIsUser = !_isLegacyServiceProviderDoc(data);
    }

    final rawStar = data['StarServiceprovider'];
    final starProviderStr = rawStar?.toString();

    final rawLeadCharge = data['payperLeadcharge'] ?? data['payperLeadCharge'];
    num? leadChargeNum;
    if (rawLeadCharge != null) {
      if (rawLeadCharge is num) {
        leadChargeNum = rawLeadCharge;
      } else {
        leadChargeNum = num.tryParse(rawLeadCharge.toString().trim());
      }
    }

    // Normalized phone string
    final phoneStr = _parsePhoneString(data['phone'] ?? data['phoneNumber'] ?? data['mobile']);

    // Universal cityKey resolution
    final directCityKey = data['cityKey']?.toString().trim().toLowerCase();
    final explicitCity = (data['city'] ?? data['City'] ?? data['businessCity'])?.toString().trim();
    final resolvedCityKey = (directCityKey != null && directCityKey.isNotEmpty)
        ? directCityKey
        : (explicitCity != null && explicitCity.isNotEmpty
            ? explicitCity.toLowerCase().replaceAll(RegExp(r'\s+'), ' ')
            : null);

    // Business pincode
    final storedPincode = data['businessPincode']?.toString().trim().isNotEmpty == true
        ? data['businessPincode'].toString().trim()
        : extractUserPincode(data);

    final rawCities = data['serviceProviderCities'];
    List<String>? storedCities;
    if (rawCities is List) {
      storedCities = rawCities.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    }

    return UserModel(
      id: id,
      rawData: data,
      uid: data['uid']?.toString(),
      firstname: data['firstname']?.toString(),
      lastname: data['lastname']?.toString(),
      username: data['username']?.toString(),
      name: data['name']?.toString(),
      email: data['email']?.toString(),
      phone: phoneStr,
      businessname: data['businessname']?.toString(),
      businessbio: data['businessbio']?.toString(),
      businessaddress: data['businessaddress']?.toString(),
      businesspic: data['businesspic']?.toString(),
      address: data['address']?.toString(),
      city: explicitCity ?? data['city']?.toString(),
      cityCapital: data['City']?.toString(),
      cityKey: resolvedCityKey,
      category: data['category'],
      isverified: _parseBool(data['isverified']) ?? false,
      isactive: _parseBool(data['isactive']) ?? true,
      isDeactivated: _parseBool(data['isDeactivated']) ?? false,
      isuser: resolvedIsUser,
      profileComplete: _parseBool(data['profileComplete']) ?? false,
      priority: _parseInt(data['priority']),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      verifiedAt: _parseDateTime(data['verifiedAt']),
      activePlan: _parseInt(data['AtivePlan'] ?? data['activePlan']),
      gender: data['gender']?.toString(),
      ownerPropertyPaid: _parseInt(data['ownerPropertyPaid']),
      userPropertyPaid: _parseInt(data['userPropertyPaid']),
      fcmtoken: data['fcmtoken']?.toString(),
      totalAmount: _parseInt(data['totalAmount']),
      categoryBoostEnabled: _parseBool(data['categoryBoostEnabled']) ?? false,
      paymentLinkSend: _parseBool(data['paymentLinkSend']) ?? false,
      isonline: _parseBool(data['isonline']) ?? false,
      StarServiceprovider: starProviderStr,
      payperLeadCharge: leadChargeNum,
      businessPincode: storedPincode,
      serviceProviderCities: storedCities,
    );
  }

  /// Backward-compatible map for UI pages.
  Map<String, dynamic> toMap() {
    return {
      ...rawData,
      'id': id,
      if (uid != null) 'uid': uid,
      if (firstname != null) 'firstname': firstname,
      if (lastname != null) 'lastname': lastname,
      if (username != null) 'username': username,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (businessname != null) 'businessname': businessname,
      if (businessbio != null) 'businessbio': businessbio,
      if (businessaddress != null) 'businessaddress': businessaddress,
      if (businesspic != null) 'businesspic': businesspic,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (cityCapital != null) 'City': cityCapital,
      if (cityKey != null) 'cityKey': cityKey,
      if (category != null) 'category': category,
      'isverified': isverified,
      'isactive': isactive,
      'isDeactivated': isDeactivated,
      'isuser': isuser,
      'profileComplete': profileComplete,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
      if (activePlan != null) 'AtivePlan': activePlan,
      if (gender != null) 'gender': gender,
      if (ownerPropertyPaid != null) 'ownerPropertyPaid': ownerPropertyPaid,
      if (userPropertyPaid != null) 'userPropertyPaid': userPropertyPaid,
      if (fcmtoken != null) 'fcmtoken': fcmtoken,
      if (totalAmount != null) 'totalAmount': totalAmount,
      'categoryBoostEnabled': categoryBoostEnabled,
      'paymentLinkSend': paymentLinkSend,
      'isonline': isonline,
      if (StarServiceprovider != null) 'StarServiceprovider': StarServiceprovider,
      if (payperLeadCharge != null) 'payperLeadcharge': payperLeadCharge,
      if (businessPincode != null) 'businessPincode': businessPincode,
      if (serviceProviderCities != null) 'serviceProviderCities': serviceProviderCities,
    };
  }

  String get displayName =>
      businessname?.trim().isNotEmpty == true
          ? businessname!.trim()
          : firstname?.trim().isNotEmpty == true
              ? firstname!.trim()
              : name?.trim().isNotEmpty == true
                  ? name!.trim()
                  : (username?.trim().isNotEmpty == true ? username!.trim() : 'Unknown User');

  /// Unified source of truth:
  bool get isCustomer => isuser == true;
  bool get isServiceProvider => isuser == false;

  static String? _parsePhoneString(dynamic value) {
    if (value == null) return null;
    final str = value.toString().trim();
    if (str.isEmpty) return null;
    return str;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(value.toString().trim());
  }

  static bool? _parseBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'no' || normalized == '0') {
      return false;
    }
    return null;
  }

  /// Structural check for legacy documents missing `isuser`
  static bool _isLegacyServiceProviderDoc(Map<String, dynamic> data) {
    final businessName = (data['businessname'] ?? data['businessName'] ?? data['business_name'])?.toString().trim() ?? '';
    final businessPic = (data['businesspic'] ?? data['businessPic'] ?? data['business_pic'])?.toString().trim() ?? '';
    final businessAddress = (data['businessaddress'] ?? data['businessAddress'] ?? data['business_address'] ?? data['address'])?.toString().trim() ?? '';

    return businessName.isNotEmpty && businessPic.isNotEmpty && businessAddress.isNotEmpty;
  }

  /// Single classification method for external maps/documents.
  static bool isServiceProviderDoc(Map<String, dynamic> data) {
    if (data.containsKey('isuser')) {
      final parsed = _parseBool(data['isuser']);
      if (parsed != null) return !parsed;
    }
    if (data.containsKey('isServiceProvider')) {
      final parsed = _parseBool(data['isServiceProvider']);
      if (parsed != null) return parsed;
    }
    return _isLegacyServiceProviderDoc(data);
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
