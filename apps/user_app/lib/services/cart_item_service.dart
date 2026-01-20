import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../checkout/checkout_state.dart';
import '../core/cache/simple_cache.dart';

/// Service to manage cart items in Supabase database
class CartItemService {
  final SupabaseClient _supabase;

  CartItemService(this._supabase);

  /// Add item to cart in database
  Future<String> addToCart({
    required String serviceId,
    required String vendorId,
    required String title,
    required String category,
    required double price,
    String? subtitle,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
    String status = 'active',
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final cartItemData = {
        'user_id': user.id,
        'service_id': serviceId,
        'vendor_id': vendorId,
        'title': title,
        'category': category,
        'price': price,
        'subtitle': subtitle,
        'booking_date': bookingDate?.toIso8601String().split('T')[0],
        'booking_time': bookingTime != null
            ? '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}'
            : null,
        'status': status,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

      final result = await _supabase
          .from('cart_items')
          .insert(cartItemData)
          .select('id')
          .single();

      // Invalidate cart cache
      _invalidateCartCache(user.id);

      return result['id'] as String;
    } catch (e) {
      print('Error adding item to cart: $e');
      rethrow;
    }
  }

  /// Get user's active cart items
  Future<List<Map<String, dynamic>>> getCartItems() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final cacheKey = 'cart_items:${user.id}:active';
      return await CacheManager.instance.getOrFetch<List<Map<String, dynamic>>>(
        cacheKey,
        const Duration(minutes: 1),
        () async {
          final result = await _supabase
              .from('cart_items')
              .select('*')
              .eq('user_id', user.id)
              .eq('status', 'active')
              .gt('expires_at', DateTime.now().toIso8601String())
              .order('created_at', ascending: false);

          return List<Map<String, dynamic>>.from(result);
        },
      );
    } catch (e) {
      print('Error fetching cart items: $e');
      return [];
    }
  }

  /// Get user's saved for later items
  Future<List<Map<String, dynamic>>> getSavedForLater() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return [];
      }

      final cacheKey = 'cart_items:${user.id}:saved';
      return await CacheManager.instance.getOrFetch<List<Map<String, dynamic>>>(
        cacheKey,
        const Duration(minutes: 1),
        () async {
          final result = await _supabase
              .from('cart_items')
              .select('*')
              .eq('user_id', user.id)
              .eq('status', 'saved_for_later')
              .gt('expires_at', DateTime.now().toIso8601String())
              .order('created_at', ascending: false);

          return List<Map<String, dynamic>>.from(result);
        },
      );
    } catch (e) {
      print('Error fetching saved items: $e');
      return [];
    }
  }

  /// Update cart item status (e.g., move to saved_for_later)
  Future<bool> updateCartItemStatus(String cartItemId, String status) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      await _supabase
          .from('cart_items')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cartItemId)
          .eq('user_id', user.id);

      // Invalidate cart cache
      _invalidateCartCache(user.id);

      return true;
    } catch (e) {
      print('Error updating cart item status: $e');
      return false;
    }
  }

  /// Update cart item booking details
  Future<bool> updateCartItemBooking({
    required String cartItemId,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      await _supabase
          .from('cart_items')
          .update({
            'booking_date': bookingDate?.toIso8601String().split('T')[0],
            'booking_time': bookingTime != null
                ? '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}'
                : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cartItemId)
          .eq('user_id', user.id);

      // Invalidate cart cache
      _invalidateCartCache(user.id);

      return true;
    } catch (e) {
      print('Error updating cart item booking: $e');
      return false;
    }
  }

  /// Remove item from cart
  Future<bool> removeFromCart(String cartItemId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      await _supabase
          .from('cart_items')
          .delete()
          .eq('id', cartItemId)
          .eq('user_id', user.id);

      // Invalidate cart cache
      _invalidateCartCache(user.id);

      return true;
    } catch (e) {
      print('Error removing cart item: $e');
      return false;
    }
  }

  /// Clear all cart items for user
  Future<bool> clearCart() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      await _supabase
          .from('cart_items')
          .delete()
          .eq('user_id', user.id)
          .inFilter('status', ['active', 'saved_for_later']);

      // Invalidate cart cache
      _invalidateCartCache(user.id);

      return true;
    } catch (e) {
      print('Error clearing cart: $e');
      return false;
    }
  }

  /// Convert database cart item to CartItem model
  CartItem _mapToCartItem(Map<String, dynamic> data) {
    DateTime? bookingDate;
    if (data['booking_date'] != null) {
      try {
        bookingDate = DateTime.parse(data['booking_date'] as String);
      } catch (e) {
        print('Error parsing booking_date: $e');
      }
    }

    TimeOfDay? bookingTime;
    if (data['booking_time'] != null) {
      try {
        final timeStr = data['booking_time'] as String;
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          bookingTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
      } catch (e) {
        print('Error parsing booking_time: $e');
      }
    }

    return CartItem(
      id: data['service_id'] as String,
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      subtitle: data['subtitle'] as String?,
      bookingDate: bookingDate,
      bookingTime: bookingTime,
    );
  }

  /// Load cart items and convert to CartItem list
  Future<List<CartItem>> loadCartItems() async {
    final items = await getCartItems();
    return items.map((item) => _mapToCartItem(item)).toList();
  }

  /// Load saved for later items and convert to CartItem list
  Future<List<CartItem>> loadSavedItems() async {
    final items = await getSavedForLater();
    return items.map((item) => _mapToCartItem(item)).toList();
  }

  /// Invalidate cart cache for user
  void _invalidateCartCache(String userId) {
    CacheManager.instance.invalidate('cart_items:$userId:active');
    CacheManager.instance.invalidate('cart_items:$userId:saved');
  }
}
