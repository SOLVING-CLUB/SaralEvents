import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'razorpay_service.dart';
import '../checkout/checkout_state.dart';
import '../checkout/payment_result_screen.dart';
import '../screens/order_status_screen.dart';
import 'order_service.dart';
import 'booking_service.dart';
import 'booking_draft_service.dart';
import 'payment_milestone_service.dart';
import 'availability_service.dart';
import 'notification_sender_service.dart';
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
      
      // Check slot availability before processing payment
      // If any slot is already booked, remove item from cart and show error
      final availabilityService = AvailabilityService(Supabase.instance.client);
      final itemsToRemove = <int>[];
      
      for (int i = 0; i < checkoutState.items.length; i++) {
        final item = checkoutState.items[i];
        if (item.bookingDate != null && item.bookingTime != null) {
          // Check if this slot is still available
          final availableSlots = await availabilityService.getAvailableTimeSlots(
            item.id,
            item.bookingDate!,
          );
          
          // Convert bookingTime to time string format (HH:mm)
          final timeStr = '${item.bookingTime!.hour.toString().padLeft(2, '0')}:${item.bookingTime!.minute.toString().padLeft(2, '0')}';
          
          // Check if the selected time slot is still in the available slots
          bool slotAvailable = false;
          for (final slot in availableSlots) {
            final startTime = slot['start_time'] as String?;
            final endTime = slot['end_time'] as String?;
            if (startTime != null && endTime != null) {
              // Check if booking time falls within this slot range
              if (_isTimeInRange(timeStr, startTime, endTime)) {
                slotAvailable = true;
                break;
              }
            }
          }
          
          if (!slotAvailable) {
            // Slot is no longer available, mark for removal
            itemsToRemove.add(i);
            if (kDebugMode) {
              debugPrint('⚠️ Slot no longer available for ${item.title}');
              debugPrint('   Date: ${item.bookingDate}, Time: $timeStr');
            }
          }
        }
      }
      
        // Remove unavailable items from cart
        if (itemsToRemove.isNotEmpty) {
          // Remove items in reverse order to maintain correct indices
          itemsToRemove.sort((a, b) => b.compareTo(a));
          for (final index in itemsToRemove) {
            await checkoutState.removeItemAt(index);
          }
        
        // Show error message
        final removedCount = itemsToRemove.length;
        final itemText = removedCount == 1 ? 'item' : 'items';
        _showError(
          context,
          '$removedCount service $itemText is no longer available. The selected time slot has been booked by another user. The unavailable $itemText has been removed from your cart.',
        );
        
        // If cart is now empty, return
        if (checkoutState.items.isEmpty) {
          return;
        }
      }
      
      // Calculate advance payment (20% of total after discount) for milestone-based payment
      final totalAfterDiscount = checkoutState.totalAfterDiscount;
      final advanceAmount = totalAfterDiscount * 0.20;
      final amountPaise = (advanceAmount * 100).round();
      final receipt = 'ord_${DateTime.now().millisecondsSinceEpoch}';
      
      if (kDebugMode) {
        debugPrint('Processing payment:');
        debugPrint('Total Amount: ₹${checkoutState.totalPrice}');
        if (checkoutState.discountAmount > 0) {
          debugPrint('Discount: ₹${checkoutState.discountAmount}');
          debugPrint('Total after discount: ₹$totalAfterDiscount');
        }
        debugPrint('Advance Payment (20%): ₹${advanceAmount.toStringAsFixed(2)} ($amountPaise paise)');
        debugPrint('Items: ${checkoutState.items.length}');
        debugPrint('User: ${billingDetails.name} (${billingDetails.email})');
      }

      // Get draft ID from checkout state
      _currentDraftId = checkoutState.draftId;
      if (kDebugMode) {
        debugPrint('=== PAYMENT PROCESSING START ===');
        debugPrint('Draft ID from checkoutState: ${checkoutState.draftId}');
        debugPrint('Stored _currentDraftId: $_currentDraftId');
      }
      
      // Create application pending order in Supabase
      final orderService = OrderService(Supabase.instance.client);
      _currentOrderId = await orderService.createPendingOrder(
        checkout: checkoutState,
        extra: {
          'source': 'user_app',
          if (_currentDraftId != null) 'draft_id': _currentDraftId,
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
          'total_amount': totalAfterDiscount.toString(),
          'advance_amount': advanceAmount.toString(),
          'payment_type': 'advance',
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
      if (kDebugMode) {
        debugPrint('🔧 Initializing Razorpay...');
      }
      
      _razorpayService.init(
        onSuccess: (paymentId, responseData) {
          if (kDebugMode) {
            debugPrint('✅ Razorpay payment success callback received');
          }
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
          if (kDebugMode) {
            debugPrint('❌ Razorpay payment error callback received: $code - $message');
          }
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
          if (kDebugMode) {
            debugPrint('🔗 External wallet selected: $walletName');
          }
          _showInfo(context, 'Redirecting to $walletName...');
        },
      );
      
      if (kDebugMode) {
        debugPrint('✅ Razorpay initialized successfully');
      }

      // Open Razorpay checkout
      if (kDebugMode) {
        debugPrint('🚀 Opening Razorpay checkout...');
        debugPrint('   Order ID: ${order['id']}');
        debugPrint('   Total Amount: ₹$totalAfterDiscount');
        debugPrint('   Advance Payment (20%): ₹${advanceAmount.toStringAsFixed(2)} ($amountPaise paise)');
        debugPrint('   Razorpay initialized: ${_razorpayService.isInitialized}');
      }
      
      _razorpayService.openCheckout(
        amountInPaise: amountPaise,
        name: 'Saral Events',
        description: 'Advance payment (20%) for ${checkoutState.items.length} item(s) - Total: ₹${totalAfterDiscount.toStringAsFixed(0)}',
        orderId: order['id'] as String,
        prefillName: billingDetails.name,
        prefillEmail: billingDetails.email,
        prefillContact: billingDetails.phone,
        notes: {
          'app': 'saral_user',
          'user_id': user?.id ?? 'anonymous',
          'items_count': checkoutState.items.length.toString(),
          'total_amount': totalAfterDiscount.toString(),
          'advance_amount': advanceAmount.toString(),
          'payment_type': 'advance',
        },
      );
      
      if (kDebugMode) {
        debugPrint('✅ Razorpay checkout opened successfully');
      }

    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Payment processing error: $e');
        debugPrint('❌ Stack trace: $stackTrace');
      }
      _showError(context, 'Failed to process payment: ${e.toString()}');
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

    // Get user ID for notifications
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final notificationService = NotificationSenderService(Supabase.instance.client);

    // Mark order paid
    final orderService = OrderService(Supabase.instance.client);
    if (_currentOrderId != null) {
      orderService.markPaid(
        orderId: _currentOrderId!,
        paymentId: paymentId,
        gatewayResponse: responseData,
      );
    }

    // Create bookings for all cart items (each service gets its own booking)
    if (kDebugMode) {
      debugPrint('=== BOOKING CREATION CHECK ===');
      debugPrint('Cart items count: ${checkoutState.items.length}');
      debugPrint('_currentDraftId: $_currentDraftId');
      debugPrint('checkoutState.draftId: ${checkoutState.draftId}');
    }
    
    final billing = checkoutState.billingDetails;
    if (billing == null) {
      if (kDebugMode) {
        debugPrint('⚠️ WARNING: No billing details found! Bookings will not be created.');
      }
    } else {
      try {
        final bookingService = BookingService(Supabase.instance.client);
        final milestoneService = PaymentMilestoneService(Supabase.instance.client);
        final List<String> createdBookingIds = [];
        
        // Create a booking for each cart item
        for (int i = 0; i < checkoutState.items.length; i++) {
          final item = checkoutState.items[i];
          
          if (kDebugMode) {
            debugPrint('Creating booking ${i + 1}/${checkoutState.items.length} for service: ${item.title}');
          }
          
          try {
            // Get vendor_id from service
            final serviceResult = await Supabase.instance.client
                .from('services')
                .select('vendor_id')
                .eq('id', item.id)
                .maybeSingle();
            
            if (serviceResult == null) {
              if (kDebugMode) {
                debugPrint('⚠️ Service not found for item: ${item.id}');
              }
              continue;
            }
            
            // Use item's booking date if available, otherwise use billing event date
            final bookingDate = item.bookingDate ?? billing.eventDate;
            if (bookingDate == null) {
              if (kDebugMode) {
                debugPrint('⚠️ No booking date available for item: ${item.title}');
              }
              continue;
            }
            
            // Apply coupon discount to first booking only
            final isFirstItem = i == 0;
            final couponId = checkoutState.appliedCouponId;
            final orderDiscount = checkoutState.discountAmount;
            double bookingAmount = item.price;
            double bookingDiscount = 0;
            if (isFirstItem && couponId != null && orderDiscount > 0) {
              bookingDiscount = orderDiscount < item.price ? orderDiscount : item.price;
              bookingAmount = item.price - bookingDiscount;
            }
            
            // Create booking for this service
            if (kDebugMode) {
              debugPrint('💳 PaymentService: Creating booking for service: ${item.title}');
              debugPrint('   serviceId: ${item.id}');
              debugPrint('   vendorId: ${serviceResult['vendor_id']}');
              debugPrint('   bookingDate: $bookingDate');
              debugPrint('   amount: $bookingAmount');
              if (bookingDiscount > 0) debugPrint('   discount: $bookingDiscount');
              debugPrint('   Expected status: pending');
              debugPrint('   Expected milestone_status: created');
            }
            
            final createdBookingId = await bookingService.createBooking(
              serviceId: item.id,
              vendorId: serviceResult['vendor_id'] as String,
              bookingDate: bookingDate,
              bookingTime: item.bookingTime,
              amount: bookingAmount,
              notes: billing.messageToVendor,
              locationLink: item.locationLink,
              couponId: isFirstItem ? couponId : null,
              discountAmount: bookingDiscount,
            );
            
            if (createdBookingId != null) {
              if (kDebugMode) {
                debugPrint('✅ PaymentService: Booking created successfully for: ${item.title}');
                debugPrint('   Verifying booking was created with correct status...');
              }
              
              createdBookingIds.add(createdBookingId);
              
              // Record coupon redemption for first booking when coupon was applied
              final userId = Supabase.instance.client.auth.currentUser?.id;
              if (isFirstItem && couponId != null && userId != null && bookingDiscount > 0) {
                try {
                  await Supabase.instance.client.rpc(
                    'record_coupon_redemption',
                    params: {
                      'p_coupon_id': couponId,
                      'p_user_id': userId,
                      'p_booking_id': createdBookingId,
                      'p_phone': billing.phone,
                      'p_discount_amount': bookingDiscount,
                    },
                  );
                  if (kDebugMode) debugPrint('✅ Coupon redemption recorded for booking: $createdBookingId');
                } catch (e) {
                  if (kDebugMode) debugPrint('⚠️ Failed to record coupon redemption: $e');
                }
              }
              
              // Verify the booking was created with correct status
              await Future.delayed(const Duration(milliseconds: 500));
              final verifyResult = await Supabase.instance.client
                  .from('bookings')
                  .select('id, status, milestone_status')
                  .eq('id', createdBookingId)
                  .maybeSingle();
              
              if (verifyResult != null && kDebugMode) {
                debugPrint('✅ PaymentService: Verified booking ${verifyResult['id']}');
                debugPrint('   Actual status: ${verifyResult['status']}');
                debugPrint('   Actual milestone_status: ${verifyResult['milestone_status']}');
                if (verifyResult['status'] != 'pending' || verifyResult['milestone_status'] != 'created') {
                  debugPrint('⚠️ WARNING: Booking created with incorrect status!');
                  debugPrint('   Expected: status=pending, milestone_status=created');
                  debugPrint('   Actual: status=${verifyResult['status']}, milestone_status=${verifyResult['milestone_status']}');
                }
              }
              
              // Mark the advance milestone as paid for this booking
              final advanceMilestone = await milestoneService.getNextPendingMilestone(createdBookingId);
              if (advanceMilestone != null) {
                await milestoneService.markMilestonePaid(
                  milestoneId: advanceMilestone.id,
                  paymentId: paymentId,
                  gatewayOrderId: responseData['orderId']?.toString(),
                  gatewayPaymentId: paymentId,
                );
                if (kDebugMode) {
                  debugPrint('✅ Advance milestone marked as paid for booking: $createdBookingId');
                }
              } else {
                if (kDebugMode) {
                  debugPrint('⚠️ No advance milestone found for booking: $createdBookingId');
                }
              }
            } else {
              if (kDebugMode) {
                debugPrint('❌ Failed to create booking for: ${item.title}');
              }
            }
          } catch (e, stackTrace) {
            if (kDebugMode) {
              debugPrint('❌ ERROR creating booking for ${item.title}: $e');
              debugPrint('Stack trace: $stackTrace');
            }
            // Continue with other items even if one fails
          }
        }
        
        // Force cache invalidation after all bookings are created
        CacheManager.instance.invalidate('user:bookings');
        CacheManager.instance.invalidate('user:booking-stats');
        CacheManager.instance.invalidateByPrefix('user:bookings');
        
        if (kDebugMode) {
          debugPrint('✅ Created ${createdBookingIds.length} booking(s) out of ${checkoutState.items.length} item(s)');
        }
        
        // Show warning if some bookings failed
        if (createdBookingIds.length < checkoutState.items.length) {
          final failedCount = checkoutState.items.length - createdBookingIds.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment successful. $failedCount booking(s) could not be created. Please contact support.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ CRITICAL ERROR creating bookings: $e');
          debugPrint('Stack trace: $stackTrace');
        }
        // Show error to user even though payment succeeded
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment successful but booking creation failed. Please contact support. Error: ${e.toString().substring(0, 100)}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }

    // Store cart details before clearing (needed for success screen)
    // IMPORTANT: at this stage we only charge the advance (20%), not the full total.
    final paidAmount = checkoutState.totalAfterDiscount * 0.20;
    final paidItemsCount = checkoutState.items.length;
    
    // Get service details for notifications (before clearing cart)
    String? vendorId;
    String? serviceName;
    DateTime? bookingDate;
    String? bookingTime;
    
    // Try to get vendor and service info from draft or cart items
    if (_currentDraftId != null) {
      try {
        final draftService = BookingDraftService(Supabase.instance.client);
        final draft = await draftService.getDraft(_currentDraftId!);
        if (draft != null) {
          vendorId = draft['vendor_id'] as String?;
          final serviceId = draft['service_id'] as String?;
          if (serviceId != null) {
            // Get service name
            final serviceResult = await Supabase.instance.client
                .from('services')
                .select('name')
                .eq('id', serviceId)
                .maybeSingle();
            if (serviceResult != null) {
              serviceName = serviceResult['name'] as String?;
            }
          }
          final bookingDateValue = draft['booking_date'] ?? draft['event_date'];
          if (bookingDateValue != null) {
            bookingDate = DateTime.parse(bookingDateValue as String);
          }
          bookingTime = draft['booking_time'] as String?;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error getting draft details for notification: $e');
        }
      }
    }
    
    // Fallback: get from cart items if draft info not available
    if (vendorId == null && checkoutState.items.isNotEmpty) {
      try {
        final item = checkoutState.items.first;
        final serviceResult = await Supabase.instance.client
            .from('services')
            .select('vendor_id, name')
            .eq('id', item.id)
            .maybeSingle();
        if (serviceResult != null) {
          vendorId = serviceResult['vendor_id'] as String?;
          serviceName = serviceResult['name'] as String?;
        }
        bookingDate = item.bookingDate;
        bookingTime = item.bookingTime != null
            ? '${item.bookingTime!.hour.toString().padLeft(2, '0')}:${item.bookingTime!.minute.toString().padLeft(2, '0')}'
            : null;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error getting service details for notification: $e');
        }
      }
    }
    
    // Send user notifications about payment success and order placement
    // Note: Database trigger also sends payment notification, but we send more specific messages here
    // The database trigger will be disabled to avoid duplicates (see disable_duplicate_notification_triggers.sql)
    if (userId != null && _currentOrderId != null) {
      try {
        if (kDebugMode) {
          debugPrint('📬 Sending user notifications for payment success...');
          debugPrint('   User ID: $userId');
          debugPrint('   Order ID: $_currentOrderId');
          debugPrint('   Amount: ₹$paidAmount');
        }
        
        // NOTE: Payment and order placement notifications are handled by database triggers
        // to avoid duplicates. Database triggers will send:
        // - Payment success notification (user_app) when payment_milestones status changes
        // - Order placement notification (user_app) when booking is created
        // - New order notification (vendor_app) when booking is created
        if (kDebugMode) {
          debugPrint('✅ Payment notifications will be sent by database triggers');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ Error sending user notification: $e');
          debugPrint('❌ Stack trace: $stackTrace');
        }
        // Don't fail payment flow if notification fails
      }
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ Cannot send user notification: userId=${userId != null}, orderId=${_currentOrderId != null}');
      }
    }
    
    // NOTE: Vendor notification for new order is handled by database trigger
    // when booking status changes to 'confirmed' (or when booking is created)
    // This avoids duplicates and ensures consistent notification delivery
    if (kDebugMode && vendorId != null) {
      debugPrint('✅ Vendor notification will be sent by database trigger');
    }
    
    // Clear the cart after successful payment
    // Remove all items that were just paid for
    if (kDebugMode) {
      debugPrint('🧹 Clearing cart after successful payment');
      debugPrint('   Items in cart before clearing: $paidItemsCount');
      debugPrint('   Total amount paid: ₹$paidAmount');
    }
    
    // Clear the cart - all items in the checkout were paid for
        await checkoutState.clearCart();
        checkoutState.setDraftId(null); // Clear draft ID as well
    
    if (kDebugMode) {
      debugPrint('   ✅ Cart cleared successfully');
      debugPrint('   Items in cart after clearing: ${checkoutState.items.length}');
    }

    // Get booking ID after successful booking creation
    String? bookingId;
    if (_currentDraftId != null) {
      try {
        // Wait a moment for database to commit
        await Future.delayed(const Duration(milliseconds: 500));
        
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          final draftService = BookingDraftService(Supabase.instance.client);
          final draft = await draftService.getDraft(_currentDraftId!);
          if (draft != null) {
            final bookingDateValue = draft['booking_date'] ?? draft['event_date'];
            if (bookingDateValue != null) {
              final result = await Supabase.instance.client
                  .from('bookings')
                  .select('id')
                  .eq('user_id', userId)
                  .eq('service_id', draft['service_id'] as String)
                  .eq('booking_date', bookingDateValue as String)
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();
              
              if (result != null) {
                bookingId = result['id'] as String?;
                if (kDebugMode) {
                  debugPrint('✅ Found booking ID after payment: $bookingId');
                }
              }
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Could not fetch booking ID after payment: $e');
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
          amount: paidAmount,
          itemsCount: paidItemsCount,
          bookingId: bookingId,
          orderId: _currentOrderId,
          onContinue: () {
            // Close payment result screen (on root navigator)
            Navigator.of(context, rootNavigator: true).pop();
            
            // Pop CheckoutFlow itself (which is on the main navigator)
            // The stack structure: [Previous Screen] -> CheckoutFlow -> PaymentResultScreen (just popped)
            // We want to pop back to [Previous Screen]
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            
            // Navigate to order status screen if booking ID is available
            if (bookingId != null || _currentOrderId != null) {
              Future.delayed(const Duration(milliseconds: 300), () {
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => OrderStatusScreen(
                        bookingId: bookingId,
                        orderId: _currentOrderId,
                      ),
                    ),
                  );
                }
              });
            }
            
            // Call success callback after navigation completes
            Future.delayed(const Duration(milliseconds: 600), () {
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
  Future<void> _handlePaymentError({
    required BuildContext context,
    required String code,
    required String message,
    required Map<String, dynamic>? errorData,
    required CheckoutState checkoutState,
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    if (kDebugMode) {
      debugPrint('Payment failed: $code - $message');
      debugPrint('Error data: $errorData');
    }

    // Get user ID for notifications
    final user = Supabase.instance.client.auth.currentUser;
    final userId = user?.id;
    final notificationService = NotificationSenderService(Supabase.instance.client);

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
    
    // Send user notification about payment failure
    if (userId != null) {
      try {
        final amount = checkoutState.totalAfterDiscount;
        
        if (kDebugMode) {
          debugPrint('📬 Sending user notification for payment failure...');
          debugPrint('   User ID: $userId');
          debugPrint('   Order ID: $_currentOrderId');
          debugPrint('   Amount: ₹$amount');
          debugPrint('   Error: $code - $message');
        }
        
        await notificationService.sendPaymentNotification(
          userId: userId,
          orderId: _currentOrderId ?? 'unknown',
          amount: amount,
          isSuccess: false,
        );
        
        if (kDebugMode) {
          debugPrint('✅ Payment failure notification sent successfully');
        }
        
        // Also send order failure notification
        await notificationService.sendNotification(
          userId: userId,
          title: 'Payment Failed',
          body: 'Your payment of ₹${amount.toStringAsFixed(2)} failed. Order was not placed. Please try again.',
          appTypes: ['user_app'], // CRITICAL: Only send to user app
          data: {
            'type': 'payment_failed',
            'order_id': _currentOrderId ?? 'unknown',
            'error_code': code,
            'error_message': message,
            'amount': amount.toString(),
          },
        );
        
        if (kDebugMode) {
          debugPrint('✅ Order failure notification sent successfully');
          debugPrint('✅ All user notifications sent for payment failure');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ Error sending user notification: $e');
          debugPrint('❌ Stack trace: $stackTrace');
        }
        // Don't fail payment flow if notification fails
      }
    } else {
      if (kDebugMode) {
        debugPrint('⚠️ Cannot send user notification: userId is null');
      }
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


  /// Check if a time string (HH:mm) falls within a slot range
  bool _isTimeInRange(String timeStr, String startTime, String endTime) {
    try {
      final timeParts = timeStr.split(':');
      final startParts = startTime.split(':');
      final endParts = endTime.split(':');
      
      if (timeParts.length >= 2 && 
          startParts.length >= 2 && 
          endParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final startHour = int.parse(startParts[0]);
        final startMinute = int.parse(startParts[1]);
        final endHour = int.parse(endParts[0]);
        final endMinute = int.parse(endParts[1]);
        
        final timeMinutes = hour * 60 + minute;
        final startMinutes = startHour * 60 + startMinute;
        final endMinutes = endHour * 60 + endMinute;
        
        // Check if time falls within the range [start, end)
        return timeMinutes >= startMinutes && timeMinutes < endMinutes;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking time range: $e');
      }
    }
    return false;
  }

  /// Process milestone payment (arrival or completion)
  Future<void> processMilestonePayment({
    required BuildContext context,
    required String bookingId,
    required String milestoneType, // 'arrival' or 'completion'
    required VoidCallback onSuccess,
    required VoidCallback onFailure,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('=== MILESTONE PAYMENT PROCESSING START ===');
        debugPrint('Booking ID: $bookingId');
        debugPrint('Milestone Type: $milestoneType');
      }

      // Get milestone details
      final milestoneService = PaymentMilestoneService(Supabase.instance.client);
      final milestones = await milestoneService.getMilestonesForBooking(bookingId);
      
      PaymentMilestone? targetMilestone;
      if (milestoneType == 'arrival') {
        targetMilestone = milestones.firstWhere(
          (m) => m.type == MilestoneType.arrival && m.status == MilestoneStatus.pending,
          orElse: () => milestones.firstWhere(
            (m) => m.type == MilestoneType.arrival,
            orElse: () => throw Exception('Arrival milestone not found'),
          ),
        );
      } else if (milestoneType == 'completion') {
        targetMilestone = milestones.firstWhere(
          (m) => m.type == MilestoneType.completion && m.status == MilestoneStatus.pending,
          orElse: () => milestones.firstWhere(
            (m) => m.type == MilestoneType.completion,
            orElse: () => throw Exception('Completion milestone not found'),
          ),
        );
      } else {
        throw Exception('Invalid milestone type: $milestoneType');
      }

      // Check if already paid
      if (targetMilestone.status != MilestoneStatus.pending) {
        _showInfo(context, 'This milestone has already been paid');
        onSuccess();
        return;
      }

      // Get user details
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showError(context, 'Please sign in to make payment');
        onFailure();
        return;
      }

      // Get user profile for billing details
      final userProfile = await Supabase.instance.client
          .from('user_profiles')
          .select('first_name, last_name, email, phone_number')
          .eq('user_id', user.id)
          .maybeSingle();

      // Combine first_name and last_name, or fallback to email username
      final firstName = userProfile?['first_name'] as String? ?? '';
      final lastName = userProfile?['last_name'] as String? ?? '';
      final userName = firstName.isNotEmpty || lastName.isNotEmpty
          ? '$firstName $lastName'.trim()
          : (user.email?.split('@')[0] ?? 'User');
      final userEmail = userProfile?['email'] as String? ?? user.email ?? '';
      final userPhone = userProfile?['phone_number'] as String? ?? '';

      // Get booking details for description
      final bookingResult = await Supabase.instance.client
          .from('bookings')
          .select('services(name)')
          .eq('id', bookingId)
          .maybeSingle();

      final serviceName = bookingResult?['services']?['name'] as String? ?? 'Service';

      // Calculate amount in paise
      final amountPaise = (targetMilestone.amount * 100).toInt();
      // Generate short receipt (Razorpay limit: 40 chars)
      // Format: ms_<first8chars_of_milestone_id>_<timestamp>
      final milestoneIdShort = targetMilestone.id.replaceAll('-', '').substring(0, 8);
      final receipt = 'ms_${milestoneIdShort}_${DateTime.now().millisecondsSinceEpoch}';

      if (kDebugMode) {
        debugPrint('Milestone Amount: ₹${targetMilestone.amount} ($amountPaise paise)');
        debugPrint('Milestone Percentage: ${targetMilestone.percentage}%');
        debugPrint('Receipt: $receipt');
      }

      // Create Razorpay order
      final order = await _razorpayService.createOrderOnServer(
        amountInPaise: amountPaise,
        currency: 'INR',
        receipt: receipt,
        notes: {
          'app': 'saral_user',
          'user_id': user.id,
          'booking_id': bookingId,
          'milestone_id': targetMilestone.id,
          'milestone_type': milestoneType,
          'milestone_percentage': targetMilestone.percentage.toString(),
          'amount': targetMilestone.amount.toString(),
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Razorpay order created: ${order['id']}');
      }

      // Store milestone details for success callback
      final milestoneId = targetMilestone.id;
      final milestonePercentage = targetMilestone.percentage;
      final milestoneAmount = targetMilestone.amount;

      // Initialize Razorpay with callbacks
      _razorpayService.init(
        onSuccess: (paymentId, responseData) async {
          if (kDebugMode) {
            debugPrint('✅ Milestone payment successful: $paymentId');
          }

          // Mark milestone as paid
          final success = await milestoneService.markMilestonePaid(
            milestoneId: milestoneId,
            paymentId: paymentId,
            gatewayOrderId: order['id'] as String?,
            gatewayPaymentId: paymentId,
          );

          if (!success) {
            if (kDebugMode) {
              debugPrint('❌ Failed to mark milestone as paid');
            }
            _showError(context, 'Payment successful but failed to update milestone. Please contact support.');
            onFailure();
            return;
          }

          // Invalidate cache
          CacheManager.instance.invalidate('user:bookings');
          CacheManager.instance.invalidate('user:booking-stats');
          CacheManager.instance.invalidateByPrefix('user:bookings');

          // Wait a moment for database to commit
          await Future.delayed(const Duration(milliseconds: 500));

          // NOTE: Milestone payment success notifications are handled by database trigger
          // (notify_payment_success) which sends to both user_app and vendor_app
          // This avoids duplicates and ensures consistent notification delivery
          if (kDebugMode) {
            debugPrint('✅ Milestone payment notifications will be sent by database trigger');
          }

          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment successful! $milestonePercentage% milestone (₹${milestoneAmount.toStringAsFixed(2)}) has been paid.',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Call success callback (which will reload order details)
          onSuccess();
        },
        onError: (code, message, responseData) async {
          if (kDebugMode) {
            debugPrint('❌ Milestone payment failed: $code - $message');
          }

          // Send push notification for milestone payment failure (only for failures, not success)
          // Success notifications are handled by database trigger to avoid duplicates
          final notificationService = NotificationSenderService(Supabase.instance.client);
          try {
            final milestoneLabel = milestoneType == 'arrival' ? 'Arrival Payment (50%)' : 'Completion Payment (30%)';
            
            if (kDebugMode) {
              debugPrint('📬 Sending milestone payment failure notification...');
              debugPrint('   Milestone Type: $milestoneType');
              debugPrint('   Amount: ₹$milestoneAmount');
              debugPrint('   Error: $code - $message');
            }

            await notificationService.sendNotification(
              userId: user.id,
              title: 'Payment Failed',
              body: '$milestoneLabel of ₹${milestoneAmount.toStringAsFixed(2)} failed. Please try again.',
              appTypes: ['user_app'], // CRITICAL: Only send to user app
              data: {
                'type': 'milestone_payment_failed',
                'booking_id': bookingId,
                'milestone_id': milestoneId,
                'milestone_type': milestoneType,
                'milestone_percentage': milestonePercentage.toString(),
                'amount': milestoneAmount.toString(),
                'error_code': code,
                'error_message': message,
              },
            );

            if (kDebugMode) {
              debugPrint('✅ Milestone payment failure notification sent');
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('❌ Error sending milestone payment failure notification: $e');
            }
            // Don't fail payment flow if notification fails
          }

          _showError(context, 'Payment failed: $message');
          onFailure();
        },
        onExternalWallet: (walletName) {
          if (kDebugMode) {
            debugPrint('⚠️ External wallet selected: $walletName');
          }
          // External wallet handling - payment will be processed normally
        },
      );

      // Open Razorpay checkout
      final milestoneLabel = milestoneType == 'arrival' ? 'Arrival Payment (50%)' : 'Completion Payment (30%)';
      _razorpayService.openCheckout(
        amountInPaise: amountPaise,
        name: 'Saral Events',
        description: '$milestoneLabel for $serviceName',
        orderId: order['id'] as String,
        prefillName: userName,
        prefillEmail: userEmail,
        prefillContact: userPhone,
        notes: {
          'app': 'saral_user',
          'user_id': user.id,
          'booking_id': bookingId,
          'milestone_id': milestoneId,
          'milestone_type': milestoneType,
        },
      );

      if (kDebugMode) {
        debugPrint('✅ Razorpay checkout opened for milestone payment');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error processing milestone payment: $e');
        debugPrint('❌ Stack trace: $stackTrace');
      }
      _showError(context, 'Failed to process payment: ${e.toString()}');
      onFailure();
    }
  }

  /// Dispose resources
  void dispose() {
    _razorpayService.dispose();
  }
}
