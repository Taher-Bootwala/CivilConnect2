enum AppRole { customer, professional }

enum BookingStatus {
  requested,
  dispatching,
  accepted,
  onTheWay,
  arrived,
  inProgress,
  workDone,
  quotePending,
  approved,
  disputed,
  paymentPending,
  paid,
  closed,
  rated,
  cancelled,
}

extension BookingStatusLabel on BookingStatus {
  String get label => switch (this) {
    BookingStatus.requested => 'Request sent',
    BookingStatus.dispatching => 'Finding a professional',
    BookingStatus.accepted => 'Professional confirmed',
    BookingStatus.onTheWay => 'On the way',
    BookingStatus.arrived => 'Arrived',
    BookingStatus.inProgress => 'Work in progress',
    BookingStatus.workDone => 'Work completed',
    BookingStatus.quotePending => 'Quote awaiting approval',
    BookingStatus.approved => 'Quote approved',
    BookingStatus.disputed => 'Under review',
    BookingStatus.paymentPending => 'Payment pending',
    BookingStatus.paid => 'Paid',
    BookingStatus.closed => 'Completed',
    BookingStatus.rated => 'Rated',
    BookingStatus.cancelled => 'Cancelled',
  };
}

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int color;
}

class Service {
  const Service({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.estimateMinPaise,
    required this.estimateMaxPaise,
    required this.icon,
  });

  final String id;
  final String categoryId;
  final String name;
  final String description;
  final int durationMinutes;
  final int estimateMinPaise;
  final int estimateMaxPaise;
  final String icon;

  String get estimateLabel =>
      '₹${estimateMinPaise ~/ 100} – ₹${estimateMaxPaise ~/ 100}';
}

class Professional {
  const Professional({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.reviewCount,
    required this.completedJobs,
    required this.distanceKm,
    required this.experience,
    required this.isVerified,
  });

  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int reviewCount;
  final int completedJobs;
  final double distanceKm;
  final String experience;
  final bool isVerified;
}

class GeoLocation {
  const GeoLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;
}

class Booking {
  const Booking({
    required this.id,
    required this.service,
    required this.status,
    required this.scheduledAt,
    required this.location,
    required this.description,
    this.professional,
    this.customerPayablePaise,
    this.quotePending = false,
  });

  final String id;
  final Service service;
  final BookingStatus status;
  final DateTime scheduledAt;
  final GeoLocation location;
  final String description;
  final Professional? professional;
  final int? customerPayablePaise;
  final bool quotePending;

  Booking copyWith({
    BookingStatus? status,
    Professional? professional,
    int? customerPayablePaise,
    bool? quotePending,
  }) => Booking(
    id: id,
    service: service,
    status: status ?? this.status,
    scheduledAt: scheduledAt,
    location: location,
    description: description,
    professional: professional ?? this.professional,
    customerPayablePaise: customerPayablePaise ?? this.customerPayablePaise,
    quotePending: quotePending ?? this.quotePending,
  );
}

class QuoteLine {
  const QuoteLine({
    required this.type,
    required this.description,
    required this.quantity,
    required this.unitAmountPaise,
  });

  final String type;
  final String description;
  final double quantity;
  final int unitAmountPaise;

  int get totalPaise => (quantity * unitAmountPaise).round();
}

class GoogleAuthProfile {
  const GoogleAuthProfile({
    required this.email,
    required this.firstName,
    required this.lastName,
    this.fullName,
    this.avatarUrl,
    this.idToken,
    this.accessToken,
  });

  final String email;
  final String firstName;
  final String lastName;
  final String? fullName;
  final String? avatarUrl;
  final String? idToken;
  final String? accessToken;

  String get displayName {
    if (fullName != null && fullName!.trim().isNotEmpty) {
      return fullName!.trim();
    }
    return ('$firstName $lastName').trim();
  }
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.location,
    required this.role,
    this.id = '',
    this.email = '',
    this.phone = '',
    this.gender = '',
    this.firstName = '',
    this.lastName = '',
    this.dateOfBirth,
    this.age,
  });

  final String id;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String gender;
  final DateTime? dateOfBirth;
  final int? age;
  final String location;
  final AppRole role;

  UserProfile copyWith({
    String? id,
    String? name,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? gender,
    DateTime? dateOfBirth,
    int? age,
    String? location,
    AppRole? role,
  }) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    firstName: firstName ?? this.firstName,
    lastName: lastName ?? this.lastName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    gender: gender ?? this.gender,
    dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    age: age ?? this.age,
    location: location ?? this.location,
    role: role ?? this.role,
  );
}

class PaymentOrder {
  const PaymentOrder({
    required this.paymentId,
    required this.orderId,
    required this.amountPaise,
    required this.publicKey,
  });

  final String paymentId;
  final String orderId;
  final int amountPaise;
  final String publicKey;

  bool get isDevelopment => orderId.startsWith('demo-');
}

int totalPaise(Iterable<QuoteLine> lines) =>
    lines.fold(0, (sum, line) => sum + line.totalPaise);
