import 'package:supabase_flutter/supabase_flutter.dart';

class Review {
  final String id;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String userId;
  final String? serviceId;
  final String? vendorId;
  final String? userName;
  final String? serviceName;
  final String? vendorName;

  Review({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.userId,
    this.serviceId,
    this.vendorId,
    this.userName,
    this.serviceName,
    this.vendorName,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    // Handle Supabase response format where relations might be arrays
    final profiles = json['profiles'];
    final services = json['services'];
    final vendorProfiles = json['vendor_profiles'];

    String? userName;
    if (profiles != null) {
      if (profiles is List && profiles.isNotEmpty) {
        userName = profiles[0]['full_name'];
      } else if (profiles is Map) {
        userName = profiles['full_name'];
      }
    }

    // Fallback: use denormalized user_name snapshot on the review row
    userName ??= json['user_name'] as String?;

    String? serviceName;
    if (services != null) {
      if (services is List && services.isNotEmpty) {
        serviceName = services[0]['name'];
      } else if (services is Map) {
        serviceName = services['name'];
      }
    }
    // Fallback: use denormalized service_name snapshot
    serviceName ??= json['service_name'] as String?;

    String? vendorName;
    if (vendorProfiles != null) {
      if (vendorProfiles is List && vendorProfiles.isNotEmpty) {
        vendorName = vendorProfiles[0]['business_name'];
      } else if (vendorProfiles is Map) {
        vendorName = vendorProfiles['business_name'];
      }
    }
    // Fallback: use denormalized vendor_name snapshot
    vendorName ??= json['vendor_name'] as String?;

    // Handle created_at being either a String or DateTime from Supabase
    final createdAtRaw = json['created_at'];
    DateTime createdAt;
    if (createdAtRaw is String) {
      createdAt = DateTime.parse(createdAtRaw);
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else {
      createdAt = DateTime.now();
    }

    return Review(
      id: json['id'].toString(),
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: createdAt,
      userId: json['user_id'].toString(),
      serviceId: json['service_id']?.toString(),
      vendorId: json['vendor_id']?.toString(),
      userName: userName,
      serviceName: serviceName,
      vendorName: vendorName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt.toIso8601String(),
      'user_id': userId,
      'service_id': serviceId,
      'vendor_id': vendorId,
      'user_name': userName,
      'service_name': serviceName,
      'vendor_name': vendorName,
    };
  }
}

class ReviewService {
  final SupabaseClient _supabase;

  ReviewService(this._supabase);

  /// Get reviews for a specific service
  Future<List<Review>> getServiceReviews(String serviceId, {int limit = 50}) async {
    try {
      final response = await _supabase
          // Use dedicated service_reviews table so it doesn't conflict with any legacy reviews
          .from('service_reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            user_id,
            service_id,
            vendor_id,
            user_name,
            profiles(full_name),
            services!service_reviews_service_id_fkey(name),
            vendor_profiles!service_reviews_vendor_id_fkey(business_name)
          ''')
          .eq('service_id', serviceId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Review.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch reviews: $e');
    }
  }

  /// Get reviews for a specific vendor
  Future<List<Review>> getVendorReviews(String vendorId, {int limit = 50}) async {
    try {
      final response = await _supabase
          .from('service_reviews')
          .select('''
            id,
            rating,
            comment,
            created_at,
            user_id,
            service_id,
            vendor_id,
            user_name,
            profiles(full_name),
            services!service_reviews_service_id_fkey(name),
            vendor_profiles!service_reviews_vendor_id_fkey(business_name)
          ''')
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => Review.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch vendor reviews: $e');
    }
  }

  /// Get average rating and count for a service
  Future<Map<String, dynamic>> getServiceRatingStats(String serviceId) async {
    try {
      final response = await _supabase
          .from('service_reviews')
          .select('rating')
          .eq('service_id', serviceId);

      if (response.isEmpty) {
        return {'averageRating': 0.0, 'count': 0};
      }

      final ratings = (response as List)
          .map((r) => (r as Map<String, dynamic>)['rating'] as int)
          .toList();

      final averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
      return {
        'averageRating': averageRating,
        'count': ratings.length,
      };
    } catch (e) {
      return {'averageRating': 0.0, 'count': 0};
    }
  }

  /// Submit a new review
  Future<Review> submitReview({
    required int rating,
    required String comment,
    required String serviceId,
    String? vendorId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to submit a review');
      }

      // Check if user already reviewed this service
      final existingReview = await _supabase
          .from('service_reviews')
          .select('id')
          .eq('user_id', user.id)
          .eq('service_id', serviceId)
          .maybeSingle();

      if (existingReview != null) {
        throw Exception('You have already reviewed this service');
      }

      // Get vendor_id and names from service if not provided
      String? finalVendorId = vendorId;
      String? reviewServiceName;
      String? reviewVendorName;
      if (finalVendorId == null) {
        final serviceResponse = await _supabase
            .from('services')
            .select('vendor_id, name, vendor_profiles(business_name)')
            .eq('id', serviceId)
            .maybeSingle();
        finalVendorId = serviceResponse?['vendor_id']?.toString();
        // Capture service and vendor names for denormalized storage
        reviewServiceName = serviceResponse?['name'] as String?;
        final vp = serviceResponse?['vendor_profiles'];
        if (vp is Map) {
          reviewVendorName = vp['business_name'] as String?;
        } else if (vp is List && vp.isNotEmpty) {
          reviewVendorName = vp[0]['business_name'] as String?;
        }
      }

      // Fetch the user's full name from profile tables (first_name + last_name / full_name)
      String? userName;
      for (final table in ['profiles', 'user_profiles']) {
        try {
          final profileResponse = await _supabase
              .from(table)
              .select('first_name, last_name, full_name')
              .eq('user_id', user.id)
              .maybeSingle();

          if (profileResponse != null) {
            final fullName = (profileResponse['full_name'] as String?)?.trim();
            final firstName = (profileResponse['first_name'] as String?)?.trim();
            final lastName = (profileResponse['last_name'] as String?)?.trim();

            if (fullName != null && fullName.isNotEmpty) {
              userName = fullName;
            } else if ((firstName != null && firstName.isNotEmpty) ||
                       (lastName != null && lastName.isNotEmpty)) {
              userName = [firstName, lastName]
                  .where((v) => v != null && v.isNotEmpty)
                  .join(' ');
            }
          }

          if (userName != null && userName.isNotEmpty) {
            break;
          }
        } catch (_) {
          // Ignore and try next candidate table
        }
      }

      // Allow service/vendor names from lookup above or fall back to null
      final reviewData = {
        'user_id': user.id,
        'service_id': serviceId,
        'vendor_id': finalVendorId,
        'rating': rating,
        'comment': comment,
        // Snapshot of user name at time of review; used when profiles data is missing
        'user_name': userName ??
            // Try auth metadata full_name / name
            (user.userMetadata?['full_name'] as String?) ??
            (user.userMetadata?['name'] as String?) ??
            // Try auth metadata first_name + last_name
            (() {
              final first = (user.userMetadata?['first_name'] as String?)?.trim();
              final last = (user.userMetadata?['last_name'] as String?)?.trim();
              final parts = [first, last].where((v) => v != null && v.isNotEmpty).join(' ');
              return parts.isNotEmpty ? parts : null;
            }()) ??
            // Fallback to email or Anonymous
            user.email ??
            'Anonymous',
        'service_name': reviewServiceName,
        'vendor_name': reviewVendorName,
      };

      final response = await _supabase
          .from('service_reviews')
          .insert(reviewData)
          .select('''
            id,
            rating,
            comment,
            created_at,
            user_id,
            service_id,
            vendor_id,
            user_name,
            profiles(full_name),
            services!service_reviews_service_id_fkey(name),
            vendor_profiles!service_reviews_vendor_id_fkey(business_name)
          ''')
          .single();

      return Review.fromJson(response);
    } catch (e) {
      throw Exception('Failed to submit review: $e');
    }
  }

  /// Delete the current user's own review by id
  Future<void> deleteReview(String reviewId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated to delete a review');
      }

      final result = await _supabase
          .from('service_reviews')
          .delete()
          .eq('id', reviewId)
          .eq('user_id', user.id);

      // Supabase returns an empty list on successful delete; no-op here.
      // If RLS prevents deletion, Supabase will throw which we re-wrap below.
      result;
    } catch (e) {
      throw Exception('Failed to delete review: $e');
    }
  }

  /// Subscribe to real-time updates for service reviews
  RealtimeChannel subscribeToServiceReviews(
    String serviceId,
    void Function(List<Review> reviews) onReviewsUpdated,
  ) {
    final channel = _supabase
        .channel('service_reviews_stream_$serviceId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'service_reviews',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'service_id',
            value: serviceId,
          ),
          callback: (payload) async {
            // Reload reviews when changes occur
            final reviews = await getServiceReviews(serviceId);
            onReviewsUpdated(reviews);
          },
        )
        .subscribe();

    return channel;
  }
}
