import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BookingDraftService {
  final SupabaseClient _supabase;

  BookingDraftService(this._supabase);

  /// Save booking details as draft
  Future<String?> saveDraft({
    required String serviceId,
    required String vendorId,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
    required double amount,
    String? notes,
    // Billing details
    String? billingName,
    String? billingEmail,
    String? billingPhone,
    DateTime? eventDate,
    String? messageToVendor,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Error: No authenticated user found');
        return null;
      }

      final draftData = {
        'user_id': userId,
        'service_id': serviceId,
        'vendor_id': vendorId,
        'booking_date': bookingDate?.toIso8601String().split('T')[0],
        'booking_time': bookingTime != null 
            ? '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}'
            : null,
        'amount': amount,
        'notes': notes,
        'billing_name': billingName,
        'billing_email': billingEmail,
        'billing_phone': billingPhone,
        'event_date': eventDate?.toIso8601String().split('T')[0],
        'message_to_vendor': messageToVendor,
        'status': 'draft',
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      };

      final result = await _supabase
          .from('booking_drafts')
          .insert(draftData)
          .select('id')
          .single();

      return result['id'] as String;
    } catch (e, stackTrace) {
      print('Error saving booking draft: $e');
      print('Stack trace: $stackTrace');
      // Check if it's a table not found error
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('relation') && errorStr.contains('does not exist')) {
        print('ERROR: booking_drafts table does not exist. Please run booking_drafts_schema.sql in your Supabase database');
        rethrow; // Re-throw to show user the actual error
      }
      rethrow; // Re-throw to show user the actual error
    }
  }

  /// Get user's active drafts
  Future<List<Map<String, dynamic>>> getUserDrafts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final result = await _supabase
          .from('booking_drafts')
          .select('''
            *,
            services!inner(id, name, price, description),
            vendor_profiles!inner(id, business_name, category)
          ''')
          .eq('user_id', userId)
          .eq('status', 'draft')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Error fetching drafts: $e');
      return [];
    }
  }

  /// Get a specific draft
  Future<Map<String, dynamic>?> getDraft(String draftId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final result = await _supabase
          .from('booking_drafts')
          .select('''
            *,
            services!inner(id, name, price, description),
            vendor_profiles!inner(id, business_name, category)
          ''')
          .eq('id', draftId)
          .eq('user_id', userId)
          .maybeSingle();

      return result != null ? Map<String, dynamic>.from(result) : null;
    } catch (e) {
      print('Error fetching draft: $e');
      return null;
    }
  }

  /// Update draft status to payment_pending
  Future<bool> markDraftPaymentPending(String draftId) async {
    try {
      await _supabase
          .from('booking_drafts')
          .update({
            'status': 'payment_pending',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', draftId);

      return true;
    } catch (e) {
      print('Error updating draft status: $e');
      return false;
    }
  }

  /// Update draft with billing details
  Future<bool> updateDraftBillingDetails({
    required String draftId,
    String? billingName,
    String? billingEmail,
    String? billingPhone,
    DateTime? eventDate,
    String? messageToVendor,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      if (billingName != null) updateData['billing_name'] = billingName;
      if (billingEmail != null) updateData['billing_email'] = billingEmail;
      if (billingPhone != null) updateData['billing_phone'] = billingPhone;
      if (eventDate != null) updateData['event_date'] = eventDate.toIso8601String().split('T')[0];
      if (messageToVendor != null) updateData['message_to_vendor'] = messageToVendor;

      await _supabase
          .from('booking_drafts')
          .update(updateData)
          .eq('id', draftId);

      return true;
    } catch (e) {
      print('Error updating draft billing details: $e');
      return false;
    }
  }

  /// Create or update draft from checkout state (when billing details are saved)
  Future<String?> saveDraftFromCheckout({
    required String serviceId,
    required String vendorId,
    required double amount,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
    String? notes,
    String? billingName,
    String? billingEmail,
    String? billingPhone,
    DateTime? eventDate,
    String? messageToVendor,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Error: No authenticated user found');
        return null;
      }

      // Check if draft already exists for this service
      final existingDraft = await _supabase
          .from('booking_drafts')
          .select('id')
          .eq('user_id', userId)
          .eq('service_id', serviceId)
          .eq('status', 'draft')
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (existingDraft != null) {
        // Update existing draft
        final draftId = existingDraft['id'] as String;
        final updateData = <String, dynamic>{
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        // Use eventDate as bookingDate if bookingDate is not provided
        final finalBookingDate = bookingDate ?? eventDate;
        if (finalBookingDate != null) {
          updateData['booking_date'] = finalBookingDate.toIso8601String().split('T')[0];
        }
        if (bookingTime != null) {
          updateData['booking_time'] = '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}';
        }
        if (notes != null) updateData['notes'] = notes;
        if (billingName != null) updateData['billing_name'] = billingName;
        if (billingEmail != null) updateData['billing_email'] = billingEmail;
        if (billingPhone != null) updateData['billing_phone'] = billingPhone;
        if (eventDate != null) updateData['event_date'] = eventDate.toIso8601String().split('T')[0];
        if (messageToVendor != null) updateData['message_to_vendor'] = messageToVendor;

        await _supabase
            .from('booking_drafts')
            .update(updateData)
            .eq('id', draftId);

        return draftId;
      } else {
        // Create new draft
        // Use eventDate as bookingDate if bookingDate is not provided
        final finalBookingDate = bookingDate ?? eventDate;
        return await saveDraft(
          serviceId: serviceId,
          vendorId: vendorId,
          bookingDate: finalBookingDate,
          bookingTime: bookingTime,
          amount: amount,
          notes: notes,
          billingName: billingName,
          billingEmail: billingEmail,
          billingPhone: billingPhone,
          eventDate: eventDate,
          messageToVendor: messageToVendor,
        );
      }
    } catch (e) {
      print('Error saving draft from checkout: $e');
      return null;
    }
  }

  /// Mark draft as completed (booking created)
  Future<bool> markDraftCompleted(String draftId) async {
    try {
      await _supabase
          .from('booking_drafts')
          .update({
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', draftId);

      return true;
    } catch (e) {
      print('Error marking draft as completed: $e');
      return false;
    }
  }

  /// Delete a draft
  Future<bool> deleteDraft(String draftId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await _supabase
          .from('booking_drafts')
          .delete()
          .eq('id', draftId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      print('Error deleting draft: $e');
      return false;
    }
  }
}

