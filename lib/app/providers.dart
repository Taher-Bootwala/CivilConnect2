import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../core/verification_service.dart';

final verificationServiceProvider = Provider<VerificationService>((ref) {
  return VerificationService();
});

final repositoryProvider = Provider<MarketplaceRepository>(
  (ref) => DemoMarketplaceRepository(),
);
final roleProvider = StateProvider<AppRole>((ref) => AppRole.customer);

class AuthNotifier extends StateNotifier<UserProfile?> {
  AuthNotifier(this._ref) : super(null) {
    _init();
  }

  final Ref _ref;
  StreamSubscription<UserProfile?>? _subscription;

  MarketplaceRepository get _repo => _ref.read(repositoryProvider);

  Future<void> _init() async {
    final user = await _repo.currentProfile();
    state = user;
    if (user != null) {
      _ref.read(roleProvider.notifier).state = user.role;
    }
    _subscription = _repo.authStateChanges.listen((updatedUser) {
      state = updatedUser;
      if (updatedUser != null) {
        _ref.read(roleProvider.notifier).state = updatedUser.role;
      }
    });
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _repo.signIn(email: email, password: password);
    state = user;
    _ref.read(roleProvider.notifier).state = user.role;
  }

  Future<GoogleAuthProfile?> pickGoogleAccount() async {
    return await _repo.signInWithGoogle();
  }

  Future<void> signUp({
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
    final user = await _repo.signUp(
      name: name,
      email: email,
      password: password,
      phone: phone,
      role: role,
      gender: gender,
      firstName: firstName,
      lastName: lastName,
      dateOfBirth: dateOfBirth,
      age: age,
    );
    state = user;
    _ref.read(roleProvider.notifier).state = user.role;
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = null;
  }

  void updateRole(AppRole role) {
    if (state != null) {
      state = state!.copyWith(role: role);
      _ref.read(roleProvider.notifier).state = role;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserProfile?>((ref) {
  return AuthNotifier(ref);
});

final profileProvider = FutureProvider<UserProfile?>((ref) async {
  final authUser = ref.watch(authProvider);
  if (authUser != null) return authUser;
  return ref.watch(repositoryProvider).currentProfile();
});
final categoriesProvider = FutureProvider<List<ServiceCategory>>(
  (ref) => ref.watch(repositoryProvider).categories(),
);
final servicesProvider = FutureProvider.family<List<Service>, String>(
  (ref, query) => ref.watch(repositoryProvider).services(query: query),
);

class BookingController extends StateNotifier<AsyncValue<List<Booking>>> {
  BookingController(this._repository) : super(const AsyncValue.loading()) {
    refresh();
  }

  final MarketplaceRepository _repository;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _repository.bookings());
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<Booking?> create({
    required Service service,
    required DateTime start,
    required DateTime end,
    required String description,
    required GeoLocation location,
    required bool automaticMatch,
    Professional? professional,
  }) async {
    try {
      final booking = await _repository.createBooking(
        service: service,
        start: start,
        end: end,
        description: description,
        location: location,
        automaticMatch: automaticMatch,
        professional: professional,
      );
      final current = state.valueOrNull ?? const <Booking>[];
      state = AsyncValue.data([booking, ...current]);
      return booking;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      return null;
    }
  }

  Future<void> transition(Booking booking, BookingStatus status) async {
    try {
      final updated = await _repository.transitionBooking(booking.id, status);
      final current = state.valueOrNull ?? const <Booking>[];
      state = AsyncValue.data(
        current.map((item) => item.id == updated.id ? updated : item).toList(),
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final bookingsProvider =
    StateNotifierProvider<BookingController, AsyncValue<List<Booking>>>(
      (ref) => BookingController(ref.watch(repositoryProvider)),
    );
