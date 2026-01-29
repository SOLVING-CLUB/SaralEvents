import 'package:flutter/material.dart';
import '../core/theme/color_tokens.dart';
import 'catalog_screen.dart';

class AllCategoriesScreen extends StatelessWidget {
  const AllCategoriesScreen({super.key});

  // Static categories with asset mapping
  final List<Map<String, String>> _categories = const [
    {
      'name': 'Photography',
      'asset': 'assets/default_images/category_photoghraphy.jpg',
    },
    {
      'name': 'Decoration',
      'asset': 'assets/default_images/category_decoration.jpg',
    },
    {
      'name': 'Catering',
      'asset': 'assets/default_images/category_catering.jpg',
    },
    {
      'name': 'Venue',
      'asset': 'assets/default_images/category_venue.jpg',
    },
    {
      'name': 'Farmhouse',
      'asset': 'assets/default_images/category_farmhouse.jpeg',
    },
    {
      'name': 'Music/Dj',
      'asset': 'assets/default_images/category_musicDj.jpg',
    },
    {
      'name': 'Essentials',
      'asset': 'assets/default_images/category_essentials.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'All Categories',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: ColorTokens.bgApp(context),
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildCategoryCard(context, category);
        },
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, Map<String, String> category) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to catalog with selected category
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => CatalogScreen(
                selectedCategory: category['name'],
                categoryDisplayName: category['name'],
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Background image
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  category['asset']!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 50,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
              
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              
              // Category name
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Text(
                  category['name']!,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ),
              
              // Arrow icon
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
