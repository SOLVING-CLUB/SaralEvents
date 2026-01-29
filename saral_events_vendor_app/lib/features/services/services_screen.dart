import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'service_models.dart';
import '../../core/ui/widgets.dart';
import '../../core/ui/app_icons.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'service_service.dart';
import 'availability_service.dart';
import '../../widgets/availability_calendar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/state/session.dart';


class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> with TickerProviderStateMixin {
  late final CategoryNode _root;
  final List<CategoryNode> _stack = <CategoryNode>[];
  final ServiceService _serviceService = ServiceService();
  bool _isLoading = false;
  String _query = '';
  final TextEditingController _searchCtrl = TextEditingController();
  late final TabController _tabController;
  // Multi-select state
  bool _selectionMode = false;
  final Set<String> _selectedServiceIds = <String>{};
  final Set<String> _selectedCategoryIds = <String>{};

  CategoryNode get _current => _stack.isEmpty ? _root : _stack.last;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _root = CategoryNode(id: 'root', name: 'All', subcategories: []);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _serviceService.getCategories();
      final rootServices = await _serviceService.getRootServices();
      setState(() {
        _root.subcategories = categories;
        _root.services
          ..clear()
          ..addAll(rootServices);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadServicesFor(CategoryNode node) async {
    try {
      final items = await _serviceService.getServices(node.id);
      if (!mounted) return;
      setState(() {
        node.services
          ..clear()
          ..addAll(items);
      });
    } catch (e) {
      print('Error loading services for category ${node.id}: $e');
    }
  }

  // Recursively count all subcategories (including nested ones)
  int _countAllSubcategories(CategoryNode node) {
    int count = node.subcategories.length;
    for (final subcat in node.subcategories) {
      count += _countAllSubcategories(subcat);
    }
    return count;
  }

  // Recursively count all services (including those in subcategories)
  int _countAllServices(CategoryNode node) {
    int count = node.services.length;
    for (final subcat in node.subcategories) {
      count += _countAllServices(subcat);
    }
    return count;
  }

  // Fetch accurate counts from database (for when in-memory structure might be incomplete)
  Future<Map<String, int>> _getCategoryCounts(String categoryId) async {
    try {
      final subcategoryCount = await _serviceService.countAllSubcategories(categoryId);
      final serviceCount = await _serviceService.countAllServices(categoryId);
      return {
        'subcategories': subcategoryCount,
        'services': serviceCount,
      };
    } catch (e) {
      print('Error fetching category counts: $e');
      return {'subcategories': 0, 'services': 0};
    }
  }

  // Get all services with category names for tabs
  Future<List<Map<String, dynamic>>> _getAllServicesWithCategories() async {
    try {
      final allServices = await _serviceService.getAllServicesWithStatus();
      final categories = await _serviceService.getCategories();
      
      // Create a map for quick category lookup
      final categoryMap = <String, String>{};
      for (final cat in categories) {
        categoryMap[cat.id] = cat.name;
      }
      
      return allServices.map((service) {
        return {
          'service': service,
          'categoryName': service.categoryId != null ? categoryMap[service.categoryId] ?? 'Unknown' : 'Root',
        };
      }).toList();
    } catch (e) {
      print('Error getting services with categories: $e');
      return [];
    }
  }

  // Refresh data for all tabs
  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final categories = await _serviceService.getCategories();
      final rootServices = await _serviceService.getRootServices();
      setState(() {
        _root.subcategories = categories;
        _root.services
          ..clear()
          ..addAll(rootServices);
        _isLoading = false;
      });
    } catch (e) {
      print('Error refreshing data: $e');
      setState(() => _isLoading = false);
    }
  }



  // Force refresh services data from database
  Future<void> _forceRefreshServicesData() async {
    try {
      // Force a rebuild by updating state
      setState(() {});
      // Also refresh the main data
      await _refreshData();
    } catch (e) {
      print('Error force refreshing services data: $e');
    }
  }

  // Update cached service data across all tabs when a service status changes
  void _updateCachedServiceStatus(String serviceId, bool newStatus) {
    setState(() {
      // Update in root services
      for (final service in _root.services) {
        if (service.id == serviceId) {
          service.enabled = newStatus;
          break;
        }
      }
      
      // Update in current category services
      for (final service in _current.services) {
        if (service.id == serviceId) {
          service.enabled = newStatus;
          break;
        }
      }
      
      // Update in all category services recursively
      void updateCategoryServices(List<CategoryNode> categories) {
        for (final category in categories) {
          for (final service in category.services) {
            if (service.id == serviceId) {
              service.enabled = newStatus;
              break;
            }
          }
          updateCategoryServices(category.subcategories);
        }
      }
      updateCategoryServices(_root.subcategories);
    });
  }

  // Update cached service visibility across all tabs when visibility changes
  void _updateCachedServiceVisibility(String serviceId, bool newVisibility) {
    setState(() {
      // Update in root services
      for (final service in _root.services) {
        if (service.id == serviceId) {
          service.isVisibleToUsers = newVisibility;
          break;
        }
      }
      
      // Update in current category services
      for (final service in _current.services) {
        if (service.id == serviceId) {
          service.isVisibleToUsers = newVisibility;
          break;
        }
      }
      
      // Update in all category services recursively
      void updateCategoryServices(List<CategoryNode> categories) {
        for (final category in categories) {
          for (final service in category.services) {
            if (service.id == serviceId) {
              service.isVisibleToUsers = newVisibility;
              break;
            }
          }
          updateCategoryServices(category.subcategories);
        }
      }
      updateCategoryServices(_root.subcategories);
    });
  }

  // Selection helpers
  void _startSelection(ServiceItem service) {
    setState(() {
      _selectionMode = true;
      _selectedServiceIds.add(service.id);
    });
  }

  void _toggleSelection(ServiceItem service) {
    setState(() {
      if (_selectedServiceIds.contains(service.id)) {
        _selectedServiceIds.remove(service.id);
      } else {
        _selectedServiceIds.add(service.id);
      }
      if (_selectedServiceIds.isEmpty && _selectedCategoryIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedServiceIds.clear();
      _selectedCategoryIds.clear();
    });
  }

  void _startSelectionCategory(CategoryNode category) {
    setState(() {
      _selectionMode = true;
      _selectedCategoryIds.add(category.id);
    });
  }

  void _toggleSelectionCategory(CategoryNode category) {
    setState(() {
      if (_selectedCategoryIds.contains(category.id)) {
        _selectedCategoryIds.remove(category.id);
      } else {
        _selectedCategoryIds.add(category.id);
      }
      if (_selectedServiceIds.isEmpty && _selectedCategoryIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedServiceIds.isEmpty && _selectedCategoryIds.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Services'),
        content: Text('Delete ${_selectedServiceIds.length} service(s) and ${_selectedCategoryIds.length} categor${_selectedCategoryIds.length == 1 ? 'y' : 'ies'}?', maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    int deletedServices = 0;
    int deletedCategories = 0;
    for (final id in List<String>.from(_selectedServiceIds)) {
      final success = await _serviceService.deleteService(id);
      if (success) {
        deletedServices++;
        setState(() {
          _root.services.removeWhere((s) => s.id == id);
          _current.services.removeWhere((s) => s.id == id);
          void removeFromCategoryServices(List<CategoryNode> categories) {
            for (final category in categories) {
              category.services.removeWhere((s) => s.id == id);
              removeFromCategoryServices(category.subcategories);
            }
          }
          removeFromCategoryServices(_root.subcategories);
        });
        _selectedServiceIds.remove(id);
      }
    }
    for (final id in List<String>.from(_selectedCategoryIds)) {
      final success = await _serviceService.forceDeleteCategory(id);
      if (success) {
        deletedCategories++;
        setState(() {
          // Remove from current view's subcategories recursively
          void removeCategoryById(List<CategoryNode> categories) {
            categories.removeWhere((c) => c.id == id);
            for (final c in categories) {
              removeCategoryById(c.subcategories);
            }
          }
          removeCategoryById(_root.subcategories);
        });
        _selectedCategoryIds.remove(id);
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted $deletedServices service${deletedServices == 1 ? '' : 's'} and $deletedCategories categor${deletedCategories == 1 ? 'y' : 'ies'}')),
      );
    }
    _clearSelection();
  }

  Future<void> _bulkMoveSelected() async {
    if (_selectedServiceIds.isEmpty && _selectedCategoryIds.isEmpty) return;
    final categories = await _serviceService.getCategories();
    // Exclude any categories that are currently selected to move
    final filteredCategories = categories
        .where((cat) => !_selectedCategoryIds.contains(cat.id))
        .toList();
    String targetId = 'root';
    final chosenId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Services'),
        content: DropdownButtonFormField<String>(
          value: targetId,
          items: [
            const DropdownMenuItem(value: 'root', child: Text('Root (No Category)')),
            ...filteredCategories.map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
          ],
          onChanged: (v) => targetId = v ?? targetId,
          decoration: const InputDecoration(labelText: 'Select Category', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, targetId), child: const Text('Move')),
        ],
      ),
    );
    if (chosenId == null) return;

    final newCategoryId = chosenId == 'root' ? null : chosenId;
    int movedServices = 0;
    int movedCategories = 0;
    for (final id in List<String>.from(_selectedServiceIds)) {
      final success = await _serviceService.updateService(id, {'category_id': newCategoryId});
      if (success) movedServices++;
    }
    for (final catId in List<String>.from(_selectedCategoryIds)) {
      if (chosenId == catId) {
        continue; // avoid moving a category into itself
      }
      final success = await _serviceService.updateCategory(catId, {'parent_id': newCategoryId});
      if (success) movedCategories++;
    }
    await _refreshData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved $movedServices service${movedServices == 1 ? '' : 's'} and $movedCategories categor${movedCategories == 1 ? 'y' : 'ies'}')),
      );
    }
    _clearSelection();
  }

  // Tab 1: All (file-explorer view)
  Widget _buildAllTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final visibleCats = _current.subcategories
        .where((c) => _query.isEmpty || c.name.toLowerCase().contains(_query))
        .toList();
    List<ServiceItem> visibleServices = _current.services
        .where((s) => _query.isEmpty || s.name.toLowerCase().contains(_query))
        .toList();

    if (visibleCats.isEmpty && visibleServices.isEmpty) {
      return const Center(child: Text('No results'));
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.separated(
        itemCount: visibleCats.length + visibleServices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index < visibleCats.length) {
            final cat = visibleCats[index];
            // Use FutureBuilder to fetch accurate counts from database
            return FutureBuilder<Map<String, int>>(
              future: _getCategoryCounts(cat.id),
              builder: (context, snapshot) {
                // Fallback to in-memory counts while loading or on error
                final totalSubcategories = snapshot.hasData 
                    ? snapshot.data!['subcategories'] ?? _countAllSubcategories(cat)
                    : _countAllSubcategories(cat);
                final totalServices = snapshot.hasData 
                    ? snapshot.data!['services'] ?? _countAllServices(cat)
                    : _countAllServices(cat);
                
                return _FolderLikeCard(
                  title: cat.name,
                  subtitle: '$totalSubcategories sub • $totalServices items',
                  onTap: () => _selectCategoryChip(cat),
                  onDelete: () => _deleteCategory(cat),
                  selectionMode: _selectionMode,
                  isSelected: _selectedCategoryIds.contains(cat.id),
                  onSelectedChanged: (_) => _toggleSelectionCategory(cat),
                  onLongPressSelect: () => _startSelectionCategory(cat),
                );
              },
            );
          }
          final item = visibleServices[index - visibleCats.length];
          return _ServiceCard(
            item: item,
            onOpen: () => _openService(item),
            onEdit: () => _openEditService(item),
            onDelete: () => _deleteService(item),
            onToggleEnabled: (v) async {
              await _serviceService.toggleServiceStatus(item.id, v);
              _updateCachedServiceStatus(item.id, v);
            },
            onOpenAvailability: () {
              // Open service details with calendar in view mode; Edit available inside
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServiceDetailsPage(item: item),
                ),
              );
            },
            onMove: () => _showMoveServiceDialog(item),
            selectionMode: _selectionMode,
            isSelected: _selectedServiceIds.contains(item.id),
            onSelectedChanged: (_) => _toggleSelection(item),
            onLongPressSelect: () => _startSelection(item),
          );
        },
      ),
    );
  }

  // Tab 2: Available Services
  Widget _buildAvailableServicesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllServicesWithCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final servicesWithCategories = snapshot.data ?? [];
        final availableServices = servicesWithCategories
            .where((item) {
              final service = item['service'] as ServiceItem;
              final query = _query.toLowerCase();
              return service.enabled && 
                     (query.isEmpty || service.name.toLowerCase().contains(query));
            })
            .toList();
        
        if (availableServices.isEmpty) {
          return const Center(child: Text('No available services'));
        }
        
        return RefreshIndicator(
          onRefresh: _forceRefreshServicesData,
          child: ListView.separated(
            itemCount: availableServices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = availableServices[index];
              final service = item['service'] as ServiceItem;
              final categoryName = item['categoryName'] as String;
              
              return _ServiceCardWithCategory(
                item: service,
                categoryName: categoryName,
                onOpen: () => _openService(service),
                onEdit: () => _openEditService(service),
                onDelete: () => _deleteService(service),
                onToggleEnabled: (v) async {
                  await _serviceService.toggleServiceStatus(service.id, v);
                  _updateCachedServiceStatus(service.id, v);
                },
                onToggleVisibility: (v) async {
                  await _serviceService.toggleServiceVisibility(service.id, v);
                  _updateCachedServiceVisibility(service.id, v);
                },
              );
            },
          ),
        );
      },
    );
  }

  // Tab 3: Unavailable Services
  Widget _buildUnavailableServicesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getAllServicesWithCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        
        final servicesWithCategories = snapshot.data ?? [];
        final unavailableServices = servicesWithCategories
            .where((item) {
              final service = item['service'] as ServiceItem;
              final query = _query.toLowerCase();
              return !service.enabled && 
                     (query.isEmpty || service.name.toLowerCase().contains(query));
            })
            .toList();
        
        if (unavailableServices.isEmpty) {
          return RefreshIndicator(
            onRefresh: _forceRefreshServicesData,
            child: ListView(
              children: [
                const SizedBox(height: 100),
                const Center(child: Text('No unavailable services')),
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Text(
                        'Total services: ${servicesWithCategories.length}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Query: "$_query"',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enabled services: ${servicesWithCategories.where((item) => (item['service'] as ServiceItem).enabled).length}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Disabled services: ${servicesWithCategories.where((item) => !(item['service'] as ServiceItem).enabled).length}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: _forceRefreshServicesData,
          child: ListView.separated(
            itemCount: unavailableServices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = unavailableServices[index];
              final service = item['service'] as ServiceItem;
              final categoryName = item['categoryName'] as String;
              
              return _ServiceCardWithCategory(
                item: service,
                categoryName: categoryName,
                onOpen: () => _openService(service),
                onEdit: () => _openEditService(service),
                onDelete: () => _deleteService(service),
                onToggleEnabled: (v) async {
                  await _serviceService.toggleServiceStatus(service.id, v);
                  _updateCachedServiceStatus(service.id, v);
                },
                onToggleVisibility: (v) async {
                  await _serviceService.toggleServiceVisibility(service.id, v);
                  _updateCachedServiceVisibility(service.id, v);
                },
              );
            },
          ),
        );
      },
    );
  }


  Future<void> _deleteService(ServiceItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Service'),
        content: Text('Delete service "${item.name}"?', maxLines: 3, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final success = await _serviceService.deleteService(item.id);
        if (success) {
          setState(() {
            // Remove from current services
            _current.services.removeWhere((s) => s.id == item.id);
            // Remove from root services
            _root.services.removeWhere((s) => s.id == item.id);
            // Remove from all category services recursively
            void removeFromCategoryServices(List<CategoryNode> categories) {
              for (final category in categories) {
                category.services.removeWhere((s) => s.id == item.id);
                removeFromCategoryServices(category.subcategories);
              }
            }
            removeFromCategoryServices(_root.subcategories);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service deleted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete service'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteCategory(CategoryNode category) async {
    // Check if category has content
    final hasContent = category.subcategories.isNotEmpty || category.services.isNotEmpty;
    
    if (hasContent) {
      // Show options dialog for categories with content
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
            'Category "${category.name}" contains:\n'
            '• ${category.subcategories.length} subcategories\n'
            '• ${category.services.length} services\n\n'
            'How would you like to proceed?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'cancel'),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'move'),
              child: const Text('Move Services to Root'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'force'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      );

      if (choice == 'cancel') return;

      if (choice == 'move') {
        // Move services to root level
        try {
          final success = await _serviceService.moveServicesToRoot(category.id);
          if (success) {
            // Now delete the empty category
            final deleteSuccess = await _serviceService.deleteCategory(category.id);
            if (deleteSuccess) {
              setState(() {
                _current.subcategories.removeWhere((c) => c.id == category.id);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Category deleted, services moved to root')),
              );
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (choice == 'force') {
        // Force delete everything
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Confirm Deletion'),
            content: Text(
              'This will PERMANENTLY DELETE:\n'
              '• Category "${category.name}"\n'
              '• All ${category.subcategories.length} subcategories\n'
              '• All ${category.services.length} services\n\n'
              'This action cannot be undone!'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Delete Everything'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;

        try {
          final success = await _serviceService.forceDeleteCategory(category.id);
          if (success) {
            setState(() {
              _current.subcategories.removeWhere((c) => c.id == category.id);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category and all contents deleted')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete category'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    } else {
      // Empty category - safe to delete
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Category'),
          content: Text('Delete empty category "${category.name}"?', maxLines: 3, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          final success = await _serviceService.deleteCategory(category.id);
          if (success) {
            setState(() {
              _current.subcategories.removeWhere((c) => c.id == category.id);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Category deleted successfully')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to delete category'),
                backgroundColor: Colors.red,
              ),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // Show dialog to move a service to a different category
  Future<void> _showMoveServiceDialog(ServiceItem service) async {
    final categories = await _serviceService.getCategories();
    String selectedCategoryId = service.categoryId ?? 'root';
    // Ensure we do not list the currently selected categories (from multi-select) as destinations
    final filteredCategories = categories
        .where((cat) => !_selectedCategoryIds.contains(cat.id))
        .toList();

    final chosenId = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Move "${service.name}" to:', maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: selectedCategoryId,
              items: [
                const DropdownMenuItem(
                  value: 'root',
                  child: Text('Root (No Category)'),
                ),
                ...filteredCategories.map((cat) => DropdownMenuItem(
                  value: cat.id,
                  child: Text(cat.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
              ],
              onChanged: (value) => selectedCategoryId = value ?? selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Select Category',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selectedCategoryId),
            child: const Text('Move'),
          ),
        ],
      ),
    );

    if (chosenId != null) {
      await _moveService(service, chosenId);
    }
  }

  // Move service to a different category
  Future<void> _moveService(ServiceItem service, String targetCategoryId) async {
    try {
      final String? newCategoryId = targetCategoryId == 'root' ? null : targetCategoryId;
      final success = await _serviceService.updateService(service.id, {
        'category_id': newCategoryId,
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Service moved'),
          ),
        );
        
        // Refresh the data to ensure consistency
        await _refreshData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to move service'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error moving service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Category name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      try {
        final newCategory = await _serviceService.createCategory(name, _current.id == 'root' ? null : _current.id);
        if (newCategory != null) {
          setState(() {
            _current.subcategories.add(newCategory);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category added successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to add category'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addService() async {
    final ServiceItem? created = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _AddServicePage(
          categoryId: _current.id == 'root' ? null : _current.id,
        ),
        fullscreenDialog: true,
      ),
    );
    if (created != null) {
      setState(() {
        // Add to current services
        _current.services.add(created);
        // Add to root services if it's a root-level service
        if (created.categoryId == null) {
          _root.services.add(created);
        }
      });
    }
  }

  void _openService(ServiceItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServiceDetailsPage(item: item)),
    );
  }

  void _openEditService(ServiceItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => _EditServicePage(item: item)),
    ).then((changed) async {
      if (changed == true) {
        await _forceRefreshServicesData();
      }
    });
  }

  

  // Removed chip helpers

  void _selectCategoryChip(CategoryNode? node) {
    // node == null means select 'All'
    if (node == null) {
      setState(() => _stack.clear());
      return;
    }
    if (_stack.isEmpty) {
      setState(() => _stack.add(node));
      _loadServicesFor(node);
      return;
    }
    // Replace current with selected sibling
    setState(() {
      _stack.removeLast();
      _stack.add(node);
    });
    _loadServicesFor(node);
  }

  // Removed chip UI to keep file-explorer flow

  @override
  Widget build(BuildContext context) {
    final canPop = _stack.isNotEmpty;
    return WillPopScope(
      onWillPop: () async {
        if (_stack.isNotEmpty) {
          setState(() => _stack.removeLast());
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _selectionMode
                ? '${_selectedServiceIds.length + _selectedCategoryIds.length} selected'
                : (canPop ? _current.name : 'Catalog'),
            overflow: TextOverflow.ellipsis,
          ),
          leading: canPop
              ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _stack.removeLast()))
              : null,
          actions: _selectionMode
              ? [
                  IconButton(
                    tooltip: 'Move',
                    icon: const Icon(Icons.drive_file_move),
                    onPressed: _bulkMoveSelected,
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: _bulkDeleteSelected,
                  ),
                  IconButton(
                    tooltip: 'Cancel',
                    icon: const Icon(Icons.close),
                    onPressed: _clearSelection,
                  ),
                ]
              : [

                ],
          bottom: canPop ? null : TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Available'),
              Tab(text: 'Unavailable'),
            ],
            onTap: (index) {
              setState(() {});
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SearchBarMinis(
                hint: 'Search your catalog',
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              ),
              const SizedBox(height: 12),
              // Category chip row removed to restore file-explorer style
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: All (current file-explorer view)
                    _buildAllTab(),
                    // Tab 2: Available Services
                    _buildAvailableServicesTab(),
                    // Tab 3: Unavailable Services
                    _buildUnavailableServicesTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _FabMenu(
          onAddCategory: _addCategory,
          onAddService: _addService,
        ),
      ),
    );
  }
}

// Old category tile retained for reference, not used after chip redesign

class _TrashIcon extends StatelessWidget {
  final Color? color;
  const _TrashIcon({this.color});

  @override
  Widget build(BuildContext context) {
    // Inline to avoid importing icons into widgets.dart consumers
    return SvgPicture.string(
      AppIcons.trashSvg,
      colorFilter: ColorFilter.mode(color ?? Colors.black87, BlendMode.srcIn),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final ServiceItem item;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback? onOpenAvailability;
  final VoidCallback? onMove;
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onLongPressSelect;
  const _ServiceCard({required this.item, required this.onOpen, this.onEdit, required this.onDelete, required this.onToggleEnabled, this.onOpenAvailability, this.onMove, this.selectionMode = false, this.isSelected = false, this.onSelectedChanged, this.onLongPressSelect});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black26, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.selectionMode) ...[
                  Checkbox(
                    value: widget.isSelected,
                    onChanged: widget.onSelectedChanged,
                  ),
                  const SizedBox(width: 4),
                ],
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image, color: Colors.black45),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('₹${widget.item.price}', style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: widget.item.enabled,
                  onChanged: (v) async {
                    widget.onToggleEnabled(v);
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            if (widget.item.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.item.tags
                    .map((t) => Chip(label: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                    .toList(),
              ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                if (widget.selectionMode) {
                  widget.onSelectedChanged?.call(!widget.isSelected);
                } else {
                  setState(() => _expanded = !_expanded);
                }
              },
              onLongPress: widget.onLongPressSelect,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.description,
                    maxLines: _expanded ? null : 2,
                    overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(_expanded ? 'Show Less' : 'Show More', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (widget.item.media.isNotEmpty)
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.item.media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final m = widget.item.media[i];
                    return GestureDetector(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaGalleryPage(items: widget.item.media))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 96,
                          height: 72,
                          color: Colors.grey[200],
                          child: m.type == MediaType.image
                              ? (m.url.startsWith('http') || kIsWeb
                                  ? Image.network(m.url, fit: BoxFit.cover)
                                  : Image.file(File(m.url), fit: BoxFit.cover))
                              : const Icon(Icons.play_circle_fill, size: 32, color: Colors.black54),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: widget.onDelete,
                      icon: const _TrashIcon(color: Colors.redAccent),
                    ),
                    if (widget.onMove != null) ...[
                      IconButton(
                        tooltip: 'Move Service',
                        onPressed: widget.onMove,
                        icon: const Icon(Icons.drag_handle, color: Colors.blue),
                      ),
                    ],
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: widget.onEdit ?? widget.onOpen, child: const Text('Edit')),
                        if (widget.onOpenAvailability != null)
                          TextButton(onPressed: widget.onOpenAvailability, child: const Text('Availability')),
                        TextButton(
                          onPressed: () async {
                            final link = 'https://example.com/service/${widget.item.id}';
                            await Clipboard.setData(ClipboardData(text: link));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
                            }
                          },
                          child: const Text('Share'),
                        ),
                        FilledButton.tonal(onPressed: widget.onOpen, child: const Text('Open')),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ServiceCardWithCategory extends StatelessWidget {
  final ServiceItem item;
  final String categoryName;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<bool>? onToggleVisibility;
  
  const _ServiceCardWithCategory({
    required this.item,
    required this.categoryName,
    required this.onOpen,
    this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
    this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black12,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black26, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.image, color: Colors.black45),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text('₹${item.price}', style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: item.enabled,
                      onChanged: onToggleEnabled,
                    ),
                    if (onToggleVisibility != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isVisibleToUsers ? Icons.visibility : Icons.visibility_off,
                            size: 16,
                            color: item.isVisibleToUsers ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Transform.scale(
                            scale: 0.8,
                            child: Switch(
                              value: item.isVisibleToUsers,
                              onChanged: onToggleVisibility,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                )
              ],
            ),
            const SizedBox(height: 8),
            if (item.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags
                    .map((t) => Chip(label: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                    .toList(),
              ),
            const SizedBox(height: 8),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      icon: const _TrashIcon(color: Colors.redAccent),
                    ),
                  ],
                ),
                Flexible(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(onPressed: onEdit ?? onOpen, child: const Text('Edit')),
                        FilledButton.tonal(onPressed: onOpen, child: const Text('Open')),
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _FabMenu extends StatefulWidget {
  final VoidCallback onAddCategory;
  final VoidCallback onAddService;
  const _FabMenu({required this.onAddCategory, required this.onAddService});

  @override
  State<_FabMenu> createState() => _FabMenuState();
}

class _FabMenuState extends State<_FabMenu> with SingleTickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final Color primary = Theme.of(context).colorScheme.primary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_open) ...[
          FloatingActionButton.extended(
            heroTag: 'fab_cat',
            onPressed: () {
              setState(() => _open = false);
              widget.onAddCategory();
            },
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Add Category'),
            foregroundColor: Colors.white,
            backgroundColor: primary,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'fab_svc',
            onPressed: () {
              setState(() => _open = false);
              widget.onAddService();
            },
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Add Service'),
            foregroundColor: Colors.white,
            backgroundColor: primary,
          ),
          const SizedBox(height: 8),
        ],
        FloatingActionButton(
          heroTag: 'fab_main',
          onPressed: () => setState(() => _open = !_open),
          child: Icon(_open ? Icons.close : Icons.add),
        )
      ],
    );
  }
}

class ServiceDetailsPage extends StatefulWidget {
  final ServiceItem item;
  const ServiceDetailsPage({super.key, required this.item});

  @override
  State<ServiceDetailsPage> createState() => _ServiceDetailsPageState();
}

class _ServiceDetailsPageState extends State<ServiceDetailsPage> {
  Key _calendarKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.item.media.isNotEmpty)
              SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: widget.item.media.length,
                  controller: PageController(viewportFraction: 0.9),
                  itemBuilder: (context, i) {
                    final m = widget.item.media[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          color: Colors.grey[200],
                          child: m.type == MediaType.image
                              ? (m.url.startsWith('http') || kIsWeb
                                  ? Image.network(m.url, fit: BoxFit.cover)
                                  : Image.file(File(m.url), fit: BoxFit.cover))
                              : const Center(child: Icon(Icons.play_circle_fill, size: 64, color: Colors.black54)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Text('₹${widget.item.price}', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Status: ${widget.item.enabled ? 'Enabled' : 'Disabled'}', style: textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (widget.item.tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.item.tags.map((t) => Chip(label: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
              ),
            const SizedBox(height: 12),
            Text(
              widget.item.description,
              maxLines: 10,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            // Availability section for existing service (view mode with Edit)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Availability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      TextButton.icon(
                        onPressed: () async {
                          final changed = await Navigator.of(context).push<bool>(
                            MaterialPageRoute(builder: (_) => ServiceAvailabilityPage(item: widget.item)),
                          );
                          if (changed == true && mounted) {
                            setState(() => _calendarKey = UniqueKey());
                          }
                        },
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AvailabilityCalendar(
                    key: _calendarKey,
                    serviceId: widget.item.id,
                    availabilityService: AvailabilityService(),
                    isViewMode: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ServiceAvailabilityPage extends StatelessWidget {
  final ServiceItem item;
  const ServiceAvailabilityPage({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final controller = AvailabilityCalendarController();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Availability'),
        actions: [
          TextButton(
            onPressed: () async {
              final overrides = controller.getOverrides();
              final service = AvailabilityService();
              for (final o in overrides) {
                await service.upsertOverride(item.id, o);
              }
              if (context.mounted) Navigator.maybePop(context, true);
            },
            child: const Text('Save'),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvailabilityCalendar(
              serviceId: item.id,
              availabilityService: AvailabilityService(),
              controller: controller,
              persistImmediately: false, // buffer edits; Save button will persist
            ),
          ],
        ),
      ),
    );
  }
}

class MediaGalleryPage extends StatelessWidget {
  final List<MediaItem> items;
  const MediaGalleryPage({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Media')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final m = items[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              color: Colors.grey[200],
              child: m.type == MediaType.image
                  ? (m.url.startsWith('http') || kIsWeb
                      ? Image.network(m.url, fit: BoxFit.cover)
                      : Image.file(File(m.url), fit: BoxFit.cover))
                  : const Center(child: Icon(Icons.play_circle_fill, size: 36, color: Colors.black54)),
            ),
          );
        },
      ),
    );
  }
}

class _EditServicePage extends StatefulWidget {
  final ServiceItem item;
  const _EditServicePage({required this.item});

  @override
  State<_EditServicePage> createState() => _EditServicePageState();
}

class _EditServicePageState extends State<_EditServicePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _priceCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _tagCtrl;
  late List<String> _tags;
  late bool _enabled;
  late bool _isVisibleToUsers;
  final ServiceService _service = ServiceService();
  final List<MediaItem> _media = <MediaItem>[];

  @override
  void initState() {
    super.initState();
    _priceCtrl = TextEditingController(text: widget.item.price.toStringAsFixed(0));
    _descCtrl = TextEditingController(text: widget.item.description);
    _tagCtrl = TextEditingController();
    _tags = List<String>.from(widget.item.tags);
    _enabled = widget.item.enabled;
    _isVisibleToUsers = widget.item.isVisibleToUsers;
    _media.addAll(widget.item.media);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _addTagsFromInput() {
    final raw = _tagCtrl.text.trim();
    if (raw.isEmpty) return;
    for (final part in raw.split(',')) {
      final t = part.trim();
      if (t.isNotEmpty && !_tags.contains(t)) _tags.add(t);
    }
    _tagCtrl.clear();
    setState(() {});
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      setState(() {
        for (final f in files) {
          _media.add(MediaItem(url: f.path, type: MediaType.image));
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final f = await picker.pickVideo(source: ImageSource.gallery);
    if (f != null) {
      setState(() => _media.add(MediaItem(url: f.path, type: MediaType.video)));
    }
  }

  Future<void> _addMediaUrl() async {
    final urlCtrl = TextEditingController();
    MediaType selected = MediaType.image;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add media from URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
            const SizedBox(height: 8),
            DropdownButtonFormField<MediaType>(
              value: selected,
              items: const [
                DropdownMenuItem(value: MediaType.image, child: Text('Image')),
                DropdownMenuItem(value: MediaType.video, child: Text('Video')),
              ],
              onChanged: (v) => selected = v ?? MediaType.image,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && urlCtrl.text.trim().isNotEmpty) {
      setState(() => _media.add(MediaItem(url: urlCtrl.text.trim(), type: selected)));
    }
  }

  void _removeMediaAt(int index) {
    setState(() => _media.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final double? price = double.tryParse(_priceCtrl.text.trim());
    final updates = <String, dynamic>{
      // title/name intentionally excluded
      'price': price,
      'description': _descCtrl.text.trim(),
      'tags': _tags,
      'is_active': _enabled,
      'is_visible_to_users': _isVisibleToUsers,
      'media_urls': _media.map((m) => m.url).toList(),
    };
    updates.removeWhere((k, v) => v == null);
    final ok = await _service.updateService(widget.item.id, updates);
    if (ok && mounted) {
      Navigator.of(context).pop(true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save service')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Media'),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(onPressed: _pickImages, icon: const Icon(Icons.image), label: const Text('Add Images')),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: _pickVideo, icon: const Icon(Icons.videocam), label: const Text('Add Video')),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _addMediaUrl, icon: const Icon(Icons.link), label: const Text('Add via URL')),
              const SizedBox(height: 12),
              if (_media.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _media.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, i) {
                    final m = _media[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: Colors.grey[200],
                            child: m.type == MediaType.image
                                ? (m.url.startsWith('http') || kIsWeb
                                    ? Image.network(m.url, fit: BoxFit.cover)
                                    : Image.file(File(m.url), fit: BoxFit.cover))
                                : const Center(child: Icon(Icons.play_circle_fill, size: 36, color: Colors.black54)),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkResponse(
                            onTap: () => _removeMediaAt(i),
                            radius: 18,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price (₹)'),
                keyboardType: TextInputType.number,
                validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter valid price' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in _tags)
                    Chip(
                      label: Text(t),
                      onDeleted: () {
                        setState(() => _tags.remove(t));
                      },
                    ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _tagCtrl,
                      decoration: const InputDecoration(labelText: 'Add tags (comma separated)'),
                      onSubmitted: (_) => _addTagsFromInput(),
                    ),
                  ),
                  IconButton(onPressed: _addTagsFromInput, icon: const Icon(Icons.add)),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
                title: const Text('Enabled'),
              ),
              SwitchListTile(
                value: _isVisibleToUsers,
                onChanged: (v) => setState(() => _isVisibleToUsers = v),
                title: const Text('Visible to users'),
              ),
              const SizedBox(height: 20),
              const Text('Availability'),
              const SizedBox(height: 8),
              AvailabilityCalendar(
                serviceId: widget.item.id,
                availabilityService: AvailabilityService(),
                isViewMode: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderLikeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  // onMove removed
  final bool selectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback? onLongPressSelect;
  const _FolderLikeCard({
    required this.title, 
    required this.subtitle, 
    required this.onTap, 
    this.onDelete, 
    this.selectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    this.onLongPressSelect,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (selectionMode) {
          onSelectedChanged?.call(!isSelected);
        } else {
          onTap();
        }
      },
      onLongPress: onLongPressSelect,
      child: Card(
        elevation: 4,
        shadowColor: Colors.black12,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.black26, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode) ...[
                Checkbox(value: isSelected, onChanged: onSelectedChanged),
                const SizedBox(width: 4),
              ],
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.folder, color: Colors.black45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.black54), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (onDelete != null && !selectionMode) ...[
                IconButton(
                  tooltip: 'Delete Category',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                ),
                const SizedBox(width: 8),
              ],
              // Drag/move UI removed
              const Icon(Icons.chevron_right)
            ],
          ),
        ),
      ),
    );
    return cardContent;
  }
}

class _AddServicePage extends StatefulWidget {
  final String? categoryId;

  const _AddServicePage({
    this.categoryId,
  });

  @override
  State<_AddServicePage> createState() => _AddServicePageState();
}

class _AddServicePageState extends State<_AddServicePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final List<String> _tags = <String>[];
  final List<MediaItem> _media = <MediaItem>[];
  bool _enabled = true;
  bool _isSaving = false;
  final AvailabilityCalendarController _availabilityController = AvailabilityCalendarController();

  // Extra fields for new service schema
  final _capacityMinCtrl = TextEditingController();
  final _capacityMaxCtrl = TextEditingController();
  final _parkingCtrl = TextEditingController();

  final _suitedCtrl = TextEditingController();
  final List<String> _suitedFor = <String>[];

  final _policyCtrl = TextEditingController();
  final List<String> _policies = <String>[];

  final _featKeyCtrl = TextEditingController();
  final _featValCtrl = TextEditingController();
  final List<MapEntry<String, String>> _features = <MapEntry<String, String>>[];
  String? _vendorCategory;

  bool get _shouldHideParkingField =>
      _vendorCategory == 'Photography' || _vendorCategory == 'Music/DJ';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final category = context.read<AppSession>().vendorProfile?.category;
    if (category != _vendorCategory) {
      _vendorCategory = category;
      if (_shouldHideParkingField) {
        _parkingCtrl.clear();
      }
    }
  }

  void _addTagFromInput() {
    final raw = _tagCtrl.text.trim();
    if (raw.isEmpty) return;
    for (final part in raw.split(',')) {
      final tag = part.trim();
      if (tag.isNotEmpty && !_tags.contains(tag)) {
        _tags.add(tag);
      }
    }
    _tagCtrl.clear();
    setState(() {});
  }

  void _addSuitedFromInput() {
    final raw = _suitedCtrl.text.trim();
    if (raw.isEmpty) return;
    for (final part in raw.split(',')) {
      final v = part.trim();
      if (v.isNotEmpty && !_suitedFor.contains(v)) _suitedFor.add(v);
    }
    _suitedCtrl.clear();
    setState(() {});
  }

  void _addPolicyFromInput() {
    final raw = _policyCtrl.text.trim();
    if (raw.isEmpty) return;
    for (final part in raw.split(',')) {
      final v = part.trim();
      if (v.isNotEmpty && !_policies.contains(v)) _policies.add(v);
    }
    _policyCtrl.clear();
    setState(() {});
  }

  void _addFeatureKV() {
    final k = _featKeyCtrl.text.trim();
    final v = _featValCtrl.text.trim();
    if (k.isEmpty || v.isEmpty) return;
    _features.add(MapEntry(k, v));
    _featKeyCtrl.clear();
    _featValCtrl.clear();
    setState(() {});
  }

  Future<void> _pickImages() async {
    final currentImageCount = _media.where((m) => m.type == MediaType.image).length;
    if (currentImageCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 images allowed. Please remove some images before adding more.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty) {
      final remainingSlots = 5 - currentImageCount;
      final filesToAdd = files.length > remainingSlots ? files.take(remainingSlots).toList() : files;
      
      if (files.length > remainingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Only $remainingSlots image(s) added. Maximum 5 images allowed.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      setState(() {
        for (final f in filesToAdd) {
          _media.add(MediaItem(url: f.path, type: MediaType.image));
        }
      });
    }
  }

  Future<void> _pickVideo() async {
    final currentVideoCount = _media.where((m) => m.type == MediaType.video).length;
    if (currentVideoCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 5 videos allowed. Please remove some videos before adding more.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final f = await picker.pickVideo(source: ImageSource.gallery);
    if (f != null) {
      setState(() => _media.add(MediaItem(url: f.path, type: MediaType.video)));
    }
  }

  Future<void> _addMediaUrl() async {
    final urlCtrl = TextEditingController();
    MediaType selected = MediaType.image;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add media from URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlCtrl, decoration: const InputDecoration(labelText: 'URL')),
            const SizedBox(height: 8),
            DropdownButtonFormField<MediaType>(
              value: selected,
              items: const [
                DropdownMenuItem(value: MediaType.image, child: Text('Image')),
                DropdownMenuItem(value: MediaType.video, child: Text('Video')),
              ],
              onChanged: (v) => selected = v ?? MediaType.image,
              decoration: const InputDecoration(labelText: 'Type'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && urlCtrl.text.trim().isNotEmpty) {
      final currentImageCount = _media.where((m) => m.type == MediaType.image).length;
      final currentVideoCount = _media.where((m) => m.type == MediaType.video).length;

      if (selected == MediaType.image && currentImageCount >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 5 images allowed. Please remove some images before adding more.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (selected == MediaType.video && currentVideoCount >= 5) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 5 videos allowed. Please remove some videos before adding more.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      setState(() => _media.add(MediaItem(url: urlCtrl.text.trim(), type: selected)));
    }
  }

  void _removeMediaAt(int index) {
    setState(() => _media.removeAt(index));
  }

  Future<List<String>> _prepareMediaUrls() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id ?? 'anon';
    final List<String> urls = <String>[];
    for (final m in _media) {
      final raw = m.url;
      if (raw.startsWith('http')) {
        urls.add(raw);
        continue;
      }
      // Only upload images to public bucket
      if (m.type != MediaType.image) {
        continue;
      }
      try {
        final file = File(raw);
        if (!await file.exists()) {
          continue;
        }
        final name = raw.split('/').isNotEmpty ? raw.split('/').last : 'media.jpg';
        final objectPath = 'services/$userId/${DateTime.now().millisecondsSinceEpoch}_$name';
        await client.storage.from('service-media').upload(objectPath, file);
        final publicUrl = client.storage.from('service-media').getPublicUrl(objectPath);
        urls.add(publicUrl);
      } catch (e) {
        // Skip failed uploads
      }
    }
    return urls;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate media requirements
    final imageCount = _media.where((m) => m.type == MediaType.image).length;
    final videoCount = _media.where((m) => m.type == MediaType.video).length;

    if (imageCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 2 images (minimum 2 required)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (imageCount > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum 5 images allowed. Please remove ${imageCount - 5} image(s)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (videoCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least 2 videos (minimum 2 required)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (videoCount > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum 5 videos allowed. Please remove ${videoCount - 5} video(s)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload local media to Supabase Storage and collect public URLs
      final mediaUrls = await _prepareMediaUrls();

      final capMin = int.tryParse(_capacityMinCtrl.text.trim());
      final capMax = int.tryParse(_capacityMaxCtrl.text.trim());
      final parking = int.tryParse(_parkingCtrl.text.trim());

      if (capMin != null && capMax != null && capMin > capMax) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capacity min cannot be greater than max')),
        );
        setState(() => _isSaving = false);
        return;
      }

      final featuresMap = _features.isEmpty
          ? null
          : { for (final e in _features) e.key: e.value };

      final service = await ServiceService().createService(
        name: _nameCtrl.text.trim(),
        categoryId: widget.categoryId, // allow null for root services
        price: double.parse(_priceCtrl.text),
        tags: List<String>.from(_tags),
        description: _descCtrl.text.trim(),
        mediaUrls: mediaUrls,
        capacityMin: capMin,
        capacityMax: capMax,
        parkingSpaces: parking,
        suitedFor: _suitedFor.isEmpty ? null : _suitedFor,
        features: featuresMap,
        policies: _policies.isEmpty ? null : _policies,
        isActive: _enabled,
      );

      if (service != null) {
        // Persist any availability overrides captured during creation
        final overrides = _availabilityController.getOverrides();
        if (overrides.isNotEmpty) {
          final availabilityService = AvailabilityService();
          for (final o in overrides) {
            await availabilityService.upsertOverride(service.id, o);
          }
        }
        // Optional: allow further fine-tuning after create
        if (mounted && overrides.isEmpty) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ServiceAvailabilityPage(item: service),
            ),
          );
        }
        if (mounted) Navigator.pop(context, service);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create service'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating service: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hideParkingField = _shouldHideParkingField;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Service'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Service Name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter number' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Enabled'),
                  const SizedBox(width: 8),
                  Switch(value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description *'),
                maxLines: 4,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              const Text('Tags'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ..._tags.map(
                    (t) => Chip(
                      label: Text(t),
                      onDeleted: () => setState(() => _tags.remove(t)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _tagCtrl,
                      decoration: const InputDecoration(hintText: 'Add tag'),
                      onSubmitted: (_) => _addTagFromInput(),
                      onChanged: (v) {
                        if (v.contains(',')) _addTagFromInput();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Media *', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Images: Minimum 2, Maximum 5 | Videos: Minimum 2, Maximum 5',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(onPressed: _pickImages, icon: const Icon(Icons.image), label: const Text('Add Images')),
                  const SizedBox(width: 8),
                  FilledButton.icon(onPressed: _pickVideo, icon: const Icon(Icons.videocam), label: const Text('Add Video')),
                ],
              ),
              const SizedBox(height: 8),
              TextButton.icon(onPressed: _addMediaUrl, icon: const Icon(Icons.link), label: const Text('Add via URL')),
              const SizedBox(height: 12),
              if (_media.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _media.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, i) {
                    final m = _media[i];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            color: Colors.grey[200],
                            child: m.type == MediaType.image
                                ? (m.url.startsWith('http') || kIsWeb
                                    ? Image.network(m.url, fit: BoxFit.cover)
                                    : Image.file(File(m.url), fit: BoxFit.cover))
                                : const Center(child: Icon(Icons.play_circle_fill, size: 36, color: Colors.black54)),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: InkResponse(
                            onTap: () => _removeMediaAt(i),
                            radius: 18,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    );
                  },
                ),
              const SizedBox(height: 16),

              // Service details block for new schema fields
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Service Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _capacityMinCtrl,
                            decoration: const InputDecoration(labelText: 'Capacity Min'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _capacityMaxCtrl,
                            decoration: const InputDecoration(labelText: 'Capacity Max'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    if (!hideParkingField) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _parkingCtrl,
                        decoration: const InputDecoration(labelText: 'Parking Spaces'),
                        keyboardType: TextInputType.number,
                      ),
                    ],
                    const SizedBox(height: 16),

                    const Text('Suited For'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ..._suitedFor.map(
                          (t) => Chip(
                            label: Text(t),
                            onDeleted: () => setState(() => _suitedFor.remove(t)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: TextField(
                            controller: _suitedCtrl,
                            decoration: const InputDecoration(hintText: 'Add item'),
                            onSubmitted: (_) => _addSuitedFromInput(),
                            onChanged: (v) { if (v.contains(',')) _addSuitedFromInput(); },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text('Features (key/value)'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _featKeyCtrl,
                            decoration: const InputDecoration(hintText: 'Key (e.g., AC)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _featValCtrl,
                            decoration: const InputDecoration(hintText: 'Value (e.g., Yes)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(onPressed: _addFeatureKV, child: const Text('Add')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_features.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _features.map((e) {
                          final label = '${e.key}: ${e.value}';
                          return Chip(
                            label: Text(label),
                            onDeleted: () {
                              setState(() => _features.remove(e));
                            },
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),

                    const Text('Policies'),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        ..._policies.map(
                          (t) => Chip(
                            label: Text(t),
                            onDeleted: () => setState(() => _policies.remove(t)),
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        SizedBox(
                          width: 250,
                          child: TextField(
                            controller: _policyCtrl,
                            decoration: const InputDecoration(hintText: 'Add policy'),
                            onSubmitted: (_) => _addPolicyFromInput(),
                            onChanged: (v) { if (v.contains(',')) _addPolicyFromInput(); },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Availability', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    AvailabilityCalendar(
                      serviceId: null, // create flow
                      availabilityService: AvailabilityService(),
                      controller: _availabilityController,
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
}

