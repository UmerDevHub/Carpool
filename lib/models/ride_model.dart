import 'package:cloud_firestore/cloud_firestore.dart';

/// A data model representing a ride offer in the application.
class RideModel {
  final String rideId;
  final String driverId;
  final String driverName;
  final String driverPhone;
  final String origin;
  final String destination;
  final DateTime dateTime;
  final double price; // The fare for the ride
  final int totalSeats;
  final int availableSeats;
  final String status; // 'active', 'completed', 'cancelled'

  RideModel({
    required this.rideId,
    required this.driverId,
    required this.driverName,
    required this.driverPhone,
    required this.origin,
    required this.destination,
    required this.dateTime,
    required this.price, // New required field
    required this.totalSeats,
    required this.availableSeats,
    this.status = 'active',
  });

  /// Converts the RideModel object into a Map for Firestore storage.
  Map<String, dynamic> toMap() {
    return {
      'rideId': rideId,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'origin': origin,
      'destination': destination,
      'dateTime': Timestamp.fromDate(dateTime),
      'price': price, // Added price
      'totalSeats': totalSeats,
      'availableSeats': availableSeats,
      'status': status,
    };
  }

  /// Creates a RideModel object from a Firestore document Map.
  factory RideModel.fromMap(Map<String, dynamic> map) {
    // Safely parse price, ensuring it's treated as a double.
    final rawPrice = map['price'] ?? 0.0;
    final parsedPrice = (rawPrice is num) ? rawPrice.toDouble() : 0.0;

    return RideModel(
      rideId: map['rideId'] ?? '',
      driverId: map['driverId'] ?? '',
      driverName: map['driverName'] ?? '',
      driverPhone: map['driverPhone'] ?? '',
      origin: map['origin'] ?? '',
      destination: map['destination'] ?? '',
      dateTime: (map['dateTime'] as Timestamp).toDate(),
      price: parsedPrice, // Added price
      totalSeats: map['totalSeats'] ?? 0,
      availableSeats: map['availableSeats'] ?? 0,
      status: map['status'] ?? 'active',
    );
  }

  /// Creates a copy of the RideModel, optionally overriding fields.
  RideModel copyWith({
    String? rideId,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? origin,
    String? destination,
    DateTime? dateTime,
    double? price, // Added price
    int? totalSeats,
    int? availableSeats,
    String? status,
  }) {
    return RideModel(
      rideId: rideId ?? this.rideId,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      dateTime: dateTime ?? this.dateTime,
      price: price ?? this.price, // Updated copyWith
      totalSeats: totalSeats ?? this.totalSeats,
      availableSeats: availableSeats ?? this.availableSeats,
      status: status ?? this.status,
    );
  }
}