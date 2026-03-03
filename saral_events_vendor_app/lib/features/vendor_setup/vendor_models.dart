class VendorProfile {
  final String? id;
  final String userId;
  final String businessName;
  final String address;
  final String category;
  final String? phoneNumber;
  final String? email;
  final String? website;
  final String? description;
  final String? gstNumber;
  final String? panNumber;
  final String? aadhaarNumber;
  final String? vendorName;
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? bankName;
  final String? branchName;
  final List<String> services;
  final List<VendorDocument> documents;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? approvalStatus;
  final String? approvalNotes;
  final String? profilePictureUrl;
  final String? yearsOfExperience;
  final String? teamSize;
  final List<String>? serviceLocations;
  final List<String>? languagesSpoken;
  final String? advancePaymentPercentage;
  final String? cancellationPolicy;
  final String? refundRules;
  final String? upiId;
  final String? settlementCycle;
  final double? rating;
  final int? totalReviews;

  VendorProfile({
    this.id,
    required this.userId,
    required this.businessName,
    required this.address,
    required this.category,
    this.phoneNumber,
    this.email,
    this.website,
    this.description,
    this.gstNumber,
    this.panNumber,
    this.aadhaarNumber,
    this.vendorName,
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.bankName,
    this.branchName,
    required this.services,
    required this.documents,
    required this.createdAt,
    required this.updatedAt,
    this.approvalStatus,
    this.approvalNotes,
    this.profilePictureUrl,
    this.yearsOfExperience,
    this.teamSize,
    this.serviceLocations,
    this.languagesSpoken,
    this.advancePaymentPercentage,
    this.cancellationPolicy,
    this.refundRules,
    this.upiId,
    this.settlementCycle,
    this.rating,
    this.totalReviews,
  });

  VendorProfile copyWith({
    String? businessName,
    String? address,
    String? category,
    String? phoneNumber,
    String? email,
    String? website,
    String? description,
    String? gstNumber,
    String? panNumber,
    String? aadhaarNumber,
    String? vendorName,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    String? branchName,
    List<String>? services,
    List<VendorDocument>? documents,
    DateTime? updatedAt,
    String? approvalStatus,
    String? approvalNotes,
    String? profilePictureUrl,
    String? yearsOfExperience,
    String? teamSize,
    List<String>? serviceLocations,
    List<String>? languagesSpoken,
    String? advancePaymentPercentage,
    String? cancellationPolicy,
    String? refundRules,
    String? upiId,
    String? settlementCycle,
    double? rating,
    int? totalReviews,
  }) {
    return VendorProfile(
      id: id,
      userId: userId,
      businessName: businessName ?? this.businessName,
      address: address ?? this.address,
      category: category ?? this.category,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      website: website ?? this.website,
      description: description ?? this.description,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      vendorName: vendorName ?? this.vendorName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      bankName: bankName ?? this.bankName,
      branchName: branchName ?? this.branchName,
      services: services ?? this.services,
      documents: documents ?? this.documents,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approvalNotes: approvalNotes ?? this.approvalNotes,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl,
      yearsOfExperience: yearsOfExperience ?? this.yearsOfExperience,
      teamSize: teamSize ?? this.teamSize,
      serviceLocations: serviceLocations ?? this.serviceLocations,
      languagesSpoken: languagesSpoken ?? this.languagesSpoken,
      advancePaymentPercentage: advancePaymentPercentage ?? this.advancePaymentPercentage,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      refundRules: refundRules ?? this.refundRules,
      upiId: upiId ?? this.upiId,
      settlementCycle: settlementCycle ?? this.settlementCycle,
      rating: rating ?? this.rating,
      totalReviews: totalReviews ?? this.totalReviews,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_name': businessName,
      'address': address,
      'category': category,
      'phone_number': phoneNumber,
      'email': email,
      'website': website,
      'description': description,
      'gst_number': gstNumber,
      'pan_number': panNumber,
      'aadhaar_number': aadhaarNumber,
      'vendor_name': vendorName,
      'account_holder_name': accountHolderName,
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
      'branch_name': branchName,
      'services': services,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'approval_status': approvalStatus,
      'approval_notes': approvalNotes,
      'profile_picture_url': profilePictureUrl,
      'years_of_experience': yearsOfExperience,
      'team_size': teamSize,
      'service_locations': serviceLocations,
      'languages_spoken': languagesSpoken,
      'advance_payment_percentage': advancePaymentPercentage,
      'cancellation_policy': cancellationPolicy,
      'refund_rules': refundRules,
      'upi_id': upiId,
      'settlement_cycle': settlementCycle,
      'rating': rating,
      'total_reviews': totalReviews,
    };
  }

  factory VendorProfile.fromJson(Map<String, dynamic> json) {
    return VendorProfile(
      id: json['id'],
      userId: json['user_id'],
      businessName: json['business_name'],
      address: json['address'],
      category: json['category'],
      phoneNumber: json['phone_number'],
      email: json['email'],
      website: json['website'],
      description: json['description'],
      gstNumber: json['gst_number'],
      panNumber: json['pan_number'],
      aadhaarNumber: json['aadhaar_number'],
      vendorName: json['vendor_name'],
      accountHolderName: json['account_holder_name'],
      accountNumber: json['account_number'],
      ifscCode: json['ifsc_code'],
      bankName: json['bank_name'],
      branchName: json['branch_name'],
      services: List<String>.from(json['services'] ?? []),
      documents: [], // Documents will be fetched separately
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      approvalStatus: json['approval_status'],
      approvalNotes: json['approval_notes'],
      profilePictureUrl: json['profile_picture_url'],
      yearsOfExperience: json['years_of_experience'],
      teamSize: json['team_size'],
      serviceLocations: json['service_locations'] != null ? List<String>.from(json['service_locations']) : null,
      languagesSpoken: json['languages_spoken'] != null ? List<String>.from(json['languages_spoken']) : null,
      advancePaymentPercentage: json['advance_payment_percentage'],
      cancellationPolicy: json['cancellation_policy'],
      refundRules: json['refund_rules'],
      upiId: json['upi_id'],
      settlementCycle: json['settlement_cycle'],
      rating: (json['rating'] as num?)?.toDouble(),
      totalReviews: json['total_reviews'],
    );
  }
}

class VendorDocument {
  final String? id;
  final String vendorId;
  final String documentType;
  final String fileName;
  final String filePath;
  final String fileUrl;
  final DateTime uploadedAt;

  VendorDocument({
    this.id,
    required this.vendorId,
    required this.documentType,
    required this.fileName,
    required this.filePath,
    required this.fileUrl,
    required this.uploadedAt,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'vendor_id': vendorId,
      'document_type': documentType,
      'file_name': fileName,
      'file_path': filePath,
      'file_url': fileUrl,
      'uploaded_at': uploadedAt.toIso8601String(),
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory VendorDocument.fromJson(Map<String, dynamic> json) {
    return VendorDocument(
      id: json['id'],
      vendorId: json['vendor_id'],
      documentType: json['document_type'],
      fileName: json['file_name'],
      filePath: json['file_path'],
      fileUrl: json['file_url'],
      uploadedAt: DateTime.parse(json['uploaded_at']),
    );
  }
}
