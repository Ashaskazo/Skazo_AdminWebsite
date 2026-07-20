import 'package:cloud_firestore/cloud_firestore.dart';

/// Typed user document from the Firestore `users` collection.
class UserModel {
  final String id;
  final String? uid;
  final String? firstname;
  final String? lastname;
  final String? username;
  final String? name;
  final String? email;
  final int? phone;
  final String? businessname;
  final String? businessbio;
  final String? businessaddress;
  final String? businesspic;
  final String? address;
  final String? city;
  final String? cityCapital;
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

  const UserModel({
    required this.id,
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
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserModel.fromMap(doc.id, data);
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    final inferredIsUser =
        _parseBool(data['isuser']) ?? !_looksLikeServiceProvider(data);

    return UserModel(
      id: id,
      uid: data['uid']?.toString(),
      firstname: data['firstname']?.toString(),
      lastname: data['lastname']?.toString(),
      username: data['username']?.toString(),
      name: data['name']?.toString(),
      email: data['email']?.toString(),
      phone: _parsePhone(data['phone']),
      businessname: data['businessname']?.toString(),
      businessbio: data['businessbio']?.toString(),
      businessaddress: data['businessaddress']?.toString(),
      businesspic: data['businesspic']?.toString(),
      address: data['address']?.toString(),
      city: data['city']?.toString(),
      cityCapital: data['City']?.toString(),
      category: data['category'],
      isverified: _parseBool(data['isverified']) ?? false,
      isactive: _parseBool(data['isactive']) ?? true,
      isDeactivated: _parseBool(data['isDeactivated']) ?? false,
      isuser: inferredIsUser,
      profileComplete: _parseBool(data['profileComplete']) ?? false,
      priority: _parseInt(data['priority']),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
      verifiedAt: _parseDateTime(data['verifiedAt']),
    );
  }

  /// Backward-compatible map for existing UI pages (e.g. BusinessProfilePage).
  Map<String, dynamic> toMap() {
    return {
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
