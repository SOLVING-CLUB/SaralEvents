import 'package:supabase_flutter/supabase_flutter.dart';

class FAQ {
  final String id;
  final String question;
  final String answer;
  final String category;
  final int displayOrder;
  final bool isActive;
  final int viewCount;
  final int helpfulCount;
  final int notHelpfulCount;

  FAQ({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.displayOrder,
    required this.isActive,
    required this.viewCount,
    required this.helpfulCount,
    required this.notHelpfulCount,
  });

  factory FAQ.fromJson(Map<String, dynamic> json) {
    return FAQ(
      id: json['id'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      category: json['category'] as String? ?? 'General',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      viewCount: (json['view_count'] as num?)?.toInt() ?? 0,
      helpfulCount: (json['helpful_count'] as num?)?.toInt() ?? 0,
      notHelpfulCount: (json['not_helpful_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class FAQService {
  final SupabaseClient _supabase;

  FAQService(this._supabase);

  /// Fetch all active FAQs for user app
  Future<List<FAQ>> getFAQs() async {
    try {
      final response = await _supabase
          .from('faqs')
          .select()
          .eq('app_type', 'user_app')
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .order('created_at', ascending: false);

      if (response.isEmpty) {
        return [];
      }

      return (response as List)
          .map((json) => FAQ.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch FAQs: $e');
    }
  }

  /// Increment view count when user views an FAQ
  Future<void> incrementViewCount(String faqId) async {
    try {
      await _supabase.rpc('increment_faq_view_count', params: {'faq_id': faqId});
    } catch (e) {
      // Silently fail - view count is not critical
      print('Failed to increment FAQ view count: $e');
    }
  }

  /// Mark FAQ as helpful
  Future<void> markAsHelpful(String faqId) async {
    try {
      await _supabase.rpc('increment_faq_helpful_count', params: {'faq_id': faqId});
    } catch (e) {
      throw Exception('Failed to mark FAQ as helpful: $e');
    }
  }

  /// Mark FAQ as not helpful
  Future<void> markAsNotHelpful(String faqId) async {
    try {
      await _supabase.rpc('increment_faq_not_helpful_count', params: {'faq_id': faqId});
    } catch (e) {
      throw Exception('Failed to mark FAQ as not helpful: $e');
    }
  }
}
