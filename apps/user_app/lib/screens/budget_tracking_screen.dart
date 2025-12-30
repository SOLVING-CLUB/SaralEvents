import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event_planning_models.dart';
import '../services/event_planning_service.dart';
import '../core/input_formatters.dart';

class BudgetTrackingScreen extends StatefulWidget {
  final Event event;

  const BudgetTrackingScreen({
    super.key,
    required this.event,
  });

  @override
  State<BudgetTrackingScreen> createState() => _BudgetTrackingScreenState();
}

class _BudgetTrackingScreenState extends State<BudgetTrackingScreen> {
  late final EventPlanningService _eventService;
  List<BudgetItem> _budgetItems = [];
  List<Event> _allEvents = [];
  bool _isLoading = true;
  String? _error;
  
  double get _totalEstimated => _budgetItems.fold(0, (sum, item) => sum + item.estimatedCost);
  double get _totalActual => _budgetItems.fold(0, (sum, item) => sum + (item.actualCost ?? 0));
  double get _remainingBudget => (widget.event.budget ?? 0) - _totalActual;
  double get _budgetUsedPercentage => (widget.event.budget ?? 0) > 0 ? (_totalActual / (widget.event.budget ?? 0)) * 100 : 0;

  @override
  void initState() {
    super.initState();
    _eventService = EventPlanningService(Supabase.instance.client);
    _loadBudgetItems();
    _loadEventsForSwitcher();
  }

  Future<void> _loadEventsForSwitcher() async {
    try {
      final events = await _eventService.getEvents();
      if (!mounted) return;
      setState(() { _allEvents = events; });
    } catch (_) {}
  }

  Future<void> _loadBudgetItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _eventService.getBudgetItems(widget.event.id);
      setState(() {
        _budgetItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addBudgetItem() async {
    final result = await showDialog<BudgetItem>(
      context: context,
      builder: (context) => _BudgetItemDialog(eventId: widget.event.id),
    );

    if (result != null) {
      try {
        await _eventService.saveBudgetItem(result);
        _loadBudgetItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget item added successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add budget item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _editBudgetItem(BudgetItem item) async {
    final result = await showDialog<BudgetItem>(
      context: context,
      builder: (context) => _BudgetItemDialog(
        eventId: widget.event.id,
        existingItem: item,
      ),
    );

    if (result != null) {
      try {
        await _eventService.saveBudgetItem(result);
        _loadBudgetItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Budget item updated successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update budget item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteBudgetItem(BudgetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Budget Item'),
        content: Text('Are you sure you want to delete "${item.itemName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final BudgetItem deleted = item;
      // Optimistic remove
      setState(() { _budgetItems.removeWhere((b) => b.id == item.id); });

      // Snackbar with UNDO
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('"${item.itemName}" deleted'),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'UNDO',
                onPressed: () async {
                  await _eventService.saveBudgetItem(deleted);
                  if (mounted) _loadBudgetItems();
                },
              ),
            ),
          );
      }

      try {
        await _eventService.deleteBudgetItem(item.id, widget.event.id);
        _loadBudgetItems();
      } catch (e) {
        _loadBudgetItems();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete budget item: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Budget Tracking',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<Event>(
            tooltip: 'Switch Event',
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    widget.event.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
                const SizedBox(width: 8),
              ],
            ),
            onSelected: (ev) {
              if (ev.id == widget.event.id) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => BudgetTrackingScreen(event: ev)),
              );
            },
            itemBuilder: (context) {
              if (_allEvents.isEmpty) {
                return [
                  const PopupMenuItem<Event>(
                    enabled: false,
                    child: Text('No events found'),
                  ),
                ];
              }
              return _allEvents.map((e) => PopupMenuItem<Event>(
                value: e,
                child: Row(
                  children: [
                    Icon(e.type.icon, color: e.type.color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )).toList();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildBudgetSummary(),
                    Expanded(child: _buildBudgetItemsList()),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addBudgetItem,
        backgroundColor: const Color(0xFFFDBB42),
        foregroundColor: Colors.black87,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading budget',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBudgetItems,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Overview',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Budget Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Budget Used',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${_budgetUsedPercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _budgetUsedPercentage > 100 ? Colors.red : const Color(0xFFFDBB42),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _budgetUsedPercentage / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _budgetUsedPercentage > 100 ? Colors.red : const Color(0xFFFDBB42),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Budget Stats
          Row(
            children: [
              Expanded(
                child: _buildBudgetStat(
                  'Total Budget',
                  widget.event.budget != null ? '₹${widget.event.budget!.toStringAsFixed(0)}' : 'Not set',
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBudgetStat(
                  'Spent',
                  '₹${_totalActual.toStringAsFixed(0)}',
                  Icons.money_off,
                  _budgetUsedPercentage > 100 ? Colors.red : Colors.orange,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildBudgetStat(
                  'Estimated',
                  '₹${_totalEstimated.toStringAsFixed(0)}',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBudgetStat(
                  'Remaining',
                  '₹${_remainingBudget.toStringAsFixed(0)}',
                  Icons.savings,
                  _remainingBudget >= 0 ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStat(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItemsList() {
    if (_budgetItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No Budget Items',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add budget items to track your event expenses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _addBudgetItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Budget Item'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDBB42),
                foregroundColor: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    // Group items by category
    final groupedItems = <String, List<BudgetItem>>{};
    for (final item in _budgetItems) {
      groupedItems.putIfAbsent(item.category, () => []).add(item);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedItems.length,
      itemBuilder: (context, index) {
        final category = groupedItems.keys.elementAt(index);
        final items = groupedItems[category]!;
        final categoryTotal = items.fold(0.0, (sum, item) => sum + (item.actualCost ?? 0));
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '₹${categoryTotal.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFDBB42),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Category Items
              ...items.map((item) => _buildBudgetItemTile(item)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetItemTile(BudgetItem item) {
    return InkWell(
      onTap: () => _editBudgetItem(item),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey, width: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (item.vendorName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.vendorName!,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (item.actualCost != null)
                      Text(
                        '₹${item.actualCost!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text(
                      'Est: ₹${item.estimatedCost.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _editBudgetItem(item);
                        break;
                      case 'delete':
                        _deleteBudgetItem(item);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Payment Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.paymentStatus.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        item.paymentStatus.icon,
                        size: 12,
                        color: item.paymentStatus.color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.paymentStatus.displayName,
                        style: TextStyle(
                          color: item.paymentStatus.color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.paymentDate != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Paid: ${item.paymentDate!.day}/${item.paymentDate!.month}/${item.paymentDate!.year}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetItemDialog extends StatefulWidget {
  final String eventId;
  final BudgetItem? existingItem;

  const _BudgetItemDialog({
    required this.eventId,
    this.existingItem,
  });

  @override
  State<_BudgetItemDialog> createState() => _BudgetItemDialogState();
}

class _BudgetItemDialogState extends State<_BudgetItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemNameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _estimatedCostController = TextEditingController();
  final _actualCostController = TextEditingController();
  final _vendorNameController = TextEditingController();
  final _vendorContactController = TextEditingController();
  
  PaymentStatus _paymentStatus = PaymentStatus.pending;
  DateTime? _paymentDate;

  final List<String> _commonCategories = [
    'Venue',
    'Catering',
    'Photography',
    'Decoration',
    'Entertainment',
    'Transportation',
    'Flowers',
    'Invitations',
    'Gifts',
    'Miscellaneous',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _itemNameController.text = item.itemName;
      _categoryController.text = item.category;
      _estimatedCostController.text = item.estimatedCost.toString();
      _actualCostController.text = item.actualCost?.toString() ?? '';
      _vendorNameController.text = item.vendorName ?? '';
      _vendorContactController.text = item.vendorContact ?? '';
      _paymentStatus = item.paymentStatus;
      _paymentDate = item.paymentDate;
    }
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _categoryController.dispose();
    _estimatedCostController.dispose();
    _actualCostController.dispose();
    _vendorNameController.dispose();
    _vendorContactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFFDBB42),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.existingItem != null ? 'Edit Budget Item' : 'Add Budget Item',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.black87),
                  ),
                ],
              ),
            ),
            
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item Name
                      TextFormField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(
                          labelText: 'Item Name *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter item name';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Category
                      DropdownButtonFormField<String>(
                        value: _commonCategories.contains(_categoryController.text) 
                            ? _categoryController.text 
                            : null,
                        decoration: const InputDecoration(
                          labelText: 'Category *',
                          border: OutlineInputBorder(),
                        ),
                        items: _commonCategories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _categoryController.text = value;
                          }
                        },
                        validator: (value) {
                          if (_categoryController.text.trim().isEmpty) {
                            return 'Please select or enter category';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Estimated Cost
                      TextFormField(
                        controller: _estimatedCostController,
                        decoration: const InputDecoration(
                          labelText: 'Estimated Cost (₹) *',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter estimated cost';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter valid amount';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Actual Cost
                      TextFormField(
                        controller: _actualCostController,
                        decoration: const InputDecoration(
                          labelText: 'Actual Cost (₹)',
                          border: OutlineInputBorder(),
                          prefixText: '₹ ',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (double.tryParse(value) == null) {
                              return 'Please enter valid amount';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Vendor Name
                      TextFormField(
                        controller: _vendorNameController,
                        decoration: const InputDecoration(
                          labelText: 'Vendor Name',
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          LettersSpacesTextInputFormatter(),
                        ],
                        validator: (value) {
                          final v = (value ?? '').trim();
                          if (v.isEmpty) return null; // optional
                          if (v.length > 60) return 'Vendor name is too long';
                          if (!RegExp(r'^[A-Za-z ]+$').hasMatch(v)) {
                            return 'Use letters and spaces only';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Vendor Contact
                      TextFormField(
                        controller: _vendorContactController,
                        decoration: const InputDecoration(
                          labelText: 'Vendor Contact (10 digits)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          if (value != null && value.trim().isNotEmpty) {
                            if (value.length != 10) {
                              return 'Contact number must be 10 digits';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Payment Status
                      DropdownButtonFormField<PaymentStatus>(
                        value: _paymentStatus,
                        decoration: const InputDecoration(
                          labelText: 'Payment Status',
                          border: OutlineInputBorder(),
                        ),
                        items: PaymentStatus.values.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Row(
                              children: [
                                Icon(status.icon, size: 16, color: status.color),
                                const SizedBox(width: 8),
                                Text(status.displayName),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _paymentStatus = value;
                              if (value == PaymentStatus.paid && _paymentDate == null) {
                                _paymentDate = DateTime.now();
                              }
                            });
                          }
                        },
                      ),
                      
                      if (_paymentStatus == PaymentStatus.paid) ...[
                        const SizedBox(height: 16),
                        
                        // Payment Date
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _paymentDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setState(() {
                                _paymentDate = date;
                              });
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Payment Date',
                              border: OutlineInputBorder(),
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              _paymentDate != null
                                  ? '${_paymentDate!.day}/${_paymentDate!.month}/${_paymentDate!.year}'
                                  : 'Select payment date',
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveBudgetItem,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFDBB42),
                                foregroundColor: Colors.black87,
                              ),
                              child: Text(widget.existingItem != null ? 'Update' : 'Add'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveBudgetItem() {
    if (_formKey.currentState!.validate()) {
      final budgetItem = BudgetItem(
        id: widget.existingItem?.id ?? 'budget_${DateTime.now().millisecondsSinceEpoch}',
        eventId: widget.eventId,
        category: _categoryController.text.trim(),
        itemName: _itemNameController.text.trim(),
        estimatedCost: double.parse(_estimatedCostController.text),
        actualCost: _actualCostController.text.trim().isNotEmpty 
            ? double.parse(_actualCostController.text) 
            : null,
        vendorName: _vendorNameController.text.trim().isNotEmpty 
            ? _vendorNameController.text.trim() 
            : null,
        vendorContact: _vendorContactController.text.trim().isNotEmpty 
            ? _vendorContactController.text.trim() 
            : null,
        paymentStatus: _paymentStatus,
        paymentDate: _paymentDate,
        createdAt: widget.existingItem?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      Navigator.pop(context, budgetItem);
    }
  }
}