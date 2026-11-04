import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../app/widgets.dart';
import '../../core/models.dart';

Future<void> showBookingWizard(
  BuildContext context,
  WidgetRef ref,
  Service service,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.canvas,
    builder: (_) => BookingWizard(service: service),
  );
}

class BookingWizard extends ConsumerStatefulWidget {
  const BookingWizard({super.key, required this.service});
  final Service service;

  @override
  ConsumerState<BookingWizard> createState() => _BookingWizardState();
}

class _BookingWizardState extends ConsumerState<BookingWizard> {
  final _descriptionController = TextEditingController();
  final _picker = ImagePicker();
  int _step = 0;
  bool _automatic = true;
  DateTime _scheduledAt = DateTime.now().add(const Duration(minutes: 31));
  GeoLocation? _location;
  List<Professional> _professionals = const [];
  Professional? _selectedProfessional;
  int _photoCount = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    setState(() => _error = null);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission is required to book a home service.',
        );
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Turn on Location Services and try again.');
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final location = GeoLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        address: 'Current GPS location',
      );
      final end = _scheduledAt.add(
        Duration(minutes: widget.service.durationMinutes),
      );
      final people = await ref
          .read(repositoryProvider)
          .nearbyProfessionals(
            service: widget.service,
            location: location,
            start: _scheduledAt,
            end: end,
          );
      if (!mounted) return;
      setState(() {
        _location = location;
        _professionals = people;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Bad state: ', ''),
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1800,
    );
    if (photo != null && mounted) setState(() => _photoCount++);
  }

  Future<void> _chooseTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      initialDate: _scheduledAt,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (pickedTime == null || !mounted) return;
    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (selected.isBefore(DateTime.now().add(const Duration(minutes: 30)))) {
      setState(() => _error = 'Choose a time at least 30 minutes from now.');
      return;
    }
    setState(() => _scheduledAt = selected);
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      if (_descriptionController.text.trim().length < 10) {
        setState(
          () => _error = 'Describe the problem in at least 10 characters.',
        );
        return;
      }
      if (_location == null) {
        setState(() => _error = 'Your GPS location is required for a booking.');
        return;
      }
      if (!_automatic && _selectedProfessional == null) {
        setState(
          () => _error = 'Choose a professional or switch to Pick for me.',
        );
        return;
      }
      setState(() => _step = 2);
      return;
    }
    if (_location == null) return;
    setState(() => _loading = true);
    final booking = await ref
        .read(bookingsProvider.notifier)
        .create(
          service: widget.service,
          start: _scheduledAt,
          end: _scheduledAt.add(
            Duration(minutes: widget.service.durationMinutes),
          ),
          description: _descriptionController.text.trim(),
          location: _location!,
          automaticMatch: _automatic,
          professional: _selectedProfessional,
        );
    if (!mounted) return;
    if (booking == null) {
      setState(() {
        _loading = false;
        _error = 'We could not create the booking. Please try again.';
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Booking request sent securely.')),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Book ${widget.service.name}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _progressBar(),
        const SizedBox(height: 20),
        Flexible(child: SingleChildScrollView(child: _stepContent())),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_step > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : () => setState(() => _step--),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
            if (_step > 0) const SizedBox(width: 12),
            SoftButton(
              label: _step == 2 ? 'Confirm request' : 'Continue',
              onPressed: _loading ? null : _next,
              icon: _step == 2 ? Icons.check : Icons.arrow_forward,
              expanded: true,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _progressBar() => Row(
    children: List.generate(
      3,
      (index) => Expanded(
        child: Container(
          height: 4,
          margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
          decoration: BoxDecoration(
            color: index <= _step ? AppColors.saffron : AppColors.line,
            borderRadius: BorderRadius.circular(9),
          ),
        ),
      ),
    ),
  );

  Widget _stepContent() => switch (_step) {
    0 => _modeStep(),
    1 => _detailsStep(),
    _ => _reviewStep(),
  };

  Widget _modeStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'How should we find your professional?',
        style: displayStyle(size: 25),
      ),
      const SizedBox(height: 8),
      Text(
        'You will approve the final quote only after the work is complete.',
        style: bodyStyle(),
      ),
      const SizedBox(height: 18),
      _ModeCard(
        selected: _automatic,
        icon: Icons.auto_awesome,
        title: 'Pick for me',
        subtitle: 'We match you with the best eligible professional nearby.',
        onTap: () => setState(() => _automatic = true),
      ),
      const SizedBox(height: 10),
      _ModeCard(
        selected: !_automatic,
        icon: Icons.person_search,
        title: 'I will choose',
        subtitle: 'Browse verified professionals and choose one yourself.',
        onTap: () => setState(() => _automatic = false),
      ),
    ],
  );

  Widget _detailsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Tell us a little more', style: displayStyle(size: 25)),
      const SizedBox(height: 8),
      Text(
        'A clear description helps the professional arrive prepared.',
        style: bodyStyle(),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _descriptionController,
        maxLines: 4,
        maxLength: 4000,
        decoration: const InputDecoration(
          hintText: 'Example: The kitchen tap is leaking from the base…',
          alignLabelWithHint: true,
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _pickPhoto,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(
          _photoCount == 0
              ? 'Add photos (optional)'
              : '$_photoCount photo${_photoCount == 1 ? '' : 's'} attached',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      const SizedBox(height: 20),
      _LocationCard(location: _location, onTap: _useLocation),
      const SizedBox(height: 12),
      _ScheduleCard(time: _scheduledAt, onTap: _chooseTime),
      if (!_automatic && _location != null) ...[
        const SizedBox(height: 20),
        const Text(
          'Choose a professional',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        ..._professionals.map(
          (professional) => _ProfessionalChoice(
            professional: professional,
            selected: _selectedProfessional?.id == professional.id,
            onTap: () => setState(() => _selectedProfessional = professional),
          ),
        ),
      ],
    ],
  );

  Widget _reviewStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Review your request', style: displayStyle(size: 25)),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          children: [
            _ReviewRow(label: 'Service', value: widget.service.name),
            _ReviewRow(
              label: 'Matching',
              value: _automatic
                  ? 'Pick for me'
                  : _selectedProfessional?.name ?? 'Selected professional',
            ),
            _ReviewRow(
              label: 'When',
              value: DateFormat('EEE, d MMM • h:mm a').format(_scheduledAt),
            ),
            _ReviewRow(
              label: 'Where',
              value: _location?.address ?? 'GPS location required',
            ),
            _ReviewRow(label: 'Upfront payment', value: '₹0', accent: true),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Text(
        'The professional submits an itemized final quote after completing the work. You approve it before any payment.',
        style: bodyStyle(),
      ),
    ],
  );
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected ? AppColors.cream : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.saffron : AppColors.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          PillIcon(
            icon: icon,
            color: selected ? AppColors.coral : AppColors.ink,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: bodyStyle()),
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            color: selected ? AppColors.coral : AppColors.muted,
          ),
        ],
      ),
    ),
  );
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.onTap});
  final GeoLocation? location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(18),
    child: Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: AppColors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location == null
                      ? 'Add service location'
                      : 'Service location',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  location?.address ??
                      'Required GPS location • address is only a display snapshot',
                  style: bodyStyle(color: AppColors.ink),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    ),
  );
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.time, required this.onTap});
  final DateTime time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    tileColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: AppColors.line),
    ),
    leading: const Icon(Icons.calendar_month, color: AppColors.coral),
    title: const Text(
      'Appointment',
      style: TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(DateFormat('EEE, d MMM • h:mm a').format(time)),
    trailing: const Icon(Icons.edit_calendar_outlined),
  );
}

class _ProfessionalChoice extends StatelessWidget {
  const _ProfessionalChoice({
    required this.professional,
    required this.selected,
    required this.onTap,
  });
  final Professional professional;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
    leading: CircleAvatar(
      backgroundColor: AppColors.cream,
      child: Text(professional.name.substring(0, 1)),
    ),
    title: Text(
      professional.name,
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
    subtitle: Text(
      '★ ${professional.rating}  •  ${professional.distanceKm.toStringAsFixed(1)} km away',
    ),
    trailing: Icon(
      selected ? Icons.check_circle : Icons.circle_outlined,
      color: selected ? AppColors.success : AppColors.muted,
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.label,
    required this.value,
    this.accent = false,
  });
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: bodyStyle())),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: accent ? AppColors.success : AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}
