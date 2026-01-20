enum MediaType { image, video }

class MediaItem {
  final String url;
  final MediaType type;

  const MediaItem({required this.url, required this.type});
}

class ServiceItem {
  final String id;
  final String? categoryId; // nullable for root-level services
  final String name;
  final double price;
  final List<String> tags;
  final String description;
  final List<MediaItem> media;
  final bool enabled;
  final String vendorId; // Add vendor ID for user app
  final String vendorName; // Add vendor name for user app
  final String? vendorCategory; // Vendor category (Photography, Decoration, etc.)
  final int? capacityMin;
  final int? capacityMax;
  final int? parkingSpaces;
  final double? ratingAvg;
  final int? ratingCount;
  final List<String> suitedFor;
  final Map<String, dynamic> features;
  final List<String> policies;

  const ServiceItem({
    required this.id,
    this.categoryId,
    required this.name,
    required this.price,
    required this.tags,
    required this.description,
    required this.media,
    this.enabled = true,
    required this.vendorId,
    required this.vendorName,
    this.vendorCategory,
    this.capacityMin,
    this.capacityMax,
    this.parkingSpaces,
    this.ratingAvg,
    this.ratingCount,
    this.suitedFor = const <String>[],
    this.features = const <String, dynamic>{},
    this.policies = const <String>[],
  });
}

class CategoryNode {
  final String id;
  final String name;
  final List<CategoryNode> subcategories;
  final List<ServiceItem> services;

  const CategoryNode({
    required this.id,
    required this.name,
    this.subcategories = const <CategoryNode>[],
    this.services = const <ServiceItem>[],
  });
}

class VendorProfile {
  final String id;
  final String businessName;
  final String address;
  final String category;
  final String? phoneNumber;
  final String? email;
  final String? website;
  final String? description;

  const VendorProfile({
    required this.id,
    required this.businessName,
    required this.address,
    required this.category,
    this.phoneNumber,
    this.email,
    this.website,
    this.description,
  });
}
