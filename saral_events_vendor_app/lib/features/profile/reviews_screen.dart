import 'package:flutter/material.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock reviews
    final List<Map<String, dynamic>> reviews = [
      {
        'user': 'Rahul Sharma',
        'rating': 5,
        'comment': 'Perfect service! The team was very professional and handled everything smoothly.',
        'date': '2 days ago',
        'reply': null,
      },
      {
        'user': 'Priya Patel',
        'rating': 4,
        'comment': 'Really good experience. A bit of delay in communication but the results were great.',
        'date': '1 week ago',
        'reply': 'Thank you Priya! We are working on improving our response times.',
      },
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ratings & Reviews')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final review = reviews[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(review['user'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(review['date'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      Icons.star,
                      size: 16,
                      color: i < (review['rating'] as int) ? Colors.amber : Colors.grey.shade300,
                    )),
                  ),
                  const SizedBox(height: 12),
                  Text(review['comment']),
                  if (review['reply'] != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Your Reply:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text(review['reply']!, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        // Future: Reply to review
                      },
                      child: const Text('Reply to Review'),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
