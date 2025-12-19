import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_model.dart';
import '../models/booking_model.dart';

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new ride
  Future<String> createRide(RideModel ride) async {
    try {
      // NOTE: Using a 'rides' collection path for public artifacts
      DocumentReference docRef = await _firestore.collection('rides').add(ride.toMap());
      await docRef.update({'rideId': docRef.id});
      return docRef.id;
    } catch (e) {
      print('Create ride error: $e');
      rethrow;
    }
  }

  // Get rides by driver
  Stream<List<RideModel>> getDriverRides(String driverId) {
    return _firestore
        .collection('rides')
        .where('driverId', isEqualTo: driverId)
        .orderBy('dateTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => RideModel.fromMap(doc.data()))
        .toList());
  }

  // Search available rides - FIXED to work with indexes
  Stream<List<RideModel>> searchRides({
    String? origin,
    String? destination,
    DateTime? date,
  }) {
    Query query = _firestore.collection('rides');

    // Build query based on what parameters are provided
    if (origin != null && origin.isNotEmpty && destination != null && destination.isNotEmpty) {
      // Both origin and destination provided - Uses Index #4
      query = query
          .where('origin', isEqualTo: origin)
          .where('destination', isEqualTo: destination)
          .where('status', isEqualTo: 'active')
          .where('availableSeats', isGreaterThan: 0)
          .orderBy('availableSeats')
          .orderBy('dateTime');
    } else if (origin != null && origin.isNotEmpty) {
      // Only origin provided - Uses Index #2
      query = query
          .where('origin', isEqualTo: origin)
          .where('status', isEqualTo: 'active')
          .where('availableSeats', isGreaterThan: 0)
          .orderBy('availableSeats')
          .orderBy('dateTime');
    } else if (destination != null && destination.isNotEmpty) {
      // Only destination provided - Uses Index #3
      query = query
          .where('destination', isEqualTo: destination)
          .where('status', isEqualTo: 'active')
          .where('availableSeats', isGreaterThan: 0)
          .orderBy('availableSeats')
          .orderBy('dateTime');
    } else {
      // No location filters - Uses Index #1
      query = query
          .where('status', isEqualTo: 'active')
          .where('availableSeats', isGreaterThan: 0)
          .orderBy('availableSeats')
          .orderBy('dateTime');
    }

    return query.snapshots().map((snapshot) {
      List<RideModel> rides = snapshot.docs
          .map((doc) => RideModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Client-side date filtering (since Firestore can't do range on multiple fields)
      if (date != null) {
        rides = rides.where((ride) {
          return ride.dateTime.year == date.year &&
              ride.dateTime.month == date.month &&
              ride.dateTime.day == date.day;
        }).toList();
      }

      return rides;
    });
  }

  // =======================================================
  // Check for active booking (Required for double-booking prevention)
  // =======================================================

  /// Checks if a passenger already has a confirmed booking (status='confirmed')
  /// for a specific ride. Used to enforce the one-booking-per-ride rule.
  Future<bool> checkExistingBooking(String rideId, String passengerId) async {
    try {
      final bookingsRef = _firestore.collection('bookings');

      // Query for a booking that matches the rideId, passengerId, AND is still 'confirmed' (active)
      final snapshot = await bookingsRef
          .where('rideId', isEqualTo: rideId)
          .where('passengerId', isEqualTo: passengerId)
          .where('status', isEqualTo: 'confirmed')
          .limit(1)
          .get();

      // If the snapshot has any documents, an active booking already exists.
      return snapshot.docs.isNotEmpty;

    } catch (e) {
      print('RideService Error checking existing booking: $e');
      return false;
    }
  }


  // Book a ride
  Future<void> bookRide({
    required String rideId,
    required String passengerId,
    required String passengerName,
    required String passengerPhone,
    int seatsToBook = 1,
  }) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference rideRef = _firestore.collection('rides').doc(rideId);
        DocumentSnapshot rideSnapshot = await transaction.get(rideRef);

        if (!rideSnapshot.exists) {
          throw Exception('Ride not found');
        }

        RideModel ride = RideModel.fromMap(
            rideSnapshot.data() as Map<String, dynamic>);

        if (ride.availableSeats < seatsToBook) {
          throw Exception('Not enough seats available');
        }

        // --- NEW LOGIC: Calculate Total Price ---
        final double totalPrice = ride.price * seatsToBook;


        // Update available seats
        transaction.update(rideRef, {
          'availableSeats': ride.availableSeats - seatsToBook,
        });

        // Create booking
        BookingModel booking = BookingModel(
          bookingId: '',
          rideId: rideId,
          passengerId: passengerId,
          passengerName: passengerName,
          passengerPhone: passengerPhone,
          seatsBooked: seatsToBook,
          totalPrice: totalPrice, // Pass the calculated total price
          bookingTime: DateTime.now(),
          status: 'confirmed', // Initialize status as confirmed
        );

        DocumentReference bookingRef = _firestore.collection('bookings').doc();
        transaction.set(bookingRef, booking.toMap());
        transaction.update(bookingRef, {'bookingId': bookingRef.id});
      });
    } catch (e) {
      print('Book ride error: $e');
      rethrow;
    }
  }

  // Get bookings for a ride (for drivers)
  Stream<List<BookingModel>> getRideBookings(String rideId) {
    return _firestore
        .collection('bookings')
        .where('rideId', isEqualTo: rideId)
        .where('status', isEqualTo: 'confirmed')
        .orderBy('bookingTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BookingModel.fromMap(doc.data()))
        .toList());
  }

  // Get passenger bookings
  Stream<List<BookingModel>> getPassengerBookings(String passengerId) {
    return _firestore
        .collection('bookings')
        .where('passengerId', isEqualTo: passengerId)
        .orderBy('bookingTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BookingModel.fromMap(doc.data()))
        .toList());
  }

  // Get ride by ID
  Future<RideModel?> getRideById(String rideId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('rides').doc(rideId).get();
      if (doc.exists) {
        return RideModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Get ride error: $e');
      return null;
    }
  }

  // Update ride status
  Future<void> updateRideStatus(String rideId, String status) async {
    try {
      await _firestore.collection('rides').doc(rideId).update({
        'status': status,
      });
    } catch (e) {
      print('Update ride status error: $e');
      rethrow;
    }
  }

  // Cancel booking
  Future<void> cancelBooking(String bookingId, String rideId, int seatsBooked) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference bookingRef = _firestore.collection('bookings').doc(bookingId);
        DocumentReference rideRef = _firestore.collection('rides').doc(rideId);

        DocumentSnapshot rideSnapshot = await transaction.get(rideRef);
        if (rideSnapshot.exists) {
          RideModel ride = RideModel.fromMap(
              rideSnapshot.data() as Map<String, dynamic>);

          transaction.update(rideRef, {
            'availableSeats': ride.availableSeats + seatsBooked,
          });
        }

        // Set status to cancelled
        transaction.update(bookingRef, {'status': 'cancelled'});
      });
    } catch (e) {
      print('Cancel booking error: $e');
      rethrow;
    }
  }
}