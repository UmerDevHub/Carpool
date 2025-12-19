import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // Import for AdMob
import '../../providers/auth_provider.dart';
import '../../models/booking_model.dart';
import '../../models/ride_model.dart'; // IMPORTANT: We need RideModel to check ride status
import '../../services/ride_service.dart';
import 'search_rides_screen.dart';
import 'booking_details_screen.dart';
import '../profile_screen.dart';

class PassengerDashboard extends StatefulWidget {
  const PassengerDashboard({Key? key}) : super(key: key);

  @override
  State<PassengerDashboard> createState() => _PassengerDashboardState();
}

class _PassengerDashboardState extends State<PassengerDashboard> with SingleTickerProviderStateMixin {
  final RideService _rideService = RideService();
  // 0: Search, 1: Upcoming Rides, 2: History
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // AdMob Variables
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;
  final String _adUnitId = 'ca-app-pub-3940256099942544/6300978111'; // Test Ad Unit ID (Android Banner)

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Only load banner ads on non-web platforms to avoid runtime issues on web
    if (!kIsWeb) {
      _loadBannerAd(); // Start loading the banner ad
    }
  }

  // AdMob Method: Load Banner Ad
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('Ad loaded successfully: ${ad.adUnitId}');
          setState(() {
            _isAdLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Ad failed to load: ${ad.adUnitId}, Error: $error');
          ad.dispose();
          setState(() {
            _isAdLoaded = false;
          });
        },
        onAdOpened: (ad) => debugPrint('Ad opened.'),
        onAdClosed: (ad) => debugPrint('Ad closed.'),
      ),
    );

    _bannerAd!.load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bannerAd?.dispose(); // Dispose the ad
    super.dispose();
  }

  // Helper to trigger fade animation on tab switch
  void _onTap(int index) {
    // Index 3 is Profile, handled separately
    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      if (_selectedIndex != index) {
        // Reset and forward animation for a nice transition
        _animationController.reverse(from: 1.0).then((_) {
          setState(() {
            _selectedIndex = index;
          });
          _animationController.forward();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final passengerUid = currentUser?.uid ?? '';

    return Scaffold(
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF0D1117), const Color(0xFF161B22)]
                : [const Color(0xFFF0F4F8), const Color(0xFFE2E8F0)],
          ),
        ),
        // Use Column inside SafeArea to stack the main content and the ad banner
        child: SafeArea(
          child: Column(
            children: [
              // Expanded Widget for Main Tab Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      // Index 0: Search Tab
                      _buildSearchTab(currentUser?.name ?? 'Passenger', authProvider, theme, isDark),

                      // Index 1: Upcoming Rides (Active Bookings only, filtered by ride status)
                      _buildUpcomingBookingsTab(passengerUid, theme, isDark),

                      // Index 2: Ride History (All Bookings)
                      _buildHistoryTab(passengerUid, theme, isDark),
                    ],
                  ),
                ),
              ),

              // Banner area (AdMob on mobile, test banner on web)
              _buildBottomBanner(isDark),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(theme, isDark),
    );
  }

  /// Builds the bottom banner section.
  /// - On mobile (non‑web): shows the real AdMob banner when loaded.
  /// - On web: shows a styled "Test Banner Ad (Web)" placeholder.
  Widget _buildBottomBanner(bool isDark) {
    // Web: show a simple test banner placeholder (since google_mobile_ads is mobile‑only)
    if (kIsWeb) {
      return Container(
        alignment: Alignment.center,
        width: double.infinity,
        height: 60,
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        child: Text(
          'Test Banner Ad (Web)',
          style: TextStyle(
            color: isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Mobile: only show when the AdMob banner is loaded
    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        child: AdWidget(ad: _bannerAd!),
      );
    }

    // No banner to show yet
    return const SizedBox.shrink();
  }

  Widget _buildBottomNavBar(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onTap,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: theme.colorScheme.primary,
          unselectedItemColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.search_rounded, size: 26),
              ),
              label: 'Find Rides',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.drive_eta_rounded, size: 26), // Changed to focus on upcoming rides
              ),
              label: 'Upcoming',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.history_rounded, size: 26), // New History icon
              ),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4.0),
                child: Icon(Icons.account_circle_rounded, size: 26),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  // --- Search Tab UI (Unchanged) ---
  Widget _buildSearchTab(String userName, AuthProvider authProvider, ThemeData theme, bool isDark) {
    // Note: Padding is left as is, ListView will scroll the content above the fixed banner ad.
    return ListView(
      padding: const EdgeInsets.only(bottom: 100), // Account for nav bar
      children: [
        // Modern Header
        _buildHeaderCard(userName, theme, isDark),

        // Search Section Title
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
          child: Text(
            'Ready to explore?',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),

        // Search CTA Card (Highly prominent)
        _buildSearchCtaCard(theme, isDark),

        // Benefits Section
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
          child: Text(
            'Why Choose RideShare?',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildBenefitCard(
                      icon: Icons.eco_rounded,
                      title: 'Eco-Friendly',
                      subtitle: 'Reduce your carbon footprint on every trip.',
                      color: Colors.green.shade500,
                      theme: theme,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBenefitCard(
                      icon: Icons.attach_money_rounded,
                      title: 'Cost Saving',
                      subtitle: 'Save money by splitting travel costs easily.',
                      color: Colors.orange.shade500,
                      theme: theme,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildBenefitCard(
                      icon: Icons.people_rounded,
                      title: 'Community',
                      subtitle: 'Connect with fellow commuters and travelers.',
                      color: Colors.purple.shade500,
                      theme: theme,
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildBenefitCard(
                      icon: Icons.shield_moon_rounded,
                      title: 'Verified Profiles',
                      subtitle: 'Travel with confidence and safety assured.',
                      color: Colors.blue.shade500,
                      theme: theme,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(String userName, ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 30,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello,',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'PASSENGER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCtaCard(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
            width: 1,
          ),
        ),
        shadowColor: isDark ? Colors.black.withOpacity(0.5) : Colors.grey.shade300.withOpacity(0.6),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchRidesScreen()),
            );
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.1),
                          theme.colorScheme.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.map_rounded,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Where are you headed?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SearchRidesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.search_rounded, size: 20),
                  label: const Text(
                    'Search for Rides Now',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    shadowColor: theme.colorScheme.primary.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required ThemeData theme,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 160, // Fixed height for visual consistency
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? const Color(0xFFAABBCF) : const Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- NEW Helper: Loading Booking Card (Placeholder for async check) ---
  Widget _buildLoadingBookingCard(ThemeData theme, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      height: 120, // Approximate height of a real card
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: LinearProgressIndicator(
          backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          color: theme.colorScheme.primary.withOpacity(0.5),
        ),
      ),
    );
  }

  // --- NEW Helper: Active Booking Card with Ride Status Check (The Fix) ---
  Widget _buildActiveBookingCard(BuildContext context, BookingModel booking, ThemeData theme, bool isDark) {
    // We fetch the latest RideModel status to override the possibly stale booking.status
    return FutureBuilder<RideModel?>(
      future: _rideService.getRideById(booking.rideId),
      builder: (context, rideSnapshot) {
        if (rideSnapshot.connectionState == ConnectionState.waiting) {
          // Show a lightweight placeholder while fetching the actual ride status
          return _buildLoadingBookingCard(theme, isDark);
        }

        final ride = rideSnapshot.data;

        // CRITICAL CHECK: Only show if the booking is confirmed AND the associated ride is active
        if (ride != null && ride.status == 'active' && booking.status == 'confirmed') {
          return _buildBookingCard(context, booking, theme, isDark);
        }

        // If the ride is cancelled, completed, or doesn't exist, hide the card.
        return const SizedBox.shrink();
      },
    );
  }

  // --- UPDATED: Upcoming Rides Tab (Index 1) ---
  Widget _buildUpcomingBookingsTab(String passengerId, ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Header
        _buildBookingsHeader(theme, isDark, 'Upcoming Rides', 'Your confirmed and active bookings.'),

        // Bookings List
        Expanded(
          child: StreamBuilder<List<BookingModel>>(
            stream: _rideService.getPassengerBookings(passengerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: theme.colorScheme.primary),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(theme, snapshot.error.toString());
              }

              // Pre-filter: We only bother checking rides that the user hasn't explicitly cancelled
              List<BookingModel> potentialBookings = snapshot.data?.where((b) => b.status == 'confirmed').toList() ?? [];

              if (potentialBookings.isEmpty) {
                return _buildEmptyBookingsState(theme, isDark, 'No active rides found.', 'Time to find a new adventure!');
              }

              // Sort by time, oldest first (next trip should be first)
              potentialBookings.sort((a, b) => a.bookingTime.compareTo(b.bookingTime));

              // Use FutureBuilder in the list to asynchronously filter out rides that are cancelled/completed
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Account for nav bar
                itemCount: potentialBookings.length,
                itemBuilder: (context, index) {
                  return _buildActiveBookingCard(context, potentialBookings[index], theme, isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- UPDATED: History Tab (Index 2) ---
  Widget _buildHistoryTab(String passengerId, ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Header
        _buildBookingsHeader(theme, isDark, 'Ride History', 'Review all your past, completed, and cancelled trips.'),

        // Bookings List
        Expanded(
          child: StreamBuilder<List<BookingModel>>(
            stream: _rideService.getPassengerBookings(passengerId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: theme.colorScheme.primary),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(theme, snapshot.error.toString());
              }

              List<BookingModel> allBookings = snapshot.data ?? [];

              // HISTORY FILTER: Show all bookings that are NOT confirmed (completed or cancelled)
              List<BookingModel> historyBookings = allBookings.where((b) => b.status != 'confirmed').toList();

              if (historyBookings.isEmpty) {
                return _buildEmptyBookingsState(theme, isDark, 'No ride history.', 'Complete your first trip to start tracking!');
              }

              // Sort by time, newest first
              historyBookings.sort((a, b) => b.bookingTime.compareTo(a.bookingTime));

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100), // Account for nav bar
                itemCount: historyBookings.length,
                itemBuilder: (context, index) {
                  return _buildBookingCard(context, historyBookings[index], theme, isDark);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Header now accepts dynamic title/subtitle ---
  Widget _buildBookingsHeader(ThemeData theme, bool isDark, String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.bookmark_rounded,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? const Color(0xFFAABBCF) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(BuildContext context, BookingModel booking, ThemeData theme, bool isDark) {
    // Note: The date format here assumes the bookingTime is the ride start time or close to it.
    final dateFormat = DateFormat('EEE, MMM dd • hh:mm a');

    // Determine status display based on booking status
    Color statusColor;
    String statusText;

    switch (booking.status) {
      case 'confirmed':
        statusColor = Colors.green.shade600;
        statusText = 'CONFIRMED';
        break;
      case 'completed':
        statusColor = Colors.blue.shade600;
        statusText = 'COMPLETED';
        break;
      case 'cancelled':
        statusColor = Colors.red.shade600;
        statusText = 'CANCELLED';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'PENDING';
    }


    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
          width: 1,
        ),
      ),
      shadowColor: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.shade300.withOpacity(0.6),
      child: InkWell(
        onTap: () {
          // You might want to refresh the list if the user cancels a ride on the details screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailsScreen(booking: booking),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status & Seats Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: statusColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.circle_rounded, size: 10, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.event_seat_rounded,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${booking.seatsBooked} seats',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 28, thickness: 1),

              // Ride Details (Date & Time)
              Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 20,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dateFormat.format(booking.bookingTime),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: isDark ? const Color(0xFFAABBCF) : Colors.grey.shade500,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Empty State now accepts dynamic messages ---
  Widget _buildEmptyBookingsState(ThemeData theme, bool isDark, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E293B)
                    : theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Icon(
                _selectedIndex == 1 ? Icons.event_available_rounded : Icons.mark_email_read_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? const Color(0xFFAABBCF) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),
            if (_selectedIndex != 0) // Show Search button if not already on the search tab
              ElevatedButton.icon(
                onPressed: () => _onTap(0),
                icon: const Icon(Icons.search_rounded, size: 20),
                label: const Text('Start Searching Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to Load Bookings',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'An error occurred: $error',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}