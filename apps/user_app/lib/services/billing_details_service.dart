import 'package:supabase_flutter/supabase_flutter.dart';
import '../checkout/checkout_state.dart';

/// Service to manage saved billing details
class BillingDetailsService {
  final SupabaseClient _supabase;

  BillingDetailsService(this._supabase);

  /// Get all saved billing details for the current user
  Future<List<Map<String, dynamic>>> getSavedBillingDetails() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final result = await _supabase
          .from('saved_billing_details')
          .select('*')
          .eq('user_id', user.id)
          .order('is_default', ascending: false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Error fetching saved billing details: $e');
      return [];
    }
  }

  /// Save billing details
  Future<String?> saveBillingDetails({
    required String name,
    required String email,
    required String phone,
    String? messageToVendor,
    bool isDefault = false,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      // If setting as default, unset other defaults
      if (isDefault) {
        await _supabase
            .from('saved_billing_details')
            .update({'is_default': false})
            .eq('user_id', user.id);
      }

      final data = {
        'user_id': user.id,
        'name': name,
        'email': email,
        'phone': phone,
        'message_to_vendor': messageToVendor,
        'is_default': isDefault,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final result = await _supabase
          .from('saved_billing_details')
          .insert(data)
          .select('id')
          .single();

      return result['id'] as String?;
    } catch (e) {
      print('Error saving billing details: $e');
      return null;
    }
  }

  /// Update billing details
  Future<bool> updateBillingDetails({
    required String id,
    required String name,
    required String email,
    required String phone,
    String? messageToVendor,
    bool? isDefault,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      // If setting as default, unset other defaults
      if (isDefault == true) {
        await _supabase
            .from('saved_billing_details')
            .update({'is_default': false})
            .eq('user_id', user.id)
            .neq('id', id);
      }

      final data = {
        'name': name,
        'email': email,
        'phone': phone,
        'message_to_vendor': messageToVendor,
        'updated_at': DateTime.now().toIso8601String(),
        if (isDefault != null) 'is_default': isDefault,
      };

      await _supabase
          .from('saved_billing_details')
          .update(data)
          .eq('id', id)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      print('Error updating billing details: $e');
      return false;
    }
  }

  /// Delete billing details
  Future<bool> deleteBillingDetails(String id) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return false;

      await _supabase
          .from('saved_billing_details')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      print('Error deleting billing details: $e');
      return false;
    }
  }

  /// Convert database record to BillingDetails
  BillingDetails mapToBillingDetails(Map<String, dynamic> data) {
    DateTime? eventDate;
    if (data['event_date'] != null) {
      try {
        eventDate = DateTime.parse(data['event_date'] as String);
      } catch (e) {
        print('Error parsing event_date: $e');
      }
    }

    return BillingDetails(
      name: data['name'] as String,
      email: data['email'] as String,
      phone: data['phone'] as String,
      eventDate: eventDate,
      messageToVendor: data['message_to_vendor'] as String?,
    );
  }
}
