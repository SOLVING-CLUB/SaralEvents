import 'package:supabase_flutter/supabase_flutter.dart';
import 'service_models.dart';

class ServiceService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get vendor ID for current user
  Future<String?> _getVendorId() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final result = await _supabase
          .from('vendor_profiles')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      return result?['id'];
    } catch (e) {
      print('Error getting vendor ID: $e');
      return null;
    }
  }

  // Get all categories for current vendor
  Future<List<CategoryNode>> getCategories() async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return [];

      final result = await _supabase
          .from('categories')
          .select()
          .eq('vendor_id', vendorId)
          .order('name');

      // Convert to CategoryNode structure
      final categories = <CategoryNode>[];
      final categoryMap = <String, CategoryNode>{};

      // First pass: create all category nodes
      for (final row in result) {
        final category = CategoryNode(
          id: row['id'],
          name: row['name'],
          subcategories: [],
          services: [],
        );
        categoryMap[row['id']] = category;
      }

      // Second pass: build hierarchy
      for (final row in result) {
        final category = categoryMap[row['id']]!;
        if (row['parent_id'] == null) {
          categories.add(category);
        } else {
          final parent = categoryMap[row['parent_id']];
          if (parent != null) {
            parent.subcategories.add(category);
          }
        }
      }

      return categories;
    } catch (e) {
      print('Error getting categories: $e');
      return [];
    }
  }

  // Get vendor category (e.g., Photography, Decoration) from vendor_profiles
  Future<String?> _getVendorCategory() async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return null;
      final result = await _supabase
          .from('vendor_profiles')
          .select('category')
          .eq('id', vendorId)
          .maybeSingle();
      return result?['category'] as String?;
    } catch (e) {
      print('Error getting vendor category: $e');
      return null;
    }
  }

  // Create new category
  Future<CategoryNode?> createCategory(String name, String? parentId) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return null;

      final result = await _supabase
          .from('categories')
          .insert({
            'vendor_id': vendorId,
            'name': name,
            'parent_id': parentId,
          })
          .select()
          .single();

      return CategoryNode(
        id: result['id'],
        name: result['name'],
        subcategories: [],
        services: [],
      );
    } catch (e) {
      print('Error creating category: $e');
      return null;
    }
  }

  // Update category
  Future<bool> updateCategory(String categoryId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('categories')
          .update(updates)
          .eq('id', categoryId);

      return true;
    } catch (e) {
      print('Error updating category: $e');
      return false;
    }
  }

  // Delete category
  Future<bool> deleteCategory(String categoryId) async {
    try {
      // Check if category has services or subcategories
      final hasServices = await _supabase
          .from('services')
          .select('id')
          .eq('category_id', categoryId)
          .limit(1)
          .maybeSingle();

      final hasSubcategories = await _supabase
          .from('categories')
          .select('id')
          .eq('parent_id', categoryId)
          .limit(1)
          .maybeSingle();

      if (hasServices != null || hasSubcategories != null) {
        throw Exception('Cannot delete category with services or subcategories');
      }

      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryId);

      return true;
    } catch (e) {
      print('Error deleting category: $e');
      return false;
    }
  }

  // Force delete category and all its contents
  Future<bool> forceDeleteCategory(String categoryId) async {
    try {
      // First delete all services in this category
      await _supabase
          .from('services')
          .delete()
          .eq('category_id', categoryId);

      // Then delete all subcategories (recursive)
      final subcategories = await _supabase
          .from('categories')
          .select('id')
          .eq('parent_id', categoryId);

      for (final subcat in subcategories) {
        await forceDeleteCategory(subcat['id']);
      }

      // Finally delete the category itself
      await _supabase
          .from('categories')
          .delete()
          .eq('id', categoryId);

      return true;
    } catch (e) {
      print('Error force deleting category: $e');
      return false;
    }
  }

  // Move all services in a category to root level
  Future<bool> moveServicesToRoot(String categoryId) async {
    try {
      await _supabase
          .from('services')
          .update({'category_id': null})
          .eq('category_id', categoryId);

      return true;
    } catch (e) {
      print('Error moving services to root: $e');
      return false;
    }
  }

  // Get services for a category (null => root-level services)
  Future<List<ServiceItem>> getServices(String categoryId) async {
    try {
      final result = await _supabase
          .from('services')
          .select()
          .eq('category_id', categoryId)
          .order('created_at', ascending: false);

      return result.map((row) => ServiceItem(
        id: row['id'],
        categoryId: row['category_id'],
        name: row['name'],
        price: row['price']?.toDouble() ?? 0.0,
        tags: List<String>.from(row['tags'] ?? []),
        description: row['description'] ?? '',
        media: (row['media_urls'] as List<dynamic>?)
                ?.map((url) => MediaItem(url: url, type: MediaType.image))
                .toList() ?? [],
        enabled: row['is_active'] ?? true, // Map the is_active field to enabled
      )).toList();
    } catch (e) {
      print('Error getting services: $e');
      return [];
    }
  }

  // Recursively count all subcategories for a given category
  Future<int> countAllSubcategories(String categoryId) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return 0;

      // Get all category IDs recursively (including the category itself and all descendants)
      final categoryIds = await _getAllCategoryIdsRecursive(categoryId);
      
      // Count subcategories (exclude the category itself)
      return categoryIds.length - 1;
    } catch (e) {
      print('Error counting subcategories: $e');
      // Fallback: count direct subcategories
      try {
        final result = await _supabase
            .from('categories')
            .select('id')
            .eq('parent_id', categoryId);
        return result.length;
      } catch (e2) {
        print('Error in fallback subcategory count: $e2');
        return 0;
      }
    }
  }

  // Recursively count all services for a given category (including services in subcategories)
  Future<int> countAllServices(String categoryId) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return 0;

      // Get all category IDs including subcategories recursively
      final categoryIds = await _getAllCategoryIdsRecursive(categoryId);
      
      // Count services in all these categories
      final result = await _supabase
          .from('services')
          .select('id')
          .eq('vendor_id', vendorId)
          .inFilter('category_id', categoryIds);

      return result.length;
    } catch (e) {
      print('Error counting services: $e');
      // Fallback: count direct services
      try {
        final result = await _supabase
            .from('services')
            .select('id')
            .eq('category_id', categoryId);
        return result.length;
      } catch (e2) {
        print('Error in fallback service count: $e2');
        return 0;
      }
    }
  }

  // Helper: Get all category IDs recursively (including the category itself and all its descendants)
  Future<List<String>> _getAllCategoryIdsRecursive(String categoryId) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return [categoryId];

      final allIds = <String>[categoryId];
      final toProcess = <String>[categoryId];

      while (toProcess.isNotEmpty) {
        final currentId = toProcess.removeAt(0);
        final subcategories = await _supabase
            .from('categories')
            .select('id')
            .eq('parent_id', currentId)
            .eq('vendor_id', vendorId);

        for (final subcat in subcategories) {
          final subcatId = subcat['id'] as String;
          if (!allIds.contains(subcatId)) {
            allIds.add(subcatId);
            toProcess.add(subcatId);
          }
        }
      }

      return allIds;
    } catch (e) {
      print('Error getting recursive category IDs: $e');
      return [categoryId];
    }
  }

  // Create new service
  Future<ServiceItem?> createService({
    required String name,
    String? categoryId,
    required double price,
    required List<String> tags,
    required String description,
    required List<String> mediaUrls,
    int? capacityMin,
    int? capacityMax,
    int? parkingSpaces,
    List<String>? suitedFor,
    Map<String, dynamic>? features,
    List<String>? policies,
    bool isActive = true,
  }) async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return null;
      // Auto-populate the top-level vendor category label into services.category
      final vendorCategory = await _getVendorCategory();

      final insert = {
        'vendor_id': vendorId,
        'category_id': categoryId, // nullable for root-level service
        'name': name,
        'price': price,
        'tags': tags,
        'description': description,
        'media_urls': mediaUrls,
        'is_active': isActive,
        'category': vendorCategory,
        'capacity_min': capacityMin,
        'capacity_max': capacityMax,
        'parking_spaces': parkingSpaces,
        'suited_for': (suitedFor == null || suitedFor.isEmpty) ? null : suitedFor,
        'features': (features == null || features.isEmpty) ? null : features,
        'policies': (policies == null || policies.isEmpty) ? null : policies,
      };
      insert.removeWhere((k, v) => v == null);

      final result = await _supabase
          .from('services')
          .insert(insert)
          .select()
          .single();

      return ServiceItem(
        id: result['id'],
        categoryId: result['category_id'],
        name: result['name'],
        price: result['price']?.toDouble() ?? 0.0,
        tags: List<String>.from(result['tags'] ?? []),
        description: result['description'] ?? '',
        media: (result['media_urls'] as List<dynamic>?)
                ?.map((url) => MediaItem(url: url, type: MediaType.image))
                .toList() ?? [],
        enabled: result['is_active'] ?? true, // Map the is_active field to enabled
      );
    } catch (e) {
      print('Error creating service: $e');
      return null;
    }
  }

  // Update service
  Future<bool> updateService(String serviceId, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('services')
          .update(updates)
          .eq('id', serviceId);

      return true;
    } catch (e) {
      print('Error updating service: $e');
      return false;
    }
  }

  // Delete service
  Future<bool> deleteService(String serviceId) async {
    try {
      await _supabase
          .from('services')
          .delete()
          .eq('id', serviceId);

      return true;
    } catch (e) {
      print('Error deleting service: $e');
      return false;
    }
  }

  // Toggle service active status
  Future<bool> toggleServiceStatus(String serviceId, bool isActive) async {
    try {
      await _supabase
          .from('services')
          .update({'is_active': isActive})
          .eq('id', serviceId);

      return true;
    } catch (e) {
      print('Error toggling service status: $e');
      return false;
    }
  }

  // Toggle service visibility to users
  Future<bool> toggleServiceVisibility(String serviceId, bool isVisible) async {
    try {
      await _supabase
          .from('services')
          .update({'is_visible_to_users': isVisible})
          .eq('id', serviceId);

      return true;
    } catch (e) {
      print('Error toggling service visibility: $e');
      return false;
    }
  }

  // Get all services for current vendor
  Future<List<ServiceItem>> getAllServices() async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return [];

      final result = await _supabase
          .from('services')
          .select()
          .eq('vendor_id', vendorId)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return result.map((row) => ServiceItem(
        id: row['id'],
        categoryId: row['category_id'],
        name: row['name'],
        price: row['price']?.toDouble() ?? 0.0,
        tags: List<String>.from(row['tags'] ?? []),
        description: row['description'] ?? '',
        media: (row['media_urls'] as List<dynamic>?)
                ?.map((url) => MediaItem(url: url, type: MediaType.image))
                .toList() ?? [],
        enabled: row['is_active'] ?? true, // Map the is_active field to enabled
        isVisibleToUsers: row['is_visible_to_users'] ?? true,
      )).toList();
    } catch (e) {
      print('Error getting all services: $e');
      return [];
    }
  }

  // Get all services for current vendor (including inactive ones)
  Future<List<ServiceItem>> getAllServicesWithStatus() async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return [];

      final result = await _supabase
          .from('services')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false);

      return result.map((row) => ServiceItem(
        id: row['id'],
        categoryId: row['category_id'],
        name: row['name'],
        price: row['price']?.toDouble() ?? 0.0,
        tags: List<String>.from(row['tags'] ?? []),
        description: row['description'] ?? '',
        media: (row['media_urls'] as List<dynamic>?)
                ?.map((url) => MediaItem(url: url, type: MediaType.image))
                .toList() ?? [],
        enabled: row['is_active'] ?? true, // Map the is_active field to enabled
        isVisibleToUsers: row['is_visible_to_users'] ?? true,
      )).toList();
    } catch (e) {
      print('Error getting all services with status: $e');
      return [];
    }
  }

  // Get only root-level services (no category)
  Future<List<ServiceItem>> getRootServices() async {
    try {
      final vendorId = await _getVendorId();
      if (vendorId == null) return [];

      final result = await _supabase
          .from('services')
          .select()
          .eq('vendor_id', vendorId)
          .filter('category_id', 'is', null)
          .order('created_at', ascending: false);

      return result.map((row) => ServiceItem(
        id: row['id'],
        categoryId: row['category_id'],
        name: row['name'],
        price: row['price']?.toDouble() ?? 0.0,
        tags: List<String>.from(row['tags'] ?? []),
        description: row['description'] ?? '',
        media: (row['media_urls'] as List<dynamic>?)
                ?.map((url) => MediaItem(url: url, type: MediaType.image))
                .toList() ?? [],
        enabled: row['is_active'] ?? true, // Map the is_active field to enabled
        isVisibleToUsers: row['is_visible_to_users'] ?? true,
      )).toList();
    } catch (e) {
      print('Error getting root services: $e');
      return [];
    }
  }
}
