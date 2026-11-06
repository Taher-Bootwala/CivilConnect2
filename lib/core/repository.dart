import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

abstract interface class MarketplaceRepository {
  Future<UserProfile?> currentProfile();
  Future<UserProfile> signIn({required String email, required String password});
  Future<GoogleAuthProfile?> signInWithGoogle();
  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required AppRole role,
    String gender = '',
    String firstName = '',
    String lastName = '',
    DateTime? dateOfBirth,
    int? age,
  });
  Future<void> signOut();
  Stream<UserProfile?> get authStateChanges;
  Future<List<ServiceCategory>> categories();
  Future<List<Service>> services({String query = ''});
  Future<List<Professional>> nearbyProfessionals({
    required Service service,
    required GeoLocation location,
    required DateTime start,
    required DateTime end,
  });
  Future<List<Booking>> bookings();
  Future<Booking> createBooking({
    required Service service,
    required DateTime start,
    required DateTime end,
    required String description,
    required GeoLocation location,
    required bool automaticMatch,
    Professional? professional,
  });
  Future<Booking> transitionBooking(String bookingId, BookingStatus status);
  Future<Booking> submitQuote(String bookingId, List<QuoteLine> lines);
  Future<Booking> approveQuote(String bookingId);
  Future<PaymentOrder> createPaymentOrder(String bookingId);
  Future<void> verifyPayment({
    required PaymentOrder order,
    required String providerPaymentId,
    required String signature,
  });
  Future<void> recordCashCollection(
    String bookingId, {
    required int amountPaise,
  });
  Future<Map<String, int>> financialSummary();
}

class DemoMarketplaceRepository implements MarketplaceRepository {
  DemoMarketplaceRepository({this.mockGoogleProfile})
      : _bookings = <Booking>[],
        _authStreamController = StreamController<UserProfile?>.broadcast();

  final GoogleAuthProfile? mockGoogleProfile;
  final List<Booking> _bookings;
  final StreamController<UserProfile?> _authStreamController;
  UserProfile? _currentUser;

  @override
  Stream<UserProfile?> get authStateChanges => _authStreamController.stream;

  @override
  Future<UserProfile?> currentProfile() async => _currentUser;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw ArgumentError('Email cannot be empty.');
    }
    if (password.length < 4) {
      throw ArgumentError('Password is too short.');
    }
    final isPro = trimmedEmail.toLowerCase().contains('pro') ||
        trimmedEmail.toLowerCase().contains('partner') ||
        trimmedEmail.toLowerCase().contains('rohan');
    final rawName = trimmedEmail.split('@').first;
    final name = rawName.isNotEmpty
        ? rawName[0].toUpperCase() + rawName.substring(1)
        : (isPro ? 'Rohan Sharma' : 'Aarav Patel');

    final user = UserProfile(
      id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: trimmedEmail,
      phone: '+91 98765 43210',
      location: 'Indiranagar, Bengaluru',
      role: isPro ? AppRole.professional : AppRole.customer,
    );
    _currentUser = user;
    _authStreamController.add(user);
    return user;
  }

  @override
  Future<GoogleAuthProfile?> signInWithGoogle() async {
    if (mockGoogleProfile != null) {
      return mockGoogleProfile;
    }
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      // Ensure previous session is cleared so device account picker is always shown
      await googleSignIn.signOut().catchError((_) => null);
      final account = await googleSignIn.signIn();
      if (account == null) {
        return null; // User cancelled account chooser
      }

      final fullName = account.displayName ?? '';
      final parts = fullName.trim().split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      return GoogleAuthProfile(
        email: account.email,
        firstName: firstName,
        lastName: lastName,
        fullName: fullName,
        avatarUrl: account.photoUrl,
      );
    } catch (_) {
      // In environment without Google Play Services (e.g. desktop/unit tests)
      return null;
    }
  }

  @override
  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required AppRole role,
    String gender = '',
    String firstName = '',
    String lastName = '',
    DateTime? dateOfBirth,
    int? age,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim();
    if (trimmedName.isEmpty) throw ArgumentError('Full name is required.');
    if (trimmedEmail.isEmpty) throw ArgumentError('Email is required.');
    if (password.length < 6) {
      throw ArgumentError('Password must be at least 6 characters.');
    }

    final user = UserProfile(
      id: 'usr-${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      firstName: firstName,
      lastName: lastName,
      email: trimmedEmail,
      phone: phone.trim().isEmpty ? '+91 98765 43210' : phone.trim(),
      gender: gender,
      dateOfBirth: dateOfBirth,
      age: age,
      location: 'Bengaluru, India',
      role: role,
    );
    _currentUser = user;
    _authStreamController.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _authStreamController.add(null);
  }

  static const _categories = [
    ServiceCategory(
      id: 'plumbing',
      name: 'Plumbing',
      description: 'Fix leaks, taps and pipes',
      icon: 'water_drop',
      color: 0xFF2F80ED,
    ),
    ServiceCategory(
      id: 'electrical',
      name: 'Electrical',
      description: 'Safe electrical repairs',
      icon: 'bolt',
      color: 0xFFF2A900,
    ),
    ServiceCategory(
      id: 'cleaning',
      name: 'Cleaning',
      description: 'A fresher home, fast',
      icon: 'cleaning_services',
      color: 0xFF27AE60,
    ),
    ServiceCategory(
      id: 'carpentry',
      name: 'Carpentry',
      description: 'Furniture and fittings',
      icon: 'chair',
      color: 0xFFB66A38,
    ),
    ServiceCategory(
      id: 'painting',
      name: 'Painting',
      description: 'Brighten your space',
      icon: 'format_paint',
      color: 0xFF9B51E0,
    ),
    ServiceCategory(
      id: 'ac-maintenance',
      name: 'AC care',
      description: 'Cooler, cleaner air',
      icon: 'ac_unit',
      color: 0xFF00A6A6,
    ),
  ];

  static const _services = [
    Service(
      id: 'tap-repair',
      categoryId: 'plumbing',
      name: 'Tap repair',
      description: 'Fix leaking taps, faucets and fittings.',
      durationMinutes: 60,
      estimateMinPaise: 15000,
      estimateMaxPaise: 60000,
      icon: 'water_drop',
    ),
    Service(
      id: 'drainage-repair',
      categoryId: 'plumbing',
      name: 'Drainage repair',
      description: 'Unblock and repair common drainage issues.',
      durationMinutes: 90,
      estimateMinPaise: 25000,
      estimateMaxPaise: 120000,
      icon: 'plumbing',
    ),
    Service(
      id: 'switch-socket-repair',
      categoryId: 'electrical',
      name: 'Switch & socket repair',
      description: 'Replace switches, sockets and minor wiring.',
      durationMinutes: 60,
      estimateMinPaise: 15000,
      estimateMaxPaise: 80000,
      icon: 'power',
    ),
    Service(
      id: 'fan-installation',
      categoryId: 'electrical',
      name: 'Fan installation',
      description: 'Install or replace ceiling and exhaust fans.',
      durationMinutes: 90,
      estimateMinPaise: 25000,
      estimateMaxPaise: 100000,
      icon: 'toys',
    ),
    Service(
      id: 'home-deep-cleaning',
      categoryId: 'cleaning',
      name: 'Home deep cleaning',
      description: 'A detailed reset for rooms and kitchens.',
      durationMinutes: 180,
      estimateMinPaise: 80000,
      estimateMaxPaise: 350000,
      icon: 'cleaning_services',
    ),
    Service(
      id: 'furniture-repair',
      categoryId: 'carpentry',
      name: 'Furniture repair',
      description: 'Repair and adjust everyday furniture.',
      durationMinutes: 120,
      estimateMinPaise: 30000,
      estimateMaxPaise: 200000,
      icon: 'chair',
    ),
    Service(
      id: 'wall-touch-up',
      categoryId: 'painting',
      name: 'Wall touch-up',
      description: 'Refresh small areas with clean paintwork.',
      durationMinutes: 120,
      estimateMinPaise: 50000,
      estimateMaxPaise: 250000,
      icon: 'format_paint',
    ),
    Service(
      id: 'ac-service',
      categoryId: 'ac-maintenance',
      name: 'AC service',
      description: 'Routine AC cleaning and maintenance.',
      durationMinutes: 90,
      estimateMinPaise: 35000,
      estimateMaxPaise: 180000,
      icon: 'ac_unit',
    ),
  ];


  @override
  Future<List<ServiceCategory>> categories() async => _categories;

  @override
  Future<List<Service>> services({String query = ''}) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return _services;
    return _services
        .where(
          (service) =>
              service.name.toLowerCase().contains(normalized) ||
              service.description.toLowerCase().contains(normalized),
        )
        .toList();
  }

  @override
  Future<List<Professional>> nearbyProfessionals({
    required Service service,
    required GeoLocation location,
    required DateTime start,
    required DateTime end,
  }) async => const [
    Professional(
      id: 'prof-1',
      name: 'Rohan Sharma',
      specialty: 'Verified plumbing specialist',
      rating: 4.9,
      reviewCount: 184,
      completedJobs: 312,
      distanceKm: 1.2,
      experience: '8 years experience',
      isVerified: true,
    ),
    Professional(
      id: 'prof-2',
      name: 'Vikram HomeCare',
      specialty: 'Home maintenance expert',
      rating: 4.8,
      reviewCount: 97,
      completedJobs: 198,
      distanceKm: 2.4,
      experience: '6 years experience',
      isVerified: true,
    ),
    Professional(
      id: 'prof-3',
      name: 'Suresh Kumar',
      specialty: 'Fast, reliable repairs',
      rating: 4.7,
      reviewCount: 62,
      completedJobs: 126,
      distanceKm: 3.1,
      experience: '5 years experience',
      isVerified: true,
    ),
  ];

  @override
  Future<List<Booking>> bookings() async => List.unmodifiable(_bookings);

  @override
  Future<Booking> createBooking({
    required Service service,
    required DateTime start,
    required DateTime end,
    required String description,
    required GeoLocation location,
    required bool automaticMatch,
    Professional? professional,
  }) async {
    final booking = Booking(
      id: 'CC-${DateTime.now().millisecondsSinceEpoch}',
      service: service,
      status: automaticMatch
          ? BookingStatus.dispatching
          : BookingStatus.requested,
      scheduledAt: start,
      location: location,
      description: description,
      professional: professional,
    );
    _bookings.insert(0, booking);
    return booking;
  }

  @override
  Future<Booking> transitionBooking(
    String bookingId,
    BookingStatus status,
  ) async {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index < 0) throw StateError('Booking not found');
    final updated = _bookings[index].copyWith(
      status: status,
      quotePending: status == BookingStatus.quotePending,
    );
    _bookings[index] = updated;
    return updated;
  }

  @override
  Future<Booking> submitQuote(String bookingId, List<QuoteLine> lines) async {
    final index = _bookings.indexWhere((booking) => booking.id == bookingId);
    if (index < 0) throw StateError('Booking not found');
    final updated = _bookings[index].copyWith(
      status: BookingStatus.quotePending,
      quotePending: true,
      customerPayablePaise: totalPaise(lines),
    );
    _bookings[index] = updated;
    return updated;
  }

  @override
  Future<Booking> approveQuote(String bookingId) async =>
      transitionBooking(bookingId, BookingStatus.approved);

  @override
  Future<PaymentOrder> createPaymentOrder(String bookingId) async =>
      PaymentOrder(
        paymentId: 'demo-payment-$bookingId',
        orderId: 'demo-order-$bookingId',
        amountPaise: 0,
        publicKey: 'demo',
      );

  @override
  Future<void> verifyPayment({
    required PaymentOrder order,
    required String providerPaymentId,
    required String signature,
  }) async {}

  @override
  Future<void> recordCashCollection(
    String bookingId, {
    required int amountPaise,
  }) async {
    await transitionBooking(bookingId, BookingStatus.paid);
  }

  @override
  Future<Map<String, int>> financialSummary() async => {
    'cashEarnings': 18450,
    'onlineEarnings': 32800,
    'outstandingDues': 4200,
    'withdrawable': 28600,
  };
}

class SupabaseMarketplaceRepository implements MarketplaceRepository {
  SupabaseMarketplaceRepository(this._client)
      : _authStreamController = StreamController<UserProfile?>.broadcast() {
    _client.auth.onAuthStateChange.listen((data) async {
      final user = data.session?.user;
      if (user == null) {
        _authStreamController.add(null);
      } else {
        final profile = await currentProfile();
        _authStreamController.add(profile);
      }
    });
  }

  final SupabaseClient _client;
  final StreamController<UserProfile?> _authStreamController;

  @override
  Stream<UserProfile?> get authStateChanges => _authStreamController.stream;

  @override
  Future<UserProfile?> currentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data =
          await _invoke('profile', method: 'GET') as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>;
      return UserProfile(
        id: user.id,
        name: (profile['full_name'] as String?) ?? 'User',
        firstName: (profile['first_name'] as String?) ?? '',
        lastName: (profile['last_name'] as String?) ?? '',
        email: user.email ?? '',
        phone: (profile['phone'] as String?) ?? '',
        gender: (profile['gender'] as String?) ?? '',
        dateOfBirth: profile['date_of_birth'] != null
            ? DateTime.tryParse(profile['date_of_birth'].toString())
            : null,
        age: profile['age'] is int ? profile['age'] as int : null,
        location: 'Bengaluru, India',
        role: profile['primary_role'] == 'professional'
            ? AppRole.professional
            : AppRole.customer,
      );
    } catch (_) {
      final meta = user.userMetadata ?? {};
      final full = (meta['full_name'] as String?) ??
          user.email?.split('@').first ??
          'User';
      return UserProfile(
        id: user.id,
        name: full,
        firstName: (meta['first_name'] as String?) ?? full.split(' ').first,
        lastName: (meta['last_name'] as String?) ?? '',
        email: user.email ?? '',
        phone: (meta['phone'] as String?) ?? '',
        gender: (meta['gender'] as String?) ?? '',
        dateOfBirth: meta['date_of_birth'] != null
            ? DateTime.tryParse(meta['date_of_birth'].toString())
            : null,
        age: meta['age'] is int ? meta['age'] as int : null,
        location: 'Bengaluru, India',
        role: meta['primary_role'] == 'professional'
            ? AppRole.professional
            : AppRole.customer,
      );
    }
  }

  @override
  Future<GoogleAuthProfile?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      // Ensure previous session is cleared so device account picker is always shown
      await googleSignIn.signOut().catchError((_) => null);
      final account = await googleSignIn.signIn();
      if (account == null) {
        return null; // User cancelled account chooser
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;

      if (idToken != null) {
        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
      }

      final fullName = account.displayName ?? '';
      final parts = fullName.trim().split(' ');
      final firstName = parts.isNotEmpty ? parts.first : '';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      return GoogleAuthProfile(
        email: account.email,
        firstName: firstName,
        lastName: lastName,
        fullName: fullName,
        avatarUrl: account.photoUrl,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (_) {
      // Fallback to web OAuth if native Google Play Services is missing
      try {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.civilconnect://login-callback',
          queryParams: {'prompt': 'select_account'},
        );
        final user = _client.auth.currentUser;
        if (user != null) {
          final meta = user.userMetadata ?? {};
          final full = (meta['full_name'] as String?) ?? (meta['name'] as String?) ?? '';
          final given = (meta['given_name'] as String?) ?? (full.isNotEmpty ? full.split(' ').first : '');
          final family = (meta['family_name'] as String?) ?? (full.split(' ').length > 1 ? full.split(' ').sublist(1).join(' ') : '');
          return GoogleAuthProfile(
            email: user.email ?? '',
            firstName: given,
            lastName: family,
            fullName: full,
            avatarUrl: meta['avatar_url'] as String?,
          );
        }
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = res.user;
    if (user == null) {
      throw StateError('Invalid email or password.');
    }
    final profile = await currentProfile();
    return profile ??
        UserProfile(
          id: user.id,
          name: email.split('@').first,
          email: email,
          phone: '',
          gender: '',
          location: 'Bengaluru, India',
          role: AppRole.customer,
        );
  }

  @override
  Future<UserProfile> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    required AppRole role,
    String gender = '',
    String firstName = '',
    String lastName = '',
    DateTime? dateOfBirth,
    int? age,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': name,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'gender': gender,
        'date_of_birth': dateOfBirth?.toIso8601String().split('T').first,
        'age': age,
        'primary_role':
            role == AppRole.professional ? 'professional' : 'customer',
      },
    );
    final user = res.user;
    if (user == null) {
      throw StateError('Registration failed. Please try again.');
    }
    return UserProfile(
      id: user.id,
      name: name,
      firstName: firstName,
      lastName: lastName,
      email: email,
      phone: phone,
      gender: gender,
      dateOfBirth: dateOfBirth,
      age: age,
      location: 'Bengaluru, India',
      role: role,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _authStreamController.add(null);
  }

  Future<dynamic> _invoke(
    String function, {
    String method = 'POST',
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final response = await _client.functions.invoke(
      function,
      method: method == 'GET' ? HttpMethod.get : HttpMethod.post,
      body: body,
      headers: idempotencyKey == null
          ? null
          : {'Idempotency-Key': idempotencyKey},
    );
    if (response.status >= 400) {
      throw StateError('Request failed (${response.status})');
    }
    return response.data;
  }


  @override
  Future<List<ServiceCategory>> categories() async {
    final data =
        await _invoke('service-discovery', method: 'GET')
            as Map<String, dynamic>;
    return (data['categories'] as List<dynamic>)
        .map(
          (item) => ServiceCategory(
            id: item['id'] as String,
            name: item['name'] as String,
            description: item['description'] as String? ?? '',
            icon: item['icon_name'] as String? ?? 'home_repair_service',
            color: 0xFF2F80ED,
          ),
        )
        .toList();
  }

  @override
  Future<List<Service>> services({String query = ''}) async {
    final data =
        await _invoke(
              'service-discovery?q=${Uri.encodeQueryComponent(query)}',
              method: 'GET',
            )
            as Map<String, dynamic>;
    return (data['services'] as List<dynamic>)
        .map(
          (item) => Service(
            id: item['id'] as String,
            categoryId: item['category_id'] as String,
            name: item['name'] as String,
            description: item['description'] as String? ?? '',
            durationMinutes: item['typical_duration_minutes'] as int,
            estimateMinPaise: item['estimate_min_paise'] as int,
            estimateMaxPaise: item['estimate_max_paise'] as int,
            icon: 'home_repair_service',
          ),
        )
        .toList();
  }

  @override
  Future<List<Professional>> nearbyProfessionals({
    required Service service,
    required GeoLocation location,
    required DateTime start,
    required DateTime end,
  }) async {
    final data =
        await _invoke(
              'nearby-professionals',
              body: {
                'serviceId': service.id,
                'latitude': location.latitude,
                'longitude': location.longitude,
                'scheduledStart': start.toUtc().toIso8601String(),
                'scheduledEnd': end.toUtc().toIso8601String(),
              },
            )
            as Map<String, dynamic>;
    return (data['professionals'] as List<dynamic>)
        .map(
          (item) => Professional(
            id: item['professional_id'] as String,
            name: item['professional_name'] as String,
            specialty: 'Verified service professional',
            rating: (item['rating'] as num).toDouble(),
            reviewCount: item['rating_count'] as int,
            completedJobs: item['completed_jobs'] as int,
            distanceKm: (item['distance_m'] as num).toDouble() / 1000,
            experience: '${item['completed_jobs']} completed jobs',
            isVerified: true,
          ),
        )
        .toList();
  }

  @override
  Future<List<Booking>> bookings() async {
    final rows = await _client
        .from('bookings')
        .select(
          'id, booking_status, scheduled_start, problem_description, services(*), booking_locations(address_snapshot)',
        )
        .order('scheduled_start', ascending: false);
    return rows.map(_bookingFromRow).toList();
  }

  Booking _bookingFromRow(dynamic raw) {
    final row = Map<String, dynamic>.from(raw as Map);
    final serviceRow = Map<String, dynamic>.from(
      (row['services'] as Map?) ?? const {},
    );
    final service = Service(
      id: serviceRow['id'] as String? ?? '',
      categoryId: serviceRow['category_id'] as String? ?? '',
      name: serviceRow['name'] as String? ?? 'Home service',
      description: serviceRow['description'] as String? ?? '',
      durationMinutes:
          (serviceRow['typical_duration_minutes'] as num?)?.toInt() ?? 60,
      estimateMinPaise:
          (serviceRow['estimate_min_paise'] as num?)?.toInt() ?? 0,
      estimateMaxPaise:
          (serviceRow['estimate_max_paise'] as num?)?.toInt() ?? 0,
      icon: 'home_repair_service',
    );
    final locationRows = row['booking_locations'];
    final location = locationRows is List && locationRows.isNotEmpty
        ? Map<String, dynamic>.from(locationRows.first as Map)
        : <String, dynamic>{};
    return Booking(
      id: row['id'] as String,
      service: service,
      status: _statusFromDatabase(
        row['booking_status'] as String? ?? 'requested',
      ),
      scheduledAt: DateTime.parse(row['scheduled_start'] as String).toLocal(),
      location: GeoLocation(
        latitude: 0,
        longitude: 0,
        address: location['address_snapshot'] as String? ?? 'Service location',
      ),
      description: row['problem_description'] as String? ?? '',
    );
  }

  BookingStatus _statusFromDatabase(String status) => switch (status) {
    'dispatching' => BookingStatus.dispatching,
    'accepted' => BookingStatus.accepted,
    'on_the_way' => BookingStatus.onTheWay,
    'arrived' => BookingStatus.arrived,
    'in_progress' => BookingStatus.inProgress,
    'work_done' => BookingStatus.workDone,
    'amount_pending_approval' => BookingStatus.quotePending,
    'approved' => BookingStatus.approved,
    'disputed' => BookingStatus.disputed,
    'payment_pending' => BookingStatus.paymentPending,
    'paid' => BookingStatus.paid,
    'closed' => BookingStatus.closed,
    'rated' => BookingStatus.rated,
    'cancelled' => BookingStatus.cancelled,
    _ => BookingStatus.requested,
  };

  Future<Booking> _refreshBooking(String bookingId) async {
    final rows = await _client
        .from('bookings')
        .select(
          'id, booking_status, scheduled_start, problem_description, services(*), booking_locations(address_snapshot)',
        )
        .eq('id', bookingId)
        .limit(1);
    if (rows.isEmpty) {
      throw StateError('Booking not found');
    }
    return _bookingFromRow(rows.first);
  }

  @override
  Future<Booking> createBooking({
    required Service service,
    required DateTime start,
    required DateTime end,
    required String description,
    required GeoLocation location,
    required bool automaticMatch,
    Professional? professional,
  }) async {
    final data = await _invoke(
      'create-booking',
      body: {
        'serviceId': service.id,
        'mode': automaticMatch ? 'automatic_match' : 'selected_professional',
        'selectedProfessionalId': professional?.id,
        'scheduledStart': start.toUtc().toIso8601String(),
        'scheduledEnd': end.toUtc().toIso8601String(),
        'problemDescription': description,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'addressSnapshot': location.address,
      },
      idempotencyKey: 'mobile-${DateTime.now().microsecondsSinceEpoch}',
    );
    final bookingId = (data as Map<String, dynamic>)['booking_id'] as String;
    return Booking(
      id: bookingId,
      service: service,
      status: automaticMatch
          ? BookingStatus.dispatching
          : BookingStatus.requested,
      scheduledAt: start,
      location: location,
      description: description,
      professional: professional,
    );
  }

  @override
  Future<Booking> transitionBooking(
    String bookingId,
    BookingStatus status,
  ) async {
    await _invoke(
      'booking-action',
      body: {'bookingId': bookingId, 'action': _actionForStatus(status)},
    );
    return _refreshBooking(bookingId);
  }

  @override
  Future<Booking> submitQuote(String bookingId, List<QuoteLine> lines) async {
    await _invoke(
      'submit-quote',
      body: {
        'bookingId': bookingId,
        'lineItems': lines
            .map(
              (line) => {
                'lineType': line.type,
                'description': line.description,
                'quantity': line.quantity,
                'unitAmountPaise': line.unitAmountPaise,
              },
            )
            .toList(),
      },
    );
    return _refreshBooking(bookingId);
  }

  @override
  Future<Booking> approveQuote(String bookingId) async {
    final quote = await _client
        .from('booking_amount_proposals')
        .select('id')
        .eq('booking_id', bookingId)
        .eq('status', 'submitted')
        .order('revision_number', ascending: false)
        .limit(1)
        .maybeSingle();
    if (quote == null) {
      throw StateError('No quote is awaiting approval');
    }
    final result = await _client.rpc(
      'approve_quote',
      params: {'booking_uuid': bookingId, 'proposal_uuid': quote['id']},
    );
    if (result.error != null) throw StateError(result.error!.message);
    return _refreshBooking(bookingId);
  }

  @override
  Future<PaymentOrder> createPaymentOrder(String bookingId) async {
    final data = await _invoke(
      'create-payment-order',
      body: {'bookingId': bookingId},
      idempotencyKey: 'payment-$bookingId',
    );
    final payload = data as Map<String, dynamic>;
    return PaymentOrder(
      paymentId: payload['payment_id'] as String,
      orderId: payload['order_id'] as String,
      amountPaise: (payload['amount_paise'] as num).toInt(),
      publicKey: payload['public_key'] as String,
    );
  }

  @override
  Future<void> verifyPayment({
    required PaymentOrder order,
    required String providerPaymentId,
    required String signature,
  }) async {
    await _invoke(
      'verify-payment',
      body: {
        'paymentId': order.paymentId,
        'orderId': order.orderId,
        'providerPaymentId': providerPaymentId,
        'signature': signature,
      },
    );
  }

  @override
  Future<void> recordCashCollection(
    String bookingId, {
    required int amountPaise,
  }) async {
    final result = await _client.rpc(
      'record_cash_collection',
      params: {
        'booking_uuid': bookingId,
        'quoted_amount_paise': amountPaise,
        'idempotency_key':
            'cash-$bookingId-${DateTime.now().microsecondsSinceEpoch}',
        'customer_confirmed': true,
      },
    );
    if (result.error != null) throw StateError(result.error!.message);
  }

  @override
  Future<Map<String, int>> financialSummary() async {
    final result = await _client.rpc('professional_financial_summary');
    if (result.error != null) throw StateError(result.error!.message);
    final rows = result.data as List<dynamic>;
    if (rows.isEmpty) return {};
    final row = Map<String, dynamic>.from(rows.first as Map);
    return row.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );
  }

  String _actionForStatus(BookingStatus status) => switch (status) {
    BookingStatus.onTheWay => 'on_the_way',
    BookingStatus.workDone => 'work_done',
    BookingStatus.cancelled => 'cancel',
    _ => throw ArgumentError('Unsupported transition'),
  };
}
