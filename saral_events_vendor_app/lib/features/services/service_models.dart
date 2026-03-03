class VendorService {
  final String id;
  final String name;
  final String description;
  final int price;
  final List<String> imageUrls;

  const VendorService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrls,
  });
}

class Booking {
  final String id;
  final String serviceId;
  final String status; // pending, confirmed, completed
  final DateTime date;

  const Booking({
    required this.id,
    required this.serviceId,
    required this.status,
    required this.date,
  });
}

enum MediaType { image, video }

class MediaItem {
  final String url;
  final MediaType type;

  const MediaItem({required this.url, required this.type});
}

class ServiceItem {
  final String id;
  final String? categoryId; // nullable for root-level services
  String name;
  double price;
  List<String> tags;
  String description;
  List<MediaItem> media;
  bool enabled;
  bool isVisibleToUsers;

  double rating;
  int reviewCount;

  ServiceItem({
    required this.id,
    this.categoryId,
    required this.name,
    required this.price,
    required this.tags,
    required this.description,
    required this.media,
    this.enabled = true,
    this.isVisibleToUsers = true,
    this.rating = 0.0,
    this.reviewCount = 0,
  });
}

class CategoryNode {
  final String id;
  String name;
  List<CategoryNode> subcategories; // Remove 'final' to make it mutable
  final List<ServiceItem> services;

  CategoryNode({
    required this.id,
    required this.name,
    List<CategoryNode>? subcategories,
    List<ServiceItem>? services,
  })  : subcategories = subcategories ?? <CategoryNode>[],
        services = services ?? <ServiceItem>[];
}

