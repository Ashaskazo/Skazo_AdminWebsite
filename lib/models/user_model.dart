import 'package:cloud_firestore/cloud_firestore.dart';

/// Typed user document from the Firestore `users` collection.
class UserModel {
  final String id;
  final Map<String, dynamic> rawData;
  final String? uid;
  final String? firstname;
  final String? lastname;
  final String? username;
  final String? name;
  final String? email;
  final int? phone;
  final String? gender;
  final String? businessname;
  final String? businessbio;
  final String? businessaddress;
  final String? businesspic;
  final List<dynamic>? businesspics;
  final String? businessLocation;
  final String? address;
  final String? city;
  final String? cityCapital;
  final String? cityKey;
  final String? pincode;
  final String? businessPincode;
  final dynamic category;
  final Map<String, dynamic>? categoryPriority;
  final bool categoryBoostEnabled;
  final dynamic ServiceRateCard;
  final String? StarServiceprovider;
  final bool priority;
  final bool isverified;
  final bool isactive;
  final bool isDeactivated;
  // final bool isProviderDeativatedStatus;
  final bool isProviderTemperoryDeactivatedStatus;
  final bool isuser;
  final bool isonline;
  final bool profileComplete;
  final bool basicplanenable;
  final int? activePlan;
  final String? paymentPlanDuration;
  final int? paymentCount;
  final int? totalAmount;
  final num? payperLeadCharge;
  final num? extraPlanCharge;
  final bool paymentLinkSend;
  final String? paymentLinkSenderId;
  final String? paymentLinkSenderName;
  final DateTime? paymentLinkSentAt;
  final String? transactionId;
  final DateTime? paymentDate;
  final DateTime? lastPaymentAt;
  final int? ownerPropertyPaid;
  final int? userPropertyPaid;
  final String? fcmtoken;
  final DateTime? deactivatedAt;
  final String? deactivationReason;
  final num? avgRating;
  final num? ratingSum;
  final int? totalRatings;
  final int? totalCallLogs;
  final int? totalCallsGenerated;
  final int? callsAfterLastPayment;
  final DateTime? lastCallAt;
  final int? todayApplinkClicks;
  final int? totalApplinkClicks;
  final DateTime? lastClickAt;
  final String? clickCounterDate;
  final String? aadhaarCardUrl;
  final String? aadhaarNumber;
  final String? panCardUrl;
  final String? panNumber;
  final dynamic coordinates;
  final String? geohash5;
  final String? geohash7;
  final dynamic location;
  final bool? sheetSent;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? verifiedAt;

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
    this.gender,
    this.businessname,
    this.businessbio,
    this.businessaddress,
    this.businesspic,
    this.businesspics,
    this.businessLocation,
    this.address,
    this.city,
    this.cityCapital,
    this.cityKey,
    this.pincode,
    this.businessPincode,
    this.category,
    this.categoryPriority,
    this.categoryBoostEnabled = false,
    this.ServiceRateCard,
    this.StarServiceprovider,
    this.priority = false,
    this.isverified = false,
    this.isactive = true,
    this.isDeactivated = false,
    // this.isProviderDeativatedStatus = false,
    this.isProviderTemperoryDeactivatedStatus = false,
    this.isuser = true,
    this.isonline = false,
    this.profileComplete = false,
    this.basicplanenable = false,
    this.activePlan,
    this.paymentPlanDuration,
    this.paymentCount,
    this.totalAmount,
    this.payperLeadCharge,
    this.extraPlanCharge,
    this.paymentLinkSend = false,
    this.paymentLinkSenderId,
    this.paymentLinkSenderName,
    this.paymentLinkSentAt,
    this.transactionId,
    this.paymentDate,
    this.lastPaymentAt,
    this.ownerPropertyPaid,
    this.userPropertyPaid,
    this.fcmtoken,
    this.deactivatedAt,
    this.deactivationReason,
    this.avgRating,
    this.ratingSum,
    this.totalRatings,
    this.totalCallLogs,
    this.totalCallsGenerated,
    this.callsAfterLastPayment,
    this.lastCallAt,
    this.todayApplinkClicks,
    this.totalApplinkClicks,
    this.lastClickAt,
    this.clickCounterDate,
    this.aadhaarCardUrl,
    this.aadhaarNumber,
    this.panCardUrl,
    this.panNumber,
    this.coordinates,
    this.geohash5,
    this.geohash7,
    this.location,
    this.sheetSent,
    this.createdAt,
    this.updatedAt,
    this.verifiedAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromMap(doc.id, data);
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    final inferredIsUser =
        _parseBool(data['isuser']) ?? !_looksLikeServiceProvider(data);

    final starProviderStr =
        (data['StarServiceprovider'] ?? data['starServiceProvider'])
            ?.toString();

    final rawLeadCharge = data['payperLeadcharge'] ?? data['payperLeadCharge'] ?? data['payPerLeadCharge'];
    final leadChargeNum = _parseNum(rawLeadCharge);

    final rawExtraPlan = data['extraPlanCharge'];
    final extraPlanNum = _parseNum(rawExtraPlan);

    final deactivatedFlag = _parseBool(data['isProviderDeativatedStatus']) ??
        _parseBool(data['isDeactivated']) ??
        false;

    return UserModel(
      id: id,
      rawData: data,
      uid: data['uid']?.toString(),
      firstname: data['firstname']?.toString(),
      lastname: data['lastname']?.toString(),
      username: data['username']?.toString(),
      name: data['name']?.toString(),
      email: data['email']?.toString(),
      phone: _parsePhone(data['phone']),
      gender: data['gender']?.toString(),
      businessname: data['businessname']?.toString(),
      businessbio: data['businessbio']?.toString(),
      businessaddress: data['businessaddress']?.toString(),
      businesspic: data['businesspic']?.toString(),
      businesspics: data['businesspics'] is List ? (data['businesspics'] as List) : null,
      businessLocation: data['businessLocation']?.toString(),
      address: data['address']?.toString(),
      city: data['city']?.toString(),
      cityCapital: data['City']?.toString(),
      cityKey: data['cityKey']?.toString(),
      pincode: (data['pincode'] ?? data['customerPincode'] ?? data['postalCode'])?.toString(),
      businessPincode: (data['businessPincode'] ?? data['business_pincode'])?.toString(),
      category: data['category'],
      categoryPriority: data['categoryPriority'] is Map ? Map<String, dynamic>.from(data['categoryPriority'] as Map) : null,
      categoryBoostEnabled: _parseBool(data['categoryBoostEnabled']) ?? false,
      ServiceRateCard: data['ServiceRateCard'] ?? data['serviceRateCard'],
      StarServiceprovider: starProviderStr,
      priority: _parseBool(data['priority']) ?? false,
      isverified: _parseBool(data['isverified']) ?? false,
      isactive: _parseBool(data['isactive']) ?? true,
      isDeactivated: deactivatedFlag,
      // isProviderDeativatedStatus: deactivatedFlag,
      isProviderTemperoryDeactivatedStatus: _parseBool(data['isProviderTemperoryDeactivatedStatus']) ?? false,
      isuser: inferredIsUser,
      isonline: _parseBool(data['isonline']) ?? false,
      profileComplete: _parseBool(data['profileComplete']) ?? false,
      basicplanenable: _parseBool(data['basicplanenable']) ?? false,
      activePlan: _parseInt(data['AtivePlan'] ?? data['ActivePlan']),
      paymentPlanDuration: data['paymentPlanDuration']?.toString(),
      paymentCount: _parseInt(data['paymentCount']),
      totalAmount: _parseInt(data['totalAmount']),
      payperLeadCharge: leadChargeNum,
      extraPlanCharge: extraPlanNum,
      paymentLinkSend: _parseBool(data['paymentLinkSend']) ?? false,
      paymentLinkSenderId: data['paymentLinkSenderId']?.toString(),
      paymentLinkSenderName: data['paymentLinkSenderName']?.toString(),
      paymentLinkSentAt: _parseDateTime(data['paymentLinkSentAt']),
      transactionId: data['transactionId']?.toString(),
      paymentDate: _parseDateTime(data['paymentDate']),
      lastPaymentAt: _parseDateTime(data['lastPaymentAt']),
      ownerPropertyPaid: _parseInt(data['ownerPropertyPaid']),
      userPropertyPaid: _parseInt(data['userPropertyPaid']),
      fcmtoken: data['fcmtoken']?.toString(),
      deactivatedAt: _parseDateTime(data['deactivatedAt']),
      deactivationReason: data['deactivationReason']?.toString(),
      avgRating: _parseNum(data['avgRating']),
      ratingSum: _parseNum(data['ratingSum']),
      totalRatings: _parseInt(data['totalRatings']),
      totalCallLogs: _parseInt(data['totalCallLogs']),
      totalCallsGenerated: _parseInt(data['totalCallsGenerated']),
      callsAfterLastPayment: _parseInt(data['callsAfterLastPayment']),
      lastCallAt: _parseDateTime(data['lastCallAt']),
      todayApplinkClicks: _parseInt(data['todayApplinkClicks']),
      totalApplinkClicks: _parseInt(data['totalApplinkClicks']),
      lastClickAt: _parseDateTime(data['lastClickAt']),
      clickCounterDate: data['clickCounterDate']?.toString(),
      aadhaarCardUrl: data['aadhaarCardUrl']?.toString(),
      aadhaarNumber: data['aadhaarNumber']?.toString(),
      panCardUrl: data['panCardUrl']?.toString(),
      panNumber: data['panNumber']?.toString(),
      coordinates: data['coordinates'],
      geohash5: data['geohash5']?.toString(),
      geohash7: data['geohash7']?.toString(),
      location: data['location'],
      sheetSent: _parseBool(data['sheetSent']),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      verifiedAt: _parseDateTime(data['verifiedAt']),
    );
  }

  /// Backward-compatible map for existing UI pages (e.g. BusinessProfilePage).
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
      if (gender != null) 'gender': gender,
      if (businessname != null) 'businessname': businessname,
      if (businessbio != null) 'businessbio': businessbio,
      if (businessaddress != null) 'businessaddress': businessaddress,
      if (businesspic != null) 'businesspic': businesspic,
      if (businesspics != null) 'businesspics': businesspics,
      if (businessLocation != null) 'businessLocation': businessLocation,
      if (address != null) 'address': address,
      if (city != null) 'city': city,
      if (cityCapital != null) 'City': cityCapital,
      if (cityKey != null) 'cityKey': cityKey,
      if (pincode != null) 'pincode': pincode,
      if (businessPincode != null) 'businessPincode': businessPincode,
      if (category != null) 'category': category,
      if (categoryPriority != null) 'categoryPriority': categoryPriority,
      'categoryBoostEnabled': categoryBoostEnabled,
      if (ServiceRateCard != null) 'ServiceRateCard': ServiceRateCard,
      if (StarServiceprovider != null)
        'StarServiceprovider': StarServiceprovider,
      'priority': priority,
      'isverified': isverified,
      'isactive': isactive,
      // 'isDeactivated': isProviderDeativatedStatus,
      // 'isProviderDeativatedStatus': isProviderDeativatedStatus,
      'isProviderTemperoryDeactivatedStatus': isProviderTemperoryDeactivatedStatus,
      'isuser': isuser,
      'isonline': isonline,
      'profileComplete': profileComplete,
      'basicplanenable': basicplanenable,
      if (activePlan != null) 'AtivePlan': activePlan,
      if (paymentPlanDuration != null) 'paymentPlanDuration': paymentPlanDuration,
      if (paymentCount != null) 'paymentCount': paymentCount,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (payperLeadCharge != null) 'payperLeadcharge': payperLeadCharge,
      if (extraPlanCharge != null) 'extraPlanCharge': extraPlanCharge,
      'paymentLinkSend': paymentLinkSend,
      if (paymentLinkSenderId != null) 'paymentLinkSenderId': paymentLinkSenderId,
      if (paymentLinkSenderName != null) 'paymentLinkSenderName': paymentLinkSenderName,
      if (paymentLinkSentAt != null) 'paymentLinkSentAt': Timestamp.fromDate(paymentLinkSentAt!),
      if (transactionId != null) 'transactionId': transactionId,
      if (paymentDate != null) 'paymentDate': Timestamp.fromDate(paymentDate!),
      if (lastPaymentAt != null) 'lastPaymentAt': Timestamp.fromDate(lastPaymentAt!),
      if (ownerPropertyPaid != null) 'ownerPropertyPaid': ownerPropertyPaid,
      if (userPropertyPaid != null) 'userPropertyPaid': userPropertyPaid,
      if (fcmtoken != null) 'fcmtoken': fcmtoken,
      if (deactivatedAt != null) 'deactivatedAt': Timestamp.fromDate(deactivatedAt!),
      if (deactivationReason != null) 'deactivationReason': deactivationReason,
      if (avgRating != null) 'avgRating': avgRating,
      if (ratingSum != null) 'ratingSum': ratingSum,
      if (totalRatings != null) 'totalRatings': totalRatings,
      if (totalCallLogs != null) 'totalCallLogs': totalCallLogs,
      if (totalCallsGenerated != null) 'totalCallsGenerated': totalCallsGenerated,
      if (callsAfterLastPayment != null) 'callsAfterLastPayment': callsAfterLastPayment,
      if (lastCallAt != null) 'lastCallAt': Timestamp.fromDate(lastCallAt!),
      if (todayApplinkClicks != null) 'todayApplinkClicks': todayApplinkClicks,
      if (totalApplinkClicks != null) 'totalApplinkClicks': totalApplinkClicks,
      if (lastClickAt != null) 'lastClickAt': Timestamp.fromDate(lastClickAt!),
      if (clickCounterDate != null) 'clickCounterDate': clickCounterDate,
      if (aadhaarCardUrl != null) 'aadhaarCardUrl': aadhaarCardUrl,
      if (aadhaarNumber != null) 'aadhaarNumber': aadhaarNumber,
      if (panCardUrl != null) 'panCardUrl': panCardUrl,
      if (panNumber != null) 'panNumber': panNumber,
      if (coordinates != null) 'coordinates': coordinates,
      if (geohash5 != null) 'geohash5': geohash5,
      if (geohash7 != null) 'geohash7': geohash7,
      if (location != null) 'location': location,
      if (sheetSent != null) 'sheetSent': sheetSent,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
    };
  }

  String get displayName =>
      businessname?.trim().isNotEmpty == true
          ? businessname!
          : firstname?.trim().isNotEmpty == true
          ? firstname!
          : name?.trim().isNotEmpty == true
          ? name!
          : 'Unknown User';

  bool get isServiceProvider {
    final hasBusinessName = businessname?.trim().isNotEmpty == true;
    final hasBusinessPic = businesspic?.trim().isNotEmpty == true;
    return hasBusinessName || hasBusinessPic;
  }

  static int? _parsePhone(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is bool) return value ? 1 : 0;
    return int.tryParse(value.toString().trim());
  }

  static num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    return num.tryParse(value.toString().trim());
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

  static bool _looksLikeServiceProvider(Map<String, dynamic> data) {
    final businessName = data['businessname']?.toString().trim() ?? '';
    final businessPic = data['businesspic']?.toString().trim() ?? '';
    final category = data['category'];

    if (businessName.isNotEmpty || businessPic.isNotEmpty) {
      return true;
    }
    if (category is List) {
      return category.any(
        (value) => value?.toString().trim().isNotEmpty == true,
      );
    }
    return category?.toString().trim().isNotEmpty == true;
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
