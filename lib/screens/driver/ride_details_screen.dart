import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ride_model.dart';
import '../../models/booking_model.dart';
import '../../services/ride_service.dart';

// Helper for status colors
Color getStatusColor(String status, ThemeData theme) {
  switch (status) {
    case 'completed':
      return Colors.green.shade700;
    case 'cancelled':
      return Colors.red.shade700;
    case 'active':
    default:
      return theme.primaryColor;
  }
}

class RideDetailsScreen extends StatefulWidget {
  final RideModel ride;

  const RideDetailsScreen({Key? key, required this.ride}) : super(key: key);

  @override
  State<RideDetailsScreen> createState() => _RideDetailsScreenState();
}

class _RideDetailsScreenState extends State<RideDetailsScreen> {
  final RideService _rideService = RideService();
  final dateFormat = DateFormat('EEE, MMM dd');
  final timeFormat = DateFormat('hh:mm a');

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // Remove any spaces, dashes, or parentheses from the phone number
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to launch phone dialer. Please dial $phoneNumber manually.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updateRideStatus(String status) async {
    try {
      await _rideService.updateRideStatus(widget.ride.rideId, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ride marked as $status'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Ride Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Mark as Completed'),
              onTap: () {
                Navigator.pop(context);
                _updateRideStatus('completed');
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.red),
              title: const Text('Cancel Ride'),
              onTap: () {
                Navigator.pop(context);
                _updateRideStatus('cancelled');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerColor = getStatusColor(widget.ride.status, theme);
    final statusLabel = widget.ride.status.toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Details'),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (widget.ride.status == 'active')
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
              tooltip: 'Update Status',
              onPressed: _showStatusDialog,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER: Status and Route Info ---
            _buildHeaderSection(theme, headerColor, statusLabel),

            // --- Metrics Section (Date, Time, Seats, Price) ---
            _buildMetricsGrid(theme),

            // --- Passengers List ---
            Padding(
              // *** MODIFIED to 10 for tighter spacing (10 bottom metric + 10 top passenger = ~20 gap) ***
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group_rounded, color: theme.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Booked Passengers',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 30, thickness: 1.5, color: Color(0xFFE0E0E0)), // Thicker divider

                  StreamBuilder<List<BookingModel>>(
                    stream: _rideService.getRideBookings(widget.ride.rideId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ));
                      }

                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text('Error loading passengers: ${snapshot.error}'),
                        );
                      }

                      List<BookingModel> bookings = snapshot.data ?? [];

                      if (bookings.isEmpty) {
                        return _buildNoPassengersState(theme);
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bookings.length,
                        itemBuilder: (context, index) {
                          return _buildPassengerCard(bookings[index], theme);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildHeaderSection(ThemeData theme, Color headerColor, String statusLabel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: headerColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: headerColor.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Label (Enhanced for clarity)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white54, width: 0.5),
            ),
            child: Text(
              statusLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Route Display (Origin to Destination)
          _buildRouteDisplay(theme),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(ThemeData theme) {
    return Padding(
      // *** MODIFIED to 10 for tighter spacing (10 bottom metric + 10 top passenger = ~20 gap) ***
      padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 10.0),
      child: GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.9, // Adjusted from 2.5 to 2.0 to give more vertical space
        children: [
          _buildMetricCard(
            context,
            label: 'DATE',
            value: dateFormat.format(widget.ride.dateTime),
            icon: Icons.calendar_today_rounded,
            color: Colors.blue.shade600,
          ),
          _buildMetricCard(
            context,
            label: 'TIME',
            value: timeFormat.format(widget.ride.dateTime),
            icon: Icons.access_time_rounded,
            color: Colors.orange.shade600,
          ),
          _buildMetricCard(
            context,
            label: 'SEATS LEFT',
            value: '${widget.ride.availableSeats} / ${widget.ride.totalSeats}',
            icon: Icons.event_seat_rounded,
            color: widget.ride.availableSeats > 0 ? Colors.green.shade600 : Colors.red.shade600,
            highlightValue: true,
          ),
          _buildMetricCard(
            context,
            label: 'PRICE / SEAT',
            value: 'PKR ${widget.ride.price.toStringAsFixed(0)}',
            icon: Icons.label_important_rounded, // Reverted icon
            color: Colors.purple.shade600,
            highlightValue: true,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
      BuildContext context, {
        required String label,
        required String value,
        required IconData icon,
        required Color color,
        bool highlightValue = false,
      }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16), // Increased radius
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08), // Heavier shadow for depth
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color.darken(0.2), // Darken label color slightly
                  letterSpacing: 0.8,
                ),
              ),
              Icon(icon, size: 20, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: highlightValue ? FontWeight.w900 : FontWeight.w700, // Heavier weight
              color: highlightValue ? color.darken(0.1) : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRouteDisplay(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Origin
        Row(
          children: [
            const Icon(Icons.circle, color: Colors.greenAccent, size: 16),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.ride.origin,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600, // Reduced weight from w700 to w600
                  fontSize: 19, // Slightly reduced size from 20 to 19
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Separator Line (Timeline style)
        Padding(
          padding: const EdgeInsets.only(left: 7.5),
          child: Container(
            width: 2, // Slightly thicker line
            height: 30,
            color: Colors.white54,
          ),
        ),
        // Destination
        Row(
          children: [
            const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                widget.ride.destination,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600, // Reduced weight from w700 to w600
                  fontSize: 19, // Slightly reduced size from 20 to 19
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNoPassengersState(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.person_search_rounded,
            size: 60,
            color: theme.colorScheme.onSurface.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No bookings yet!',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The ride is open for booking. Keep an eye out for new passengers.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // New helper function for cleaner detail rows inside passenger card
  Widget _buildDetailRow({required IconData icon, required String label, required String value, required Color iconColor, required ThemeData theme, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 8),
          Text(
            '$label:',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: valueStyle ?? theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: iconColor.darken(0.2),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerCard(BookingModel booking, ThemeData theme) {
    final String passengerFare = 'PKR ${booking.totalPrice.toStringAsFixed(0)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. Header (Name, Phone, Call Button) ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.primaryColor.withOpacity(0.1),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: theme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),

                // Name and Phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        booking.passengerName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                          fontSize: 18,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        booking.passengerPhone,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Call Button
                Tooltip(
                  message: 'Call ${booking.passengerName}',
                  child: IconButton(
                    onPressed: () => _makePhoneCall(booking.passengerPhone),
                    icon: const Icon(Icons.phone_rounded, size: 28),
                    color: theme.primaryColor,
                    style: IconButton.styleFrom(
                      backgroundColor: theme.primaryColor.withOpacity(0.15),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ),
              ],
            ),

            const Divider(height: 25, thickness: 1),

            // --- 2. Details Stack (Vertical Layout) ---

            // Seats Booked
            _buildDetailRow(
              icon: Icons.event_seat_rounded,
              label: 'Seats Booked',
              value: '${booking.seatsBooked}',
              iconColor: Colors.orange.shade700,
              theme: theme,
            ),

            // Total Fare
            _buildDetailRow(
              icon: Icons.label_important_rounded,
              label: 'Total Fare',
              value: passengerFare,
              iconColor: Colors.teal.shade700,
              theme: theme,
              valueStyle: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.teal.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to slightly darken a color for better contrast/depth
extension ColorManipulation on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}