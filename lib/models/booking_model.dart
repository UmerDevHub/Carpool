import 'package:cloud_firestore/cloud_firestore.dart';

/// A data model representing a passenger booking for a specific ride.
class BookingModel {
  final String bookingId;
  final String rideId;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final int seatsBooked;
  final double totalPrice; // The total fare for the number of seats booked
  final DateTime bookingTime;
  final String status; // 'confirmed', 'cancelled'

  BookingModel({
    required this.bookingId,
    required this.rideId,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.seatsBooked,
    required this.totalPrice, // New required field
    required this.bookingTime,
    this.status = 'confirmed',
  });

  /// Converts the BookingModel object into a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'rideId': rideId,
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'seatsBooked': seatsBooked,
      'totalPrice': totalPrice, // Added totalPrice
      'bookingTime': Timestamp.fromDate(bookingTime),
      'status': status,
    };
  }

  /// Creates a BookingModel object from a Firestore document Map.
  factory BookingModel.fromMap(Map<String, dynamic> map) {
    // Safely parse price, ensuring it's treated as a double.
    final rawPrice = map['totalPrice'] ?? 0.0;
    final parsedPrice = (rawPrice is num) ? rawPrice.toDouble() : 0.0;

    return BookingModel(
      bookingId: map['bookingId'] ?? '',
      rideId: map['rideId'] ?? '',
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      passengerPhone: map['passengerPhone'] ?? '',
      seatsBooked: map['seatsBooked'] ?? 1,
      totalPrice: parsedPrice, // Added totalPrice
      bookingTime: (map['bookingTime'] as Timestamp).toDate(),
      status: map['status'] ?? 'confirmed',
    );
  }

  /// Creates a copy of the BookingModel, optionally overriding fields.
  BookingModel copyWith({
    String? bookingId,
    String? rideId,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    int? seatsBooked,
    double? totalPrice, // Added totalPrice
    DateTime? bookingTime,
    String? status,
  }) {
    return BookingModel(
      bookingId: bookingId ?? this.bookingId,
      rideId: rideId ?? this.rideId,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      seatsBooked: seatsBooked ?? this.seatsBooked,
      totalPrice: totalPrice ?? this.totalPrice, // Updated copyWith
      bookingTime: bookingTime ?? this.bookingTime,
      status: status ?? this.status,
    );
  }
}