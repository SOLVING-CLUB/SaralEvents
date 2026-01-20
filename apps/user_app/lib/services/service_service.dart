import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_models.dart';
import '../core/cache/simple_cache.dart';

class ServiceService {
  final SupabaseClient _supabase;

  ServiceService(this._supabase);

  // Fetch all active services from all vendors
  Future<List<ServiceItem>> getAllServices() async {
    try {
      return await CacheManager.instance.getOrFetch<List<ServiceItem>>(
        'services:all',
        const Duration(minutes: 5),
        () async {
          final result = await _supabase
          .from('services')
          .select('''
            *,
            vendor_profiles!inner(
              id,
              business_name,
              address,
              category
            )
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false);
          return result.map((row) {
            final vendorProfile = row['vendor_profiles'];
            final vendorId = vendorProfile['id'] ?? '';
            final vendorName = vendorProfile['business_name'] ?? 'Unknown Vendor';
            final vendorCategory = vendorProfile['category'] as String?;
            return ServiceItem(
              id: row['id'],
              categoryId: row['category_id'],
              name: row['name'],
              price: (row['price'] ?? 0).toDouble(),
              tags: List<String>.from(row['tags'] ?? []),
              description: row['description'] ?? '',
              media: (row['media_urls'] as List<dynamic>?)
                      ?.map((url) => MediaItem(url: url, type: MediaType.image))
                      .toList() ??
                  [],
              enabled: row['is_active'] ?? true,
              vendorId: vendorId,
              vendorName: vendorName,
              vendorCategory: vendorCategory,
              capacityMin: row['capacity_min'] as int?,
              capacityMax: row['capacity_max'] as int?,
              parkingSpaces: row['parking_spaces'] as int?,
              ratingAvg: (row['rating_avg'] is num) ? (row['rating_avg'] as num).toDouble() : null,
              ratingCount: row['rating_count'] as int?,
              suitedFor: List<String>.from(row['suited_for'] ?? const <String>[]),
              features: (row['features'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
              policies: List<String>.from(row['policies'] ?? const <String>[]),
            );
          }).toList();
        },
      );
    } catch (e) {
      print('Error fetching services: $e');
      return [];
    }
  }

  // Fetch all categories from all vendors
  Future<List<CategoryNode>> getAllCategories() async {
    try {
      return await CacheManager.instance.getOrFetch<List<CategoryNode>>(
        'categories:all',
        const Duration(minutes: 30),
        () async {
          final result = await _supabase
          .from('categories')
          .select('*')
          .order('name');
          return result.map((row) => CategoryNode(
            id: row['id'],
            name: row['name'],
            subcategories: [],
            services: [],
          )).toList();
        },
      );
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  // Fetch services by category
  Future<List<ServiceItem>> getServicesByCategory(String categoryId) async {
    try {
      return await CacheManager.instance.getOrFetch<List<ServiceItem>>(
        'services:category:$categoryId',
        const Duration(minutes: 5),
        () async {
          final result = await _supabase
          .from('services')
          .select('''
            *,
            vendor_profiles!inner(
              id,
              business_name,
              address,
              category
            )
          ''')
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .order('created_at', ascending: false);
          return result.map((row) {
            final vendorProfile = row['vendor_profiles'];
            final vendorCategory = vendorProfile['category'] as String?;
            return ServiceItem(
              id: row['id'],
              categoryId: row['category_id'],
              name: row['name'],
              price: (row['price'] ?? 0).toDouble(),
              tags: List<String>.from(row['tags'] ?? []),
              description: row['description'] ?? '',
              media: (row['media_urls'] as List<dynamic>?)
                      ?.map((url) => MediaItem(url: url, type: MediaType.image))
                      .toList() ??
                  [],
              enabled: row['is_active'] ?? true,
              vendorId: vendorProfile['id'] ?? '',
              vendorName: vendorProfile['business_name'] ?? 'Unknown Vendor',
              vendorCategory: vendorCategory,
              capacityMin: row['capacity_min'] as int?,
              capacityMax: row['capacity_max'] as int?,
              parkingSpaces: row['parking_spaces'] as int?,
              ratingAvg: (row['rating_avg'] is num) ? (row['rating_avg'] as num).toDouble() : null,
              ratingCount: row['rating_count'] as int?,
              suitedFor: List<String>.from(row['suited_for'] ?? const <String>[]),
              features: (row['features'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
              policies: List<String>.from(row['policies'] ?? const <String>[]),
            );
          }).toList();
        },
      );
    } catch (e) {
      print('Error fetching services by category: $e');
      return [];
    }
  }

  // Search services by query
  Future<List<ServiceItem>> searchServices(String query) async {
    try {
      final key = 'services:search:${query.toLowerCase()}';
      return await CacheManager.instance.getOrFetch<List<ServiceItem>>(
        key,
        const Duration(minutes: 2),
        () async {
          final result = await _supabase
          .from('services')
          .select('''
            *,
            vendor_profiles!inner(
              id,
              business_name,
              address,
              category
            )
          ''')
          .eq('is_active', true)
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);
          return result.map((row) {
            final vendorProfile = row['vendor_profiles'];
            final vendorCategory = vendorProfile['category'] as String?;
            return ServiceItem(
              id: row['id'],
              categoryId: row['category_id'],
              name: row['name'],
              price: (row['price'] ?? 0).toDouble(),
              tags: List<String>.from(row['tags'] ?? []),
              description: row['description'] ?? '',
              media: (row['media_urls'] as List<dynamic>?)
                      ?.map((url) => MediaItem(url: url, type: MediaType.image))
                      .toList() ??
                  [],
              enabled: row['is_active'] ?? true,
              vendorId: vendorProfile['id'] ?? '',
              vendorName: vendorProfile['business_name'] ?? 'Unknown Vendor',
              vendorCategory: vendorCategory,
              capacityMin: row['capacity_min'] as int?,
              capacityMax: row['capacity_max'] as int?,
              parkingSpaces: row['parking_spaces'] as int?,
              ratingAvg: (row['rating_avg'] is num) ? (row['rating_avg'] as num).toDouble() : null,
              ratingCount: row['rating_count'] as int?,
              suitedFor: List<String>.from(row['suited_for'] ?? const <String>[]),
              features: (row['features'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
              policies: List<String>.from(row['policies'] ?? const <String>[]),
            );
          }).toList();
        },
      );
    } catch (e) {
      print('Error searching services: $e');
      return [];
    }
  }

  // Fetch services by a list of IDs
  Future<List<ServiceItem>> getServicesByIds(List<String> ids) async {
    if (ids.isEmpty) return <ServiceItem>[];
    try {
      final result = await _supabase
          .from('services')
          .select('''
            *,
            vendor_profiles!inner(
              id,
              business_name,
              address,
              category
            )
          ''')
          .inFilter('id', ids)
          .eq('is_active', true)
          .order('created_at', ascending: false);
      return result.map((row) {
        final vendorProfile = row['vendor_profiles'];
        return ServiceItem(
          id: row['id'],
          categoryId: row['category_id'],
          name: row['name'],
          price: (row['price'] ?? 0).toDouble(),
          tags: List<String>.from(row['tags'] ?? []),
          description: row['description'] ?? '',
          media: (row['media_urls'] as List<dynamic>?)
                  ?.map((url) => MediaItem(url: url, type: MediaType.image))
                  .toList() ??
              [],
          enabled: row['is_active'] ?? true,
          vendorId: vendorProfile['id'] ?? '',
          vendorName: vendorProfile['business_name'] ?? 'Unknown Vendor',
          capacityMin: row['capacity_min'] as int?,
          capacityMax: row['capacity_max'] as int?,
          parkingSpaces: row['parking_spaces'] as int?,
          ratingAvg: (row['rating_avg'] is num) ? (row['rating_avg'] as num).toDouble() : null,
          ratingCount: row['rating_count'] as int?,
          suitedFor: List<String>.from(row['suited_for'] ?? const <String>[]),
          features: (row['features'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
          policies: List<String>.from(row['policies'] ?? const <String>[]),
        );
      }).toList();
    } catch (e) {
      print('Error fetching services by ids: $e');
      return [];
    }
  }
}
