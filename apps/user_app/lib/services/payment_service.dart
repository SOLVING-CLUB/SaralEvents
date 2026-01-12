import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'razorpay_service.dart';
import '../checkout/checkout_state.dart';
import '../checkout/payment_result_screen.dart';
import 'order_service.dart';
import 'booking_service.dart';
import 'booking_draft_service.dart';
import 'payment_milestone_service.dart';
import '../core/cache/simple_cache.dart';

/// Comprehensive payment service that handles the complete payment flow
class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final RazorpayService _razorpayService = RazorpayService();
  String? _currentOrderId; // our app's order id
  String? _currentDraftId; // booking draft id if coming from booking screen

  /// Process payment with comprehensive error handling and user feedback
  Future<void> processPayment({
    required BuildContext context,
    required CheckoutState checkoutState,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
    String? draftId, // Optional draft ID for booking creation after payment
  }) async {
    try {
      // Validate checkout state
      if (checkoutState.items.isEmpty) {
        _showError(context, 'No items in cart');
        return;
      }

      if (checkoutState.billingDetails == null) {
        _showError(context, 'Billing details not provided');
        return;
      }

      // Get user details
      final user = Supabase.instance.client.auth.currentUser;
      final billingDetails = checkoutState.billingDetails!;
      
      // Prepare payment details
      final amountPaise = (checkoutState.totalPrice * 100).round();
      final receipt = 'ord_${DateTime.now().millisecondsSinceEpoch}';
      
      if (kDebugMode) {
        debugPrint('Processing payment:');
        debugPrint('Amount: ₹${checkoutState.totalPrice} (${amountPaise} paise)');
        debugPrint('Items: ${checkoutState.items.length}');
        debugPrint('User: ${billingDetails.name} (${billingDetails.email})');
      }

      // Store draft ID if provided
      _currentDraftId = draftId;
      if (kDebugMode) {
        debugPrint('=== PAYMENT PROCESSING START ===');
        debugPrint('Draft ID from parameter: $draftId');
        debugPrint('Draft ID from checkoutState: ${checkoutState.draftId}');
        debugPrint('Stored _currentDraftId: $_currentDraftId');
      }
      
      // Create application pending order in Supabase
      final orderService = OrderService(Supabase.instance.client);
      _currentOrderId = await orderService.createPendingOrder(
        checkout: checkoutState,
        extra: {
          'source': 'user_app',
          if (draftId != null) 'draft_id': draftId,
        },
      );

      // Create gateway order on server (Edge Function or direct HTTP)
      final order = await _razorpayService.createOrderOnServer(
        amountInPaise: amountPaise,
        currency: 'INR',
        receipt: receipt,
        notes: {
          'app': 'saral_user',
          'user_id': user?.id ?? 'anonymous',
          'user_name': billingDetails.name,
          'user_email': billingDetails.email,
          'user_phone': billingDetails.phone,
          'items_count': checkoutState.items.length.toString(),
          'total_amount': checkoutState.totalPrice.toString(),
          'event_date': billingDetails.eventDate?.toIso8601String(),
          'message_to_vendor': billingDetails.messageToVendor,
        },
      );

      // Attach gateway order id to our order
      await orderService.attachRazorpayOrder(
        orderId: _currentOrderId!,
        razorpayOrderId: order['id'] as String,
        amountPaise: amountPaise,
      );

      // Initialize Razorpay
      _razorpayService.init(
        onSuccess: (paymentId, responseData) {
          // Handle payment success asynchronously
          _handlePaymentSuccess(
            context: context,
            paymentId: paymentId,
            responseData: responseData,
            checkoutState: checkoutState,
            onSuccessCallback: onSuccess,
          ).catchError((e) {
            if (kDebugMode) {
              debugPrint('Error in payment success handler: $e');
            }
          });
        },
        onError: (code, message, errorData) {
          _handlePaymentError(
            context: context,
            code: code,
            message: message,
            errorData: errorData,
            checkoutState: checkoutState,
            onSuccess: onSuccess,
            onFailure: onFailure,
          );
        },
        onExternalWallet: (walletName) {
          _showInfo(context, 'Redirecting to $walletName...');
        },
      );

      // Open Razorpay checkout
      _razorpayService.openCheckout(
        amountInPaise: amountPaise,
        name: 'Saral Events',
        description: 'Service payment for ${checkoutState.items.length} item(s)',
        orderId: order['id'] as String,
        prefillName: billingDetails.name,
        prefillEmail: billingDetails.email,
        prefillContact: billingDetails.phone,
        notes: {
          'app': 'saral_user',
          'user_id': user?.id ?? 'anonymous',
          'items_count': checkoutState.items.length.toString(),
          'total_amount': checkoutState.totalPrice.toString(),
        },
      );

    } catch (e) {
      if (kDebugMode) {
        debugPrint('Payment processing error: $e');
      }
      _showError(context, 'Failed to process payment: $e');
      onFailure();
    }
  }

  /// Handle successful payment
  Future<void> _handlePaymentSuccess({
    required BuildContext context,
    required String paymentId,
    required Map<String, dynamic> responseData,
    required CheckoutState checkoutState,
    required VoidCallback onSuccessCallback,
  }) async {
    if (kDebugMode) {
      debugPrint('Payment successful: $paymentId');
      debugPrint('Response data: $responseData');
    }

    // Mark order paid
    final orderService = OrderService(Supabase.instance.client);
    if (_currentOrderId != null) {
      orderService.markPaid(
        orderId: _currentOrderId!,
        paymentId: paymentId,
        gatewayResponse: responseData,
      );
    }

    // Create booking from draft if draft ID exists
    if (kDebugMode) {
      debugPrint('=== BOOKING CREATION CHECK ===');
      debugPrint('_currentDraftId: $_currentDraftId');
      debugPrint('checkoutState.draftId: ${checkoutState.draftId}');
    }
    
    if (_currentDraftId != null) {
      if (kDebugMode) {
        debugPrint('✅ Draft ID found, creating booking...');
      }
      try {
        await _createBookingFromDraft(
          draftId: _currentDraftId!,
          paymentId: paymentId,
          gatewayOrderId: responseData['orderId']?.toString(),
          gatewayPaymentId: paymentId,
        );
        if (kDebugMode) {
          debugPrint('✅ Booking created successfully from draft: $_currentDraftId');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ ERROR creating booking from draft: $e');
          debugPrint('Stack trace: $stackTrace');
        }
        // Show error to user even though payment succeeded
        // Don't fail the payment flow if booking creation fails
        // Admin can manually create booking if needed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful but booking creation failed. Please contact support. Error: ${e.toString().substring(0, 100)}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ WARNING: No draft ID found! Booking will not be created.');
        debugPrint('This means either:');
        debugPrint('  1. Draft was not created before payment');
        debugPrint('  2. Draft ID was not passed to processPayment');
        debugPrint('  3. CheckoutState.draftId is null');
      }
      // Try to create booking anyway if we have billing details
      // This is a fallback for cases where draft wasn't created
      try {
        if (checkoutState.items.isNotEmpty && checkoutState.billingDetails != null) {
          final item = checkoutState.items.first;
          final billing = checkoutState.billingDetails!;
          
          // Get vendor_id from service
          final serviceResult = await Supabase.instance.client
              .from('services')
              .select('vendor_id')
              .eq('id', item.id)
              .maybeSingle();
          
          if (serviceResult != null && billing.eventDate != null) {
            if (kDebugMode) {
              debugPrint('Attempting to create booking without draft...');
            }
            
            final bookingService = BookingService(Supabase.instance.client);
            final success = await bookingService.createBooking(
              serviceId: item.id,
              vendorId: serviceResult['vendor_id'] as String,
              bookingDate: billing.eventDate!,
              bookingTime: null,
              amount: item.price,
              notes: billing.messageToVendor,
            );
            
            if (success) {
              if (kDebugMode) {
                debugPrint('✅ Booking created successfully without draft');
              }
            } else {
              if (kDebugMode) {
                debugPrint('❌ Failed to create booking without draft');
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error in fallback booking creation: $e');
        }
      }
    }

    // Show success screen on root navigator to ensure it's above CheckoutFlow
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) => PaymentResultScreen(
          isSuccess: true,
          paymentId: paymentId,
          responseData: responseData,
          amount: checkoutState.totalPrice,
          itemsCount: checkoutState.items.length,
          onContinue: () {
            // Close payment result screen (on root navigator)
            Navigator.of(context, rootNavigator: true).pop();
            
            // Pop CheckoutFlow itself (which is on the main navigator)
            // The stack structure: [Previous Screen] -> CheckoutFlow -> PaymentResultScreen (just popped)
            // We want to pop back to [Previous Screen]
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            
            // Call success callback after navigation completes
            Future.delayed(const Duration(milliseconds: 300), () {
              if (context.mounted) {
                try {
                  onSuccessCallback();
                } catch (e) {
                  debugPrint('Error in payment success callback: $e');
                }
              }
            });
          },
        ),
      ),
    );
  }

  /// Handle payment error
  void _handlePaymentError({
    required BuildContext context,
    required String code,
    required String message,
    required Map<String, dynamic>? errorData,
    required CheckoutState checkoutState,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) {
    if (kDebugMode) {
      debugPrint('Payment failed: $code - $message');
      debugPrint('Error data: $errorData');
    }

    // Mark order failed
    final orderService = OrderService(Supabase.instance.client);
    if (_currentOrderId != null) {
      orderService.markFailed(
        orderId: _currentOrderId!,
        code: code,
        message: message,
        errorData: errorData,
      );
    }

    // Show error screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PaymentResultScreen(
          isSuccess: false,
          errorMessage: message,
          responseData: errorData,
          onRetry: () {
            Navigator.of(context).pop(); // Close error screen
            // Retry payment
            processPayment(
              context: context,
              checkoutState: checkoutState,
              onSuccess: onSuccess,
              onFailure: onFailure,
            );
          },
          onContinue: () {
            Navigator.of(context).pop(); // Close error screen
            onFailure();
          },
        ),
      ),
    );
  }

  /// Show error message
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show info message
  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Create booking from draft after payment success
  Future<void> _createBookingFromDraft({
    required String draftId,
    required String paymentId,
    String? gatewayOrderId,
    String? gatewayPaymentId,
  }) async {
    BookingDraftService? draftService;
    try {
      draftService = BookingDraftService(Supabase.instance.client);
      final bookingService = BookingService(Supabase.instance.client);
      
      // Get draft details
      final draft = await draftService.getDraft(draftId);
      if (draft == null) {
        throw Exception('Draft not found');
      }

      // Create booking from draft (use event_date if booking_date is null)
      final bookingDateValue = draft['booking_date'] ?? draft['event_date'];
      if (bookingDateValue == null) {
        throw Exception('Booking date or event date is required to create booking');
      }

      if (kDebugMode) {
        debugPrint('Creating booking from draft:');
        debugPrint('  Draft ID: $draftId');
        debugPrint('  Service ID: ${draft['service_id']}');
        debugPrint('  Vendor ID: ${draft['vendor_id']}');
        debugPrint('  Booking Date: $bookingDateValue (from ${draft['booking_date'] != null ? 'booking_date' : 'event_date'})');
        debugPrint('  Amount: ${draft['amount']}');
      }

      final success = await bookingService.createBooking(
        serviceId: draft['service_id'] as String,
        vendorId: draft['vendor_id'] as String,
        bookingDate: DateTime.parse(bookingDateValue as String),
        bookingTime: draft['booking_time'] != null
            ? TimeOfDay(
                hour: int.parse((draft['booking_time'] as String).split(':')[0]),
                minute: int.parse((draft['booking_time'] as String).split(':')[1]),
              )
            : null,
        amount: (draft['amount'] as num).toDouble(),
        notes: draft['notes'] as String?,
      );

      if (kDebugMode) {
        debugPrint('Booking creation result: $success');
      }

      if (success) {
        if (kDebugMode) {
          debugPrint('✅ Booking creation returned success=true');
        }
        
        // Force cache invalidation immediately after booking creation
        CacheManager.instance.invalidate('user:bookings');
        CacheManager.instance.invalidate('user:booking-stats');
        CacheManager.instance.invalidateByPrefix('user:bookings');
        
        // Get the most recently created booking for this user and service
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          if (kDebugMode) {
            debugPrint('Verifying booking was created for user: $userId');
            debugPrint('Looking for booking with:');
            debugPrint('  service_id: ${draft['service_id']}');
            debugPrint('  booking_date: ${draft['booking_date']}');
          }
          
          // Wait a moment for database to commit
          await Future.delayed(const Duration(milliseconds: 500));
          
          final result = await Supabase.instance.client
              .from('bookings')
              .select('id, user_id, status, milestone_status, created_at')
              .eq('user_id', userId)
              .eq('service_id', draft['service_id'] as String)
              .eq('booking_date', bookingDateValue as String)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

          if (result != null) {
            final bookingId = result['id'] as String;
            if (kDebugMode) {
              debugPrint('✅ Booking verified: ID=$bookingId');
              debugPrint('  Status: ${result['status']}');
              debugPrint('  Milestone Status: ${result['milestone_status']}');
              debugPrint('  User ID: ${result['user_id']}');
              debugPrint('  Created At: ${result['created_at']}');
            }
            
            // Mark the advance milestone as paid
            final milestoneService = PaymentMilestoneService(Supabase.instance.client);
            final advanceMilestone = await milestoneService.getNextPendingMilestone(bookingId);
            
            if (advanceMilestone != null) {
              await milestoneService.markMilestonePaid(
                milestoneId: advanceMilestone.id,
                paymentId: paymentId,
                gatewayOrderId: gatewayOrderId,
                gatewayPaymentId: gatewayPaymentId,
              );
              if (kDebugMode) {
                debugPrint('✅ Advance milestone marked as paid');
              }
            } else {
              if (kDebugMode) {
                debugPrint('⚠️ No advance milestone found for booking');
              }
            }
          } else {
            if (kDebugMode) {
              debugPrint('❌ ERROR: Booking creation returned success=true but booking not found in database!');
              debugPrint('This indicates a potential RLS issue or user_id mismatch');
              debugPrint('Attempting to query all bookings for user to debug...');
              
              // Debug: Try to see all bookings for this user
              try {
                final allBookings = await Supabase.instance.client
                    .from('bookings')
                    .select('id, service_id, booking_date, status, created_at')
                    .eq('user_id', userId)
                    .order('created_at', ascending: false)
                    .limit(5);
                
                debugPrint('Found ${allBookings.length} total bookings for user');
                for (final b in allBookings) {
                  debugPrint('  Booking: ${b['id']}, Service: ${b['service_id']}, Date: ${b['booking_date']}, Status: ${b['status']}');
                }
              } catch (debugError) {
                debugPrint('Error querying bookings for debug: $debugError');
              }
            }
            throw Exception('Booking created but not found in database - possible RLS issue');
          }
        } else {
          if (kDebugMode) {
            debugPrint('❌ ERROR: User ID is null, cannot verify booking');
          }
          throw Exception('User ID is null');
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ ERROR: Booking creation returned false');
          debugPrint('Check the console logs above for detailed error messages');
        }
        throw Exception('Booking creation failed - check logs for details');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ CRITICAL ERROR creating booking from draft: $e');
        debugPrint('Full stack trace: $stackTrace');
        debugPrint('This error is being rethrown to ensure it is handled properly');
      }
      // Rethrow the error so the caller can show it to the user
      // The payment succeeded, but booking creation failed - user needs to know
      rethrow;
    } finally {
      // Always try to mark the draft as completed so it doesn't remain stuck in "payment_pending"
      try {
        draftService ??= BookingDraftService(Supabase.instance.client);
        await draftService.markDraftCompleted(draftId);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error marking draft as completed after payment: $e');
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _razorpayService.dispose();
  }
}
