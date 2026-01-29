import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/event_models.dart';
import '../core/theme/color_tokens.dart';
import '../screens/catalog_screen.dart';
import '../utils/category_mapping_helper.dart';

class EventCategoriesScreen extends StatefulWidget {
  final EventType eventType;

  const EventCategoriesScreen({
    super.key,
    required this.eventType,
  });

  @override
  State<EventCategoriesScreen> createState() => _EventCategoriesScreenState();
}

class _EventCategoriesScreenState extends State<EventCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<EventCategory> _filteredCategories = [];
  List<EventCategory> _allCategories = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _initializeCategories() {
    _allCategories = EventData.getCategoriesForEvent(widget.eventType.id);
    _filteredCategories = List.from(_allCategories);
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCategories = List.from(_allCategories);
      } else {
        _filteredCategories = _allCategories.where((category) {
          return category.name.toLowerCase().contains(query) ||
                 category.description.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filteredCategories = List.from(_allCategories);
    });
  }

  void _onCategoryTapped(BuildContext context, EventCategory category) {
    debugPrint('Navigating to catalog with category: ${category.databaseCategory} for event: ${widget.eventType.name}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CatalogScreen(
          selectedCategory: category.databaseCategory, // Use database category name
          eventType: widget.eventType.name,
          categoryDisplayName: category.name, // Pass display name for UI
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Debug category mapping (only in debug mode)
    if (kDebugMode) {
      debugPrint('Event Categories for ${widget.eventType.name}:');
      for (final category in _allCategories) {
        final isValid = CategoryMappingHelper.isValidCategory(category.databaseCategory);
        debugPrint('  ${category.name} → ${category.databaseCategory} ${isValid ? '✓' : '✗'}');
      }
    }

    return Scaffold(
      backgroundColor: ColorTokens.bgApp(context),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Search bar
            _buildSearchBar(),
            
            // Search results indicator
            if (_searchQuery.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  '${_filteredCategories.length} ${_filteredCategories.length == 1 ? 'category' : 'categories'} found for "$_searchQuery"',
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorTokens.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            
            // Categories list
            Expanded(
              child: _filteredCategories.isEmpty
                  ? _buildEmptyState()
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: ListView.builder(
                        key: ValueKey(_searchQuery), // Trigger animation on search change
                        padding: const EdgeInsets.all(20),
                        itemCount: _filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = _filteredCategories[index];
                          return AnimatedContainer(
                            duration: Duration(milliseconds: 200 + (index * 50)),
                            curve: Curves.easeOutBack,
                            child: _buildCategoryCard(context, category),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ColorTokens.bgSurface(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: ColorTokens.iconPrimary(context),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.eventType.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: ColorTokens.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Explore vendor\'s section',
                  style: TextStyle(
                    fontSize: 14,
                    color: ColorTokens.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: ColorTokens.bgInput(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorTokens.borderInput(context)),
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search categories...',
            hintStyle: TextStyle(color: ColorTokens.textTertiary(context)),
            prefixIcon: Icon(Icons.search, color: ColorTokens.iconTertiary(context)),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: _clearSearch,
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ColorTokens.bgSurface(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.clear,
                        color: ColorTokens.iconSecondary(context),
                        size: 18,
                      ),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.all(8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: ColorTokens.bgSurface(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.tune,
                      color: ColorTokens.iconSecondary(context),
                      size: 18,
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, EventCategory category) {
    return GestureDetector(
      onTap: () => _onCategoryTapped(context, category),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: ColorTokens.bgSurface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background image
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getCategoryGradientColors(category.id),
                    ),
                  ),
                  child: _buildCategoryImage(category),
                ),
              ),
              
              // Gradient overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Content
              Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
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
                    const SizedBox(height: 4),
                    Text(
                      category.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                        shadows: const [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryImage(EventCategory category) {
    // For now, we'll use a placeholder with icon
    // In production, you would load actual images
    return Center(
      child: Icon(
        _getCategoryIcon(category.name),
        size: 80,
        color: Colors.white.withValues(alpha: 0.7),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchQuery.isNotEmpty;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.event_busy,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching 
                ? 'No categories found'
                : 'No categories available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? 'Try searching with different keywords'
                : 'Categories for ${widget.eventType.name} will be added soon',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          if (isSearching) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: Colors.grey.shade700,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Color> _getCategoryGradientColors(String categoryId) {
    if (categoryId.contains('venues')) {
      return [
        const Color(0xFF8E24AA).withValues(alpha: 0.8),
        const Color(0xFF5E35B1).withValues(alpha: 0.9),
      ];
    } else if (categoryId.contains('decor')) {
      return [
        const Color(0xFF43A047).withValues(alpha: 0.8),
        const Color(0xFF2E7D32).withValues(alpha: 0.9),
      ];
    } else if (categoryId.contains('catering')) {
      return [
        const Color(0xFFFF8F00).withValues(alpha: 0.8),
        const Color(0xFFE65100).withValues(alpha: 0.9),
      ];
    } else if (categoryId.contains('photography')) {
      return [
        const Color(0xFF1976D2).withValues(alpha: 0.8),
        const Color(0xFF0D47A1).withValues(alpha: 0.9),
      ];
    } else if (categoryId.contains('makeup')) {
      return [
        const Color(0xFFE91E63).withValues(alpha: 0.8),
        const Color(0xFFC2185B).withValues(alpha: 0.9),
      ];
    } else if (categoryId.contains('music')) {
      return [
        const Color(0xFFFF5722).withValues(alpha: 0.8),
        const Color(0xFFD84315).withValues(alpha: 0.9),
      ];
    } else {
      return [
        const Color(0xFF607D8B).withValues(alpha: 0.8),
        const Color(0xFF455A64).withValues(alpha: 0.9),
      ];
    }
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('venue')) {
      return Icons.location_city;
    } else if (name.contains('decor')) {
      return Icons.local_florist;
    } else if (name.contains('catering')) {
      return Icons.restaurant;
    } else if (name.contains('photography')) {
      return Icons.camera_alt;
    } else if (name.contains('makeup')) {
      return Icons.face;
    } else if (name.contains('music') || name.contains('dance')) {
      return Icons.music_note;
    } else if (name.contains('entertainment')) {
      return Icons.celebration;
    } else if (name.contains('av') || name.contains('equipment')) {
      return Icons.settings_input_component;
    } else {
      return Icons.miscellaneous_services;
    }
  }
}