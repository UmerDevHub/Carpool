import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';
import 'create_ride_screen.dart';
import 'ride_details_screen.dart';
import '../profile_screen.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({Key? key}) : super(key: key);

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> with SingleTickerProviderStateMixin {
  final RideService _rideService = RideService();

  String _selectedFilter = 'active';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _selectedIndex = 0;
  bool _hasActiveRide = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkForActiveRide(List<RideModel> rides) {
    // We only check for 'active' rides across ALL fetched data, regardless of the current filter
    final hasActive = rides.any((ride) => ride.status == 'active');

    if (_hasActiveRide != hasActive) {
      // Use scheduleMicrotask to avoid calling setState during build phase of parents
      Future.microtask(() {
        if (mounted) {
          setState(() {
            _hasActiveRide = hasActive;
          });
        }
      });
    }
  }

  void _onCreateRidePressed() {
    if (_hasActiveRide) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('You already have an active ride. Please cancel it before creating a new one.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreateRideScreen()),
      );
    }
  }

  Widget _buildMyRidesView(String driverUid, ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Filter Chips (Only visible on My Rides tab)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'My Trips',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800, // Reduced boldness slightly
                  fontSize: 20, // Adjusted font size
                ),
              ),
              const Spacer(),
              _buildFilterChip('All', 'all', theme, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Active', 'active', theme, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Done', 'completed', theme, isDark),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Rides List Stream
        Expanded(
          child: StreamBuilder<List<RideModel>>(
            stream: _rideService.getDriverRides(driverUid),
            builder: (context, snapshot) {

              if (snapshot.hasData && snapshot.data != null) {
                // Check for active ride after data is available
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkForActiveRide(snapshot.data!);
                });
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: theme.colorScheme.primary,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(theme, snapshot.error.toString());
              }

              List<RideModel> rides = snapshot.data ?? [];

              // Filter rides based on the selected chip
              if (_selectedFilter != 'all') {
                rides = rides.where((ride) => ride.status == _selectedFilter).toList();
              }
              // Optionally filter out 'cancelled' rides if they shouldn't show in the 'My Trips' view
              // I'll keep them out unless 'All' or 'History' is selected
              if (_selectedIndex == 0 && _selectedFilter != 'all') {
                rides = rides.where((ride) => ride.status != 'cancelled').toList();
              }


              if (rides.isEmpty) {
                return _buildEmptyState(theme, isDark,
                    _selectedFilter == 'active'
                        ? 'You have no active trips currently.'
                        : 'No rides found for this filter.');
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                itemCount: rides.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildRideCard(context, rides[index], theme, isDark),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRideHistoryView(String driverUid, ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Ride History',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800, // Reduced boldness slightly
              fontSize: 24, // Adjusted font size
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<RideModel>>(
            stream: _rideService.getDriverRides(driverUid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: theme.colorScheme.primary));
              }

              if (snapshot.hasError) {
                return _buildErrorState(theme, snapshot.error.toString());
              }

              // History shows ALL rides (active, completed, cancelled)
              List<RideModel> rides = snapshot.data ?? [];

              if (rides.isEmpty) {
                return _buildEmptyState(theme, isDark, 'No past ride history available.');
              }

              // Sort rides by date/time descending for history view
              rides.sort((a, b) => b.dateTime.compareTo(a.dateTime));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: rides.length,
                itemBuilder: (context, index) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildRideCard(context, rides[index], theme, isDark),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final driverUid = currentUser?.uid ?? '';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B).withOpacity(0.9)] // Darker gradient
                : [const Color(0xFFF8FAFC), const Color(0xFFE0E7FF)], // Soft light gradient
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Modern Header (Enhanced)
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.9),
                        theme.colorScheme.secondary.withOpacity(0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30), // Increased radius
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withOpacity(0.5), // Stronger shadow
                        blurRadius: 25,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14), // Slightly reduced padding
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3), // More prominent circle
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.5),
                            width: 2, // Reduced border width
                          ),
                        ),
                        child: const Icon(
                          Icons.drive_eta_rounded, // Changed icon for driver feel
                          size: 30, // Slightly reduced icon size
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14, // Reduced font size
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentUser?.name ?? 'Driver',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24, // Reduced font size
                                fontWeight: FontWeight.w800, // Reduced boldness slightly
                                letterSpacing: -0.5, // Adjusted letter spacing
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Content Stack
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    _buildMyRidesView(driverUid, theme, isDark),
                    _buildRideHistoryView(driverUid, theme, isDark),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // --- FAB USES NEW HANDLER ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onCreateRidePressed,
        icon: const Icon(Icons.add_rounded, size: 24), // Reduced icon size
        label: const Text('Create Ride', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)), // Reduced font size and boldness
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 10, // Reduced elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      // --- Bottom Navigation Bar ---
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Reduced shadow opacity
              blurRadius: 15, // Reduced blur radius
              offset: const Offset(0, -5), // Reduced offset
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              if (index == 2) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              } else {
                setState(() {
                  _selectedIndex = index;
                  if (index == 0) {
                    _selectedFilter = 'active';
                  }
                });
              }
            },
            elevation: 0,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            selectedItemColor: theme.colorScheme.primary,
            unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), // Reduced font size
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11), // Reduced font size
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.drive_eta_rounded, size: 24), // Reduced icon size
                label: 'My Rides',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded, size: 24), // Reduced icon size
                label: 'History',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_rounded, size: 24), // Reduced icon size
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, ThemeData theme, bool isDark) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Adjusted padding
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20), // Adjusted radius
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1, // Adjusted border width
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.3), // Reduced shadow opacity
              blurRadius: 8, // Reduced blur
              offset: const Offset(0, 4), // Reduced offset
            )
          ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, // Reduced boldness
            fontSize: 13, // Reduced font size
          ),
        ),
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, RideModel ride, ThemeData theme, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');

    Color statusColor;
    IconData statusIcon;

    switch (ride.status) {
      case 'active':
        statusColor = Colors.green.shade600;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'completed':
        statusColor = theme.colorScheme.secondary; // Using secondary for completion
        statusIcon = Icons.done_all_rounded;
        break;
      case 'cancelled':
        statusColor = Colors.red.shade600;
        statusIcon = Icons.cancel_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20), // Reduced radius
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), // Subtle border
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), // Reduced shadow opacity
            blurRadius: 15, // Reduced blur
            offset: const Offset(0, 8), // Reduced offset
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => RideDetailsScreen(ride: ride)),
            );
          },
          borderRadius: BorderRadius.circular(20), // Reduced radius
          child: Padding(
            padding: const EdgeInsets.all(20), // Reduced padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Status Chip (more defined background)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Adjusted padding
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16), // Reduced radius
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: statusColor), // Reduced icon size
                          const SizedBox(width: 6),
                          Text(
                            ride.status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11, // Reduced font size
                              fontWeight: FontWeight.w600, // Reduced boldness
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Seats Info
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), // Adjusted padding
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16), // Reduced radius
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event_seat_rounded,
                            size: 16, // Reduced icon size
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${ride.availableSeats}/${ride.totalSeats} seats',
                            style: TextStyle(
                              fontSize: 13, // Reduced font size
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600, // Reduced boldness
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Reduced spacing

                // Route with enhanced visuals
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        // Origin Point
                        Container(
                          padding: const EdgeInsets.all(8), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.green.shade500.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.circle,
                            size: 12, // Reduced icon size
                            color: Colors.green.shade500,
                          ),
                        ),
                        // Route Line (Dashed appearance with gradient)
                        Container(
                          width: 2, // Reduced width
                          height: 40, // Reduced height
                          margin: const EdgeInsets.symmetric(vertical: 4), // Adjusted margin
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1), // Reduced radius
                            gradient: LinearGradient(
                              colors: [
                                Colors.green.shade500.withOpacity(0.7),
                                Colors.red.shade500.withOpacity(0.7)
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        // Destination Point
                        Container(
                          padding: const EdgeInsets.all(8), // Reduced padding
                          decoration: BoxDecoration(
                            color: Colors.red.shade500.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 16, // Reduced icon size
                            color: Colors.red.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16), // Reduced spacing
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6), // Reduced spacing
                          Text(
                            'Departure',
                            style: theme.textTheme.labelSmall?.copyWith( // Used labelSmall
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            ride.origin,
                            style: theme.textTheme.titleMedium?.copyWith( // Reduced font size
                              fontWeight: FontWeight.w600, // Reduced boldness
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 30), // Reduced spacing between points
                          Text(
                            'Arrival',
                            style: theme.textTheme.labelSmall?.copyWith( // Used labelSmall
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          Text(
                            ride.destination,
                            style: theme.textTheme.titleMedium?.copyWith( // Reduced font size
                              fontWeight: FontWeight.w600, // Reduced boldness
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Reduced spacing

                // Date and Time (using a more pronounced background/separator)
                Container(
                  padding: const EdgeInsets.all(14), // Reduced padding
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : theme.colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12), // Reduced radius
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18, // Reduced icon size
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        dateFormat.format(ride.dateTime),
                        style: theme.textTheme.bodyMedium?.copyWith( // Reduced font size
                          fontWeight: FontWeight.w500, // Reduced boldness
                        ),
                      ),
                      const Spacer(),
                      // Divider
                      VerticalDivider(
                        color: isDark ? const Color(0xFF334155) : theme.colorScheme.primary.withOpacity(0.3),
                        width: 16, // Reduced width
                        thickness: 1,
                        indent: 5,
                        endIndent: 5,
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time_rounded,
                        size: 18, // Reduced icon size
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeFormat.format(ride.dateTime),
                        style: theme.textTheme.bodyMedium?.copyWith( // Reduced font size
                          fontWeight: FontWeight.w500, // Reduced boldness
                        ),
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

  Widget _buildEmptyState(ThemeData theme, bool isDark, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28), // Reduced padding
              decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : theme.colorScheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    width: 2,
                  )
              ),
              child: Icon(
                Icons.event_busy_rounded,
                size: 64, // Reduced icon size
                color: theme.colorScheme.primary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24), // Reduced spacing
            Text(
              message.split('.').first,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith( // Reduced to titleLarge
                fontWeight: FontWeight.w700, // Reduced boldness
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message.contains('.') ? message.split('.').last.trim() : 'Try creating a new ride.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith( // Reduced to bodyMedium
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded, size: 64, color: theme.colorScheme.error), // Reduced icon size
            const SizedBox(height: 16), // Reduced spacing
            Text(
              'Failed to load data',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), // Reduced boldness
            ),
            const SizedBox(height: 8),
            Text(
              'Error: ${error.contains('null') ? 'Check your connection or user ID.' : error}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}