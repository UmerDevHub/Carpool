import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import '../../services/shared_prefs_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../driver/map_selection_screen.dart';

class SearchRidesScreen extends StatefulWidget {
  const SearchRidesScreen({Key? key}) : super(key: key);

  @override
  State<SearchRidesScreen> createState() => _SearchRidesScreenState();
}

class _SearchRidesScreenState extends State<SearchRidesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final RideService _rideService = RideService();

  DateTime? _selectedDate;
  bool _hasSearched = false;
  List<Map<String, String>> _recentSearches = [];
  List<Map<String, String>> _favoriteRoutes = [];

  // Store full location data from map selection
  Map<String, dynamic>? _originLocationData;
  Map<String, dynamic>? _destinationLocationData;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  void _loadSavedData() {
    _recentSearches = SharedPrefsService.getRecentSearches();
    _favoriteRoutes = SharedPrefsService.getFavoriteRoutes();

    String? lastOrigin = SharedPrefsService.getLastSearchOrigin();
    String? lastDestination = SharedPrefsService.getLastSearchDestination();

    if (lastOrigin != null && lastOrigin.isNotEmpty) {
      _originController.text = lastOrigin;
    }
    if (lastDestination != null && lastDestination.isNotEmpty) {
      _destinationController.text = lastDestination;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _selectLocationOnMap(bool isOrigin) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(
          title: isOrigin ? 'Select Starting Point' : 'Select Destination',
          initialLocation: isOrigin ? _originController.text : _destinationController.text,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (isOrigin) {
          _originLocationData = result;
          _originController.text = result['displayName'] ?? result['locationName'] ?? '';
        } else {
          _destinationLocationData = result;
          _destinationController.text = result['displayName'] ?? result['locationName'] ?? '';
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _search() async {
    if (_formKey.currentState!.validate()) {
      await SharedPrefsService.addRecentSearch(
        _originController.text.trim(),
        _destinationController.text.trim(),
      );

      await SharedPrefsService.saveLastSearch(
        origin: _originController.text.trim(),
        destination: _destinationController.text.trim(),
      );

      setState(() {
        _hasSearched = true;
        _recentSearches = SharedPrefsService.getRecentSearches();
      });
    }
  }

  void _clearSearch() {
    setState(() {
      _originController.clear();
      _destinationController.clear();
      _selectedDate = null;
      _hasSearched = false;
      _originLocationData = null;
      _destinationLocationData = null;
    });
  }

  void _useRecentSearch(String origin, String destination) {
    setState(() {
      _originController.text = origin;
      _destinationController.text = destination;
      // We clear location data when using recent search as the exact coordinate match is lost
      _originLocationData = null;
      _destinationLocationData = null;
    });
  }

  Future<void> _toggleFavorite() async {
    String origin = _originController.text.trim();
    String destination = _destinationController.text.trim();

    if (origin.isEmpty || destination.isEmpty) return;

    bool isFavorite = SharedPrefsService.isFavoriteRoute(origin, destination);

    if (isFavorite) {
      await SharedPrefsService.removeFavoriteRoute(origin, destination);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from favorites'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      await SharedPrefsService.addFavoriteRoute(origin, destination);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Added to favorites'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }

    setState(() {
      _favoriteRoutes = SharedPrefsService.getFavoriteRoutes();
    });
  }

  Future<void> _bookRide(RideModel ride) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    final theme = Theme.of(context);

    // Calculate price for one seat booking
    final double bookingPrice = ride.price * 1;
    final String priceString = 'PKR ${bookingPrice.toStringAsFixed(2)}';

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to book a ride.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // --- Check for existing booking for this ride by this passenger ---
    bool alreadyBooked = false;
    try {
      alreadyBooked = await _rideService.checkExistingBooking(
        ride.rideId,
        currentUser.uid,
      );
    } catch (e) {
      // Handle check error if needed
    }

    if (alreadyBooked) {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Already Booked'),
          content: const Text('You already have a confirmed booking for this ride.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('OK', style: TextStyle(color: theme.colorScheme.primary)),
            ),
          ],
        ),
      );
      return;
    }
    // --- END NEW CHECK ---

    // 1. Confirmation Dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Book ONE seat on the ride from ${ride.origin} to ${ride.destination}?',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.event_seat, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Available seats: ${ride.availableSeats}',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Display Total Price (now Total Fare in PKR)
            Row(
              children: [
                // Icon changed to indicate fare/price without currency association
                Icon(Icons.label_important_rounded, size: 20, color: Colors.teal[700]),
                const SizedBox(width: 8),
                Text(
                  'Total Fare: $priceString',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: theme.colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Book'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    // 2. Execute Booking
    try {
      // Show loading indicator temporarily (using SnackBar or similar)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Processing booking...'),
            ],
          ),
          duration: const Duration(seconds: 5),
          backgroundColor: theme.colorScheme.secondary,
        ),
      );


      await _rideService.bookRide(
        rideId: ride.rideId,
        passengerId: currentUser.uid,
        passengerName: currentUser.name,
        passengerPhone: currentUser.phone,
        seatsToBook: 1, // Fixed to 1 seat
      );

      if (mounted) {
        // Clear loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        // 3. Show Success Dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Booking Successful!'),
            content: Text('Your ride is booked for $priceString. You will now be redirected to your Upcoming Rides.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), // Dismiss dialog
                child: Text('View Ride', style: TextStyle(color: theme.colorScheme.primary)),
              ),
            ],
          ),
        );

        // 4. Navigate to Passenger Dashboard and switch to the Upcoming tab (Index 1)
        Navigator.pop(context, 1);
      }
    } catch (e) {
      if (mounted) {
        // Clear loading snackbar
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking ride: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch phone dialer'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildLocationField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    required Color iconColor,
    required bool isOrigin,
  }) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              prefixIcon: Icon(prefixIcon, color: iconColor),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            },
            onChanged: (value) {
              setState(() {
                if (isOrigin) {
                  _originLocationData = null;
                } else {
                  _destinationLocationData = null;
                }
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            ),
          ),
          child: IconButton(
            icon: Icon(
              Icons.map_rounded,
              // FIX: Use onSurface color for the icon to ensure high contrast
              // against the accent-colored container background in both dark and light modes.
              color: Theme.of(context).colorScheme.onSurface,
            ),
            tooltip: 'Select on map',
            onPressed: () => _selectLocationOnMap(isOrigin),
          ),
        ),
      ],
    );
  }

  /**
   * Performs case-insensitive, keyword-based substring matching.
   * A match is found if:
   * 1. The full search term is contained within the ride location.
   * 2. OR, if at least one significant keyword (length > 2) from the search term
   * is contained within the ride location.
   */
  bool _isFuzzyMatch(String rideLocation, String searchTerm) {
    final normalizedRide = rideLocation.toLowerCase();
    final normalizedSearch = searchTerm.toLowerCase().trim();

    if (normalizedSearch.isEmpty) return true; // Empty search term matches everything

    // 1. Check if the full search term is contained (e.g., searching "New Y" matches "New York")
    if (normalizedRide.contains(normalizedSearch)) {
      return true;
    }

    // 2. Check if any *word* in the search term is contained (keyword matching)
    final keywords = normalizedSearch
        .split(RegExp(r'\s+')) // Split by whitespace
        .where((t) => t.length > 2) // Exclude very short words
        .toList();

    if (keywords.isEmpty) {
      // If the search term was only very short words, and it didn't pass rule 1, no match.
      return false;
    }

    // Check if ANY of the significant keywords are contained in the ride location
    return keywords.any((keyword) => normalizedRide.contains(keyword));
  }

  @override
  Widget build(BuildContext context) {
    String origin = _originController.text.trim();
    String destination = _destinationController.text.trim();
    bool isFavorite = origin.isNotEmpty && destination.isNotEmpty &&
        SharedPrefsService.isFavoriteRoute(origin, destination);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Rides'),
        actions: [
          if (origin.isNotEmpty && destination.isNotEmpty)
            IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              onPressed: _toggleFavorite,
              tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Form Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Origin Field with Map Button
                  _buildLocationField(
                    controller: _originController,
                    label: 'From',
                    hint: 'Enter starting point',
                    prefixIcon: Icons.trip_origin,
                    iconColor: Colors.green,
                    isOrigin: true,
                  ),

                  // Visual indicator if location was selected from map (simplified)
                  if (_originLocationData != null) ...[
                    const SizedBox(height: 8),
                    _buildLocationIndicator(Colors.green),
                  ],
                  const SizedBox(height: 16),

                  // Destination Field with Map Button
                  _buildLocationField(
                    controller: _destinationController,
                    label: 'To',
                    hint: 'Enter destination',
                    prefixIcon: Icons.location_on,
                    iconColor: Colors.red,
                    isOrigin: false,
                  ),

                  // Visual indicator if location was selected from map (simplified)
                  if (_destinationLocationData != null) ...[
                    const SizedBox(height: 8),
                    _buildLocationIndicator(Colors.red),
                  ],
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).scaffoldBackgroundColor,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedDate == null
                                  ? 'Select date (optional)'
                                  : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                              style: TextStyle(
                                fontSize: 15,
                                color: _selectedDate == null
                                    ? Colors.grey[600]
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (_selectedDate != null)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _selectedDate = null;
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _search,
                          icon: const Icon(Icons.search),
                          label: const Text('Search Rides'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      if (_hasSearched) ...[
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: _clearSearch,
                          icon: const Icon(Icons.refresh),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            foregroundColor: Theme.of(context).colorScheme.primary,
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Content Area (Recents/Favorites OR Search Results)
          if (!_hasSearched && (_recentSearches.isNotEmpty || _favoriteRoutes.isNotEmpty))
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_favoriteRoutes.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Favorite Routes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._favoriteRoutes.map((route) => _buildRouteCard(
                        route['origin']!,
                        route['destination']!,
                        isFavorite: true,
                      )),
                      const SizedBox(height: 24),
                    ],

                    if (_recentSearches.isNotEmpty) ...[
                      Row(
                        children: [
                          Icon(Icons.history, color: Colors.grey[600], size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Recent Searches',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () async {
                              await SharedPrefsService.clearRecentSearches();
                              setState(() {
                                _recentSearches = [];
                              });
                            },
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._recentSearches.map((search) => _buildRouteCard(
                        search['origin']!,
                        search['destination']!,
                      )),
                    ],
                  ],
                ),
              ),
            )
          else if (_hasSearched)
            Expanded(
              child: StreamBuilder<List<RideModel>>(
                // Fetch a broad set of active rides and filter on the client
                stream: _rideService.searchRides(origin: null, destination: null, date: null),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 60, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading rides',
                            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              '${snapshot.error}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  List<RideModel> rides = snapshot.data ?? [];

                  // Get search terms from controllers for client-side fuzzy filtering
                  final originSearchTerm = _originController.text.trim();
                  final destinationSearchTerm = _destinationController.text.trim();


                  rides = rides.where((ride) {
                    if (ride.availableSeats <= 0) return false;
                    if (ride.status != 'active') return false;

                    // --- NEW: Apply Fuzzy/Keyword Matching ---
                    if (!_isFuzzyMatch(ride.origin, originSearchTerm)) return false;
                    if (!_isFuzzyMatch(ride.destination, destinationSearchTerm)) return false;
                    // ------------------------------------------

                    if (_selectedDate != null) {
                      return ride.dateTime.year == _selectedDate!.year &&
                          ride.dateTime.month == _selectedDate!.month &&
                          ride.dateTime.day == _selectedDate!.day;
                    }

                    return true;
                  }).toList();

                  rides.sort((a, b) => a.dateTime.compareTo(b.dateTime));

                  if (rides.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No rides found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              'Try searching for "$originSearchTerm" to "$destinationSearchTerm".\n\nSearch is now flexible and case-insensitive.',
                              style: TextStyle(
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rides.length,
                    itemBuilder: (context, index) {
                      return _buildRideCard(rides[index]);
                    },
                  );
                },
              ),
            )
          else
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search for available rides',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // The previous _buildSearchQuery logic is now primarily handled by client-side filtering.
  // We keep this function but simplify it to fetch a broad set of data.
  Stream<List<RideModel>> _buildSearchQuery() {
    return _rideService.searchRides(
      origin: null, // Set to null to fetch a broad stream from the service
      destination: null, // Set to null to fetch a broad stream from the service
      date: null,
    );
  }

  Widget _buildRouteCard(String origin, String destination, {bool isFavorite = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          isFavorite ? Icons.favorite : Icons.history,
          color: isFavorite ? Colors.red : Colors.grey[600],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                origin,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                destination,
                style: const TextStyle(fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        onTap: () => _useRecentSearch(origin, destination),
      ),
    );
  }

  // UPDATED: Refactored _buildRideCard to display details vertically for responsiveness
  Widget _buildRideCard(RideModel ride) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final theme = Theme.of(context);
    final String pricePerSeatString = 'PKR ${ride.price.toStringAsFixed(2)}';

    // Helper widget for a single detail line (Date, Time, Seats, Price)
    Widget buildDetailLine({
      required IconData icon,
      required String label,
      required String value,
      Color? iconColor,
      TextStyle? valueStyle,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? Colors.grey[600]),
            const SizedBox(width: 8),
            Text(
              '$label:',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(width: 4),
            // Expanded to ensure the value text does not overflow horizontally
            Expanded(
              child: Text(
                value,
                style: valueStyle ?? theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Driver Details Row ---
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  child: Icon(
                    Icons.person_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.driverName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Driver',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _makePhoneCall(ride.driverPhone),
                  icon: Icon(
                    Icons.phone,
                    color: theme.colorScheme.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),

            const Divider(height: 30),

            // --- 2. Route Details ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Origin/Destination Icons and Line
                Column(
                  children: [
                    Icon(Icons.trip_origin_rounded, size: 20, color: Colors.green[700]),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Container(
                        width: 2,
                        height: 30, // Fixed height for vertical line segment
                        color: Colors.grey[400],
                      ),
                    ),
                    Icon(Icons.location_on_rounded, size: 20, color: Colors.red[700]),
                  ],
                ),
                const SizedBox(width: 12),

                // Origin/Destination Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Origin
                      Text(
                        ride.origin.toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 40), // Spacing to align with the vertical line

                      // Destination
                      Text(
                        ride.destination.toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- 3. Details Stack (Vertical Layout) ---
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildDetailLine(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: dateFormat.format(ride.dateTime),
                ),
                buildDetailLine(
                  icon: Icons.access_time_rounded,
                  label: 'Time',
                  value: timeFormat.format(ride.dateTime),
                ),
                buildDetailLine(
                  icon: Icons.event_seat_rounded,
                  label: 'Available Seats',
                  value: '${ride.availableSeats}',
                  iconColor: theme.colorScheme.primary,
                ),
                buildDetailLine(
                  icon: Icons.label_important_rounded,
                  label: 'Fare per seat',
                  value: pricePerSeatString,
                  iconColor: Colors.teal[700],
                  valueStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.teal[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // --- 4. Book Button (Full Width) ---
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _bookRide(ride),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 3,
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationIndicator(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: color.withOpacity(0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Location selected from map',
              style: TextStyle(
                fontSize: 12,
                color: color.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}