import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_models.dart';
import '../services/booking_draft_service.dart';
import '../widgets/user_availability_calendar.dart';
import '../widgets/time_slot_picker.dart';
import '../services/availability_service.dart';
import '../services/refund_service.dart';
import '../checkout/checkout_state.dart';
import '../checkout/booking_flow.dart';
import 'package:provider/provider.dart';

class BookingScreen extends StatefulWidget {
  final ServiceItem service;

  const BookingScreen({super.key, required this.service});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final BookingDraftService _draftService;
  late final AvailabilityService _availabilityService;
  late final RefundService _refundService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _locationLinkController = TextEditingController();
  bool _isLoading = false;
  List<TimeSlot> _availableTimeSlots = [];
  TimeSlot? _selectedTimeSlot;
  String? _actualVendorCategory;
  bool _isLoadingCategory = false;
  String? _cancellationPolicyWarning;
  
  // Categories that require location link (normalized to lowercase for robust matching)
  static const List<String> _locationRequiredCategories = [
    'photography',
    'decoration',
    'catering',
    'music/dj',
    'essentials',
  ];
  
  bool get _requiresLocationLink {
    // Use fetched category if available, otherwise fall back to service's category
    final category = _actualVendorCategory ?? widget.service.vendorCategory;
    if (category == null) {
      if (!_isLoadingCategory) {
        print('⚠️ WARNING: vendorCategory is null for service ${widget.service.id}');
        print('   Service Name: ${widget.service.name}');
        print('   Vendor ID: ${widget.service.vendorId}');
        print('   Vendor Name: ${widget.service.vendorName}');
      }
      return false;
    }
    final normalized = category.trim().toLowerCase();
    final requires = _locationRequiredCategories.contains(normalized);
    if (!_isLoadingCategory) {
      print('📍 Location Link Check: category="$category" (normalized="$normalized") -> requires=$requires');
    }
    return requires;
  }

  @override
  void initState() {
    super.initState();
    _draftService = BookingDraftService(Supabase.instance.client);
    _availabilityService = AvailabilityService(Supabase.instance.client);
    _refundService = RefundService(Supabase.instance.client);
    
    // Debug: Print service information
    print('=== BOOKING SCREEN DEBUG ===');
    print('Service Name: ${widget.service.name}');
    print('Service ID: ${widget.service.id}');
    print('Vendor ID: ${widget.service.vendorId}');
    print('Vendor Name: ${widget.service.vendorName}');
    print('Vendor Category: ${widget.service.vendorCategory}');
    print('Service Price: ${widget.service.price}');
    print('Requires Location Link: $_requiresLocationLink');
    print('============================');
    
    // If vendorCategory is missing, fetch it from vendor_profiles
    if (widget.service.vendorCategory == null) {
      _fetchVendorCategory();
    } else {
      _actualVendorCategory = widget.service.vendorCategory;
    }
  }

  Future<void> _fetchVendorCategory() async {
    if (_isLoadingCategory) return;
    
    setState(() {
      _isLoadingCategory = true;
    });
    
    try {
      final result = await Supabase.instance.client
          .from('vendor_profiles')
          .select('category')
          .eq('id', widget.service.vendorId)
          .maybeSingle();
      
      if (result != null) {
        final category = result['category'] as String?;
        setState(() {
          _actualVendorCategory = category;
          _isLoadingCategory = false;
        });
        print('✅ Fetched vendor category: $category');
        print('📍 Normalized category: ${category?.trim().toLowerCase()}');
        print('📍 Required categories: $_locationRequiredCategories');
        print('📍 Now requires location link: $_requiresLocationLink');
        print('📍 Will trigger UI rebuild to show/hide location field');
      } else {
        print('⚠️ Vendor profile not found for vendor ID: ${widget.service.vendorId}');
        setState(() {
          _isLoadingCategory = false;
        });
      }
    } catch (e) {
      print('❌ Error fetching vendor category: $e');
      setState(() {
        _isLoadingCategory = false;
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _locationLinkController.dispose();
    super.dispose();
  }

  void _onDateSelected(DateTime date, TimeOfDay? time) {
    setState(() {
      _selectedDate = date;
      _selectedTime = time;
      _selectedTimeSlot = null;
      _availableTimeSlots = [];
    });
    
    // Check cancellation policy warning
    final category = _actualVendorCategory ?? widget.service.vendorCategory;
    if (category != null) {
      final warning = _refundService.getCancellationPolicyWarning(
        vendorCategory: category,
        bookingDate: date,
        currentDate: DateTime.now(),
      );
      setState(() {
        _cancellationPolicyWarning = warning;
      });
    }
    
    // Load available time slots for the selected date
    _loadTimeSlotsForDate(date);
  }

  void _onTimeSlotSelected(TimeSlot slot) {
    setState(() {
      _selectedTimeSlot = slot;
      _selectedTime = slot.startTime;
    });
  }

  Future<void> _loadTimeSlotsForDate(DateTime date) async {
    try {
      final timeSlotsData = await _availabilityService.getAvailableTimeSlots(widget.service.id, date);
      
      final slots = timeSlotsData.map((slotData) {
        final startTimeParts = slotData['start_time'].split(':');
        final endTimeParts = slotData['end_time'].split(':');
        
        return TimeSlot(
          startTime: TimeOfDay(
            hour: int.parse(startTimeParts[0]),
            minute: int.parse(startTimeParts[1]),
          ),
          endTime: TimeOfDay(
            hour: int.parse(endTimeParts[0]),
            minute: int.parse(endTimeParts[1]),
          ),
          isAvailable: slotData['is_available'] as bool,
        );
      }).toList();
      
      setState(() {
        _availableTimeSlots = slots;
      });
    } catch (e) {
      print('Error loading time slots: $e');
      setState(() {
        _availableTimeSlots = [];
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Book Service',
          style: theme.textTheme.titleLarge,
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service Details Card
            _buildServiceCard(),
            const SizedBox(height: 24),

            // Availability Calendar
            _buildSectionTitle('Select Date & Time', Icons.calendar_today),
            const SizedBox(height: 12),
            _buildAvailabilityCalendar(),
            const SizedBox(height: 24),

            // Cancellation Policy Warning (if applicable)
            if (_selectedDate != null && _cancellationPolicyWarning != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _cancellationPolicyWarning!,
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Time Slots (if date is selected) - MANDATORY
            if (_selectedDate != null) ...[
              _buildSectionTitle('Available Time Slots *', Icons.access_time),
              const SizedBox(height: 12),
              if (_availableTimeSlots.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline, 
                        color: Theme.of(context).colorScheme.onErrorContainer, 
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No time slots available for this date. Please select another date.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer, 
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildTimeSlotPicker(),
              if (_selectedTimeSlot == null && _availableTimeSlots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '⚠️ Please select a time slot to continue',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error, 
                      fontSize: 13, 
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],

            // Location Link (mandatory for specific categories)
            if (_requiresLocationLink) ...[
              _buildSectionTitle('Destination Location Link *', Icons.location_on),
              const SizedBox(height: 12),
              _buildLocationLinkField(),
              const SizedBox(height: 24),
            ],
            
            // Notes
            _buildSectionTitle('Additional Notes', Icons.note),
            const SizedBox(height: 12),
            _buildNotesField(),
            const SizedBox(height: 32),

            // Booking Summary
            _buildBookingSummary(),
            const SizedBox(height: 24),

            // Book Now Button
            _buildBookButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(0.1),
                theme.colorScheme.primary.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Service Icon
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getServiceIcon(widget.service.name),
                    size: 35,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 20),
                // Service Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.service.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.service.vendorName.isNotEmpty ? widget.service.vendorName : 'Vendor',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            '₹',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            widget.service.price.toStringAsFixed(0),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAvailabilityCalendar() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: UserAvailabilityCalendar(
          serviceId: widget.service.id,
          vendorId: widget.service.vendorId,
          onDateSelected: _onDateSelected,
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
        ),
      ),
    );
  }

  Widget _buildTimeSlotPicker() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TimeSlotPicker(
          availableSlots: _availableTimeSlots,
          selectedSlot: _selectedTimeSlot,
          onSlotSelected: _onTimeSlotSelected,
        ),
      ),
    );
  }


  Widget _buildLocationLinkField() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _locationLinkController,
        keyboardType: TextInputType.url,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Paste Google Maps location link here...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          prefixIcon: const Icon(Icons.location_on, color: Colors.green),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(20),
          helperText: 'Vendor needs this to reach your location',
          helperMaxLines: 2,
        ),
        onChanged: (_) => setState(() {}), // Trigger rebuild for validation
      ),
    );
  }

  Widget _buildNotesField() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 4,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Add any special requirements or notes...',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildBookingSummary() {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.cardColor,
                theme.colorScheme.primary.withOpacity(0.05),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long,
                        color: theme.colorScheme.onPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Booking Summary',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildSummaryRow('Service', widget.service.name),
                _buildSummaryRow('Vendor', widget.service.vendorName),
                _buildSummaryRow('Date', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : 'Not selected'),
                _buildSummaryRow('Time', _selectedTimeSlot != null 
                    ? _selectedTimeSlot!.formattedTime
                    : (_selectedTime != null 
                        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                        : 'Not selected')),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount:',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '₹',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          widget.service.price.toStringAsFixed(0),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton() {
    // Require both date AND time slot selection
    // Also require location link for specific categories
    final hasLocationLink = !_requiresLocationLink || 
        (_locationLinkController.text.trim().isNotEmpty);
    final canProceed = _selectedDate != null && 
        _selectedTimeSlot != null && 
        hasLocationLink;
    
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFDBB42).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
        child: ElevatedButton(
        onPressed: (_isLoading || !canProceed)
            ? null
            : () async {
                // Double-check: Ensure time slot is selected
                if (_selectedTimeSlot == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please select a time slot to continue'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  setState(() => _isLoading = false);
                  return;
                }
                
                // Validate location link for required categories
                if (_requiresLocationLink && _locationLinkController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Please provide the destination location link'),
                      backgroundColor: Theme.of(context).colorScheme.error,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                  setState(() => _isLoading = false);
                  return;
                }
                setState(() => _isLoading = true);
                try {
                  // Save as draft instead of creating booking
                  final draftId = await _draftService.saveDraft(
                    serviceId: widget.service.id,
                    vendorId: widget.service.vendorId,
                    bookingDate: _selectedDate,
                    bookingTime: _selectedTime,
                    amount: widget.service.price,
                    notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
                    locationLink: _requiresLocationLink 
                        ? (_locationLinkController.text.trim().isNotEmpty 
                            ? _locationLinkController.text.trim() 
                            : null)
                        : null,
                  );

                  if (!mounted) return;

                  if (draftId != null) {
                    // Add item to cart and set draft ID
                    final checkoutState = Provider.of<CheckoutState>(context, listen: false);
                    final item = CartItem(
                      id: widget.service.id,
                      locationLink: _requiresLocationLink 
                          ? _locationLinkController.text.trim() 
                          : null,
                      title: widget.service.name,
                      category: 'Service',
                      price: widget.service.price,
                      subtitle: widget.service.vendorName,
                      bookingDate: _selectedDate,
                      bookingTime: _selectedTime,
                    );
                    
                    // Add item to cart (do NOT clear existing cart items)
                    // This enables multi-service checkout from cart.
                    await checkoutState.addItem(item);
                    // NOTE: CheckoutState currently supports only a single draftId; setting it here
                    // would overwrite any previous draft reference when multiple services are added.
                    // Keeping draftId unset avoids cart items being "replaced" conceptually.
                    
                    // Navigate to clean booking flow
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BookingFlow(),
                        ),
                      );
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Failed to save booking details. Please try again.'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    final errorMessage = e.toString();
                    String userMessage = 'Failed to save booking details.';
                    
                    // Check for specific errors
                    if (errorMessage.toLowerCase().contains('relation') && 
                        errorMessage.toLowerCase().contains('does not exist')) {
                      userMessage = 'Database table missing. Please contact support.';
                    } else if (errorMessage.toLowerCase().contains('permission') ||
                               errorMessage.toLowerCase().contains('policy')) {
                      userMessage = 'Permission denied. Please check your account.';
                    } else {
                      userMessage = 'Error: ${errorMessage.length > 100 ? "${errorMessage.substring(0, 100)}..." : errorMessage}';
                    }
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(userMessage),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        duration: const Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'Dismiss',
                          textColor: Theme.of(context).colorScheme.onError,
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          },
                        ),
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.onPrimary,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    canProceed ? 'Confirm Booking' : 'Select Time Slot',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('photography') || name.contains('photo') || name.contains('camera')) {
      return Icons.camera_alt;
    } else if (name.contains('catering') || name.contains('food') || name.contains('meal')) {
      return Icons.restaurant;
    } else if (name.contains('decoration') || name.contains('decor') || name.contains('flower')) {
      return Icons.local_florist;
    } else if (name.contains('music') || name.contains('dj') || name.contains('sound')) {
      return Icons.music_note;
    } else if (name.contains('venue') || name.contains('hall') || name.contains('place')) {
      return Icons.location_on;
    } else if (name.contains('transport') || name.contains('car') || name.contains('vehicle')) {
      return Icons.directions_car;
    } else if (name.contains('makeup') || name.contains('beauty') || name.contains('salon')) {
      return Icons.face;
    } else if (name.contains('dress') || name.contains('clothing') || name.contains('suit')) {
      return Icons.checkroom;
    } else {
      return Icons.miscellaneous_services;
    }
  }

}
