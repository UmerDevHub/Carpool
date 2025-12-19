import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/booking_model.dart';
import '../../models/ride_model.dart';
import '../../services/ride_service.dart';

class BookingDetailsScreen extends StatefulWidget {
  final BookingModel booking;

  const BookingDetailsScreen({Key? key, required this.booking}) : super(key: key);

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final RideService _rideService = RideService();
  RideModel? _ride;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRideDetails();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadRideDetails() async {
    try {
      final ride = await _rideService.getRideById(widget.booking.rideId);
      if (mounted) {
        setState(() {
          _ride = ride;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('Error loading ride details: Ride may be removed or cancelled.', Colors.red);
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      // Remove any spaces, dashes, or parentheses from the phone number
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);

      // Try to launch directly without checking canLaunchUrl
      await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Unable to launch phone dialer. Please dial $phoneNumber manually.', Colors.orange);
      }
    }
  }

  Future<void> _cancelBooking() async {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking? This action cannot be undone.'),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keep Booking', style: TextStyle(color: theme.colorScheme.primary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              try {
                await _rideService.cancelBooking(
                  widget.booking.bookingId,
                  widget.booking.rideId,
                  widget.booking.seatsBooked,
                );

                if (mounted) {
                  _showSnackBar('Booking cancelled successfully', Colors.green);
                  // Return true to the previous screen (PassengerDashboard) indicating a change occurred
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) {
                  _showSnackBar('Error cancelling booking: $e', Colors.red);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    if (_ride == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking Details')),
        body: const Center(
          child: Text('Ride details could not be loaded.'),
        ),
      );
    }

    final dateFormat = DateFormat('EEEE, MMM dd, yyyy');
    final timeFormat = DateFormat('hh:mm a');
    final bookingDateFormat = DateFormat('MMM dd, yyyy - hh:mm a');

    final bool isRideActive = _ride!.status == 'active';
    final bool isCancellable = widget.booking.status == 'confirmed' && isRideActive;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_ride!.status == 'cancelled') {
      statusColor = Colors.red.shade600;
      statusText = 'Ride Cancelled by Driver';
      statusIcon = Icons.report_problem_rounded;
    } else if (_ride!.status == 'completed') {
      statusColor = Colors.blue.shade600;
      statusText = 'Ride Completed Successfully';
      statusIcon = Icons.done_all_rounded;
    } else if (widget.booking.status == 'cancelled') {
      statusColor = Colors.red.shade600;
      statusText = 'Booking Cancelled (by Passenger)';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = Colors.green.shade600;
      statusText = 'Booking Confirmed (Ride is Active)';
      statusIcon = Icons.check_circle_rounded;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(theme, statusColor, statusIcon, statusText, bookingDateFormat),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(theme, 'Route Overview', Icons.route_rounded),
                  const SizedBox(height: 16),
                  _buildRouteCard(theme, _ride!.origin, _ride!.destination),

                  const SizedBox(height: 32),

                  _buildSectionTitle(theme, 'Booking Summary', Icons.calendar_month_rounded),
                  const SizedBox(height: 16),
                  // Pass price data to the summary card
                  _buildSummaryCard(
                    theme,
                    dateFormat,
                    timeFormat,
                    _ride!.dateTime,
                    widget.booking.seatsBooked,
                    widget.booking.totalPrice,
                  ),

                  const SizedBox(height: 32),

                  _buildSectionTitle(theme, 'Driver Details', Icons.person_pin_circle_rounded),
                  const SizedBox(height: 16),
                  _buildDriverCard(theme, _ride!.driverName, _ride!.driverPhone, theme.brightness == Brightness.dark),

                  const SizedBox(height: 40),

                  if (isCancellable)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _cancelBooking,
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancel Booking'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade200, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHeader(ThemeData theme, Color statusColor, IconData statusIcon, String statusText, DateFormat bookingDateFormat) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Booked on ${bookingDateFormat.format(widget.booking.bookingTime)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                // Display Total Fare prominently
                _buildPriceDetail(theme, widget.booking.totalPrice),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Updated helper widget to display the total fare (PKR), removing dollar icon
  Widget _buildPriceDetail(ThemeData theme, double price) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade400,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Changed Icon from monetization to label_important
          const Icon(Icons.label_important_rounded, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            'Total Fare: PKR ${price.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRouteCard(ThemeData theme, String origin, String destination) {
    final isDark = theme.brightness == Brightness.dark;

    Widget _buildLocationItem({
      required String title,
      required String label,
      required Color color,
      required bool isEnd,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withOpacity(0.5), width: 2),
                    ),
                  ),
                  if (!isEnd)
                    Container(
                      height: 40,
                      width: 2,
                      color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: theme.colorScheme.primary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            _buildLocationItem(
              title: origin,
              label: 'Departure Point',
              color: Colors.green.shade500,
              isEnd: false,
            ),
            const SizedBox(height: 8),
            _buildLocationItem(
              title: destination,
              label: 'Arrival Destination',
              color: Colors.red.shade500,
              isEnd: true,
            ),
          ],
        ),
      ),
    );
  }

  // Updated _buildSummaryCard to use 'Total Fare' and PKR, and reorganize for better layout
  Widget _buildSummaryCard(ThemeData theme, DateFormat dateFormat, DateFormat timeFormat, DateTime dateTime, int seatsBooked, double totalPrice) {
    final isDark = theme.brightness == Brightness.dark;

    Widget _buildDetailItem({required IconData icon, required String label, required String value, required Color color, TextStyle? valueStyle, bool compact = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: compact ? 16 : 18, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: valueStyle ?? theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: theme.colorScheme.secondary.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column( // Main Column for two rows
          children: [
            // Row 1: Date and Time
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.calendar_today_rounded,
                      label: 'Date',
                      value: dateFormat.format(dateTime),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  VerticalDivider(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    thickness: 1,
                    width: 30,
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.access_time_filled_rounded,
                      label: 'Time',
                      value: timeFormat.format(dateTime),
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            Divider(height: 30, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),

            // Row 2: Seats and Total Fare
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.event_seat_rounded,
                      label: 'Seats',
                      value: '$seatsBooked',
                      color: Colors.orange.shade600,
                    ),
                  ),
                  VerticalDivider(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                    thickness: 1,
                    width: 30,
                  ),
                  Expanded(
                    child: _buildDetailItem(
                      icon: Icons.label_important_rounded, // Changed icon from monetization to label_important
                      label: 'Total Fare',
                      value: 'PKR ${totalPrice.toStringAsFixed(2)}',
                      color: Colors.teal.shade600,
                      valueStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverCard(ThemeData theme, String driverName, String driverPhone, bool isDark) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: theme.colorScheme.primary.withOpacity(0.15),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Icon(
                Icons.person_rounded,
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
                    driverName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    driverPhone,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => _makePhoneCall(driverPhone),
              icon: const Icon(Icons.phone_rounded, size: 22),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}