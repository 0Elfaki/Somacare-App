import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../doctor/data/notification_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';
import '../../../widgets/bloom_components.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key});

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  final _reasonCtrl = TextEditingController();
  bool _isLoading = false;
  bool _loadingDoctors = true;
  List<Map<String, dynamic>> _doctors = [];
  Map<String, dynamic>? _selectedDoctor;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTime;
  bool _isEmergency = false; // Emergency/immediate appointment flag
  String _category = 'All';

  final List<String> _times = const [
    '9:00',
    '9:30',
    '10:00',
    '10:30',
    '11:00',
    '11:30',
    '1:00',
    '1:30',
    '2:00',
    '2:30',
    '3:00',
    '3:30',
    '4:00',
  ];

  static const int _consultFee = 15000;
  static const int _platformFee = 1000;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _selectedTime = _times[6];
  }

  Future<void> _loadDoctors() async {
    try {
      // Fetch doctors from profiles table with role='doctor' to get the correct profile IDs
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('role', 'doctor');

      if (mounted) {
        setState(() {
          _doctors = List<Map<String, dynamic>>.from(response);
          _loadingDoctors = false;
          if (_doctors.isNotEmpty) {
            _selectedDoctor = _doctors.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingDoctors = false;
        });
        showAppSnack(
          context,
          userFriendlyErrorMessage(
            e,
            defaultMessage:
                'Unable to load available doctors right now. Please pull down to refresh.',
          ),
          tone: AppStatusTone.danger,
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String _specialtyOf(Map<String, dynamic> d) =>
      (d['specialization'] ?? d['specialty'] ?? 'General Practice') as String;

  List<String> get _categories {
    final set = <String>{'All'};
    for (final d in _doctors) {
      set.add(_specialtyOf(d));
    }
    return set.toList();
  }

  List<Map<String, dynamic>> get _filteredDoctors => _category == 'All'
      ? _doctors
      : _doctors.where((d) => _specialtyOf(d) == _category).toList();

  bool get _canConfirm =>
      _selectedDoctor != null &&
      (_isEmergency || _selectedTime != null) &&
      _reasonCtrl.text.trim().isNotEmpty &&
      !_isLoading;

  void _goToPayment() {
    if (!_canConfirm) return;
    context.push(
      '/payment',
      extra: {
        'doctorName': _selectedDoctor!['full_name'] as String? ?? 'Doctor',
        'consultFee': _consultFee,
        'platformFee': _platformFee,
        'onConfirm': _confirm,
      },
    );
  }

  Future<void> _confirm() async {
    if (!_canConfirm) return;
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;

      // For emergency appointments, set to immediate start
      final appointmentDate = _isEmergency
          ? DateTime.now().toIso8601String().split('T').first
          : _selectedDate.toIso8601String().split('T').first;
      final appointmentTime = _isEmergency ? 'Immediate' : _selectedTime;

      await Supabase.instance.client.from('appointments').insert({
        'student_id': userId,
        'doctor_id': _selectedDoctor!['id'], // This is now the profile ID
        'doctor_name': _selectedDoctor!['full_name'],
        'doctor_specialty': _specialtyOf(_selectedDoctor!),
        'date': appointmentDate,
        'time': appointmentTime,
        'reason': _reasonCtrl.text.trim(),
        'status': 'pending', // Emergency appointments need doctor approval
        'is_emergency': _isEmergency,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Send notification to doctor
      final studentName =
          Supabase.instance.client.auth.currentUser?.email ?? 'Student';
      final doctorId = _selectedDoctor!['id'] as String;
      if (_isEmergency) {
        await NotificationService.notifyEmergency(
          doctorId: doctorId,
          studentName: studentName,
          reason: _reasonCtrl.text.trim(),
        );
      } else {
        await NotificationService.notifyNewBooking(
          doctorId: doctorId,
          studentName: studentName,
          date: appointmentDate,
          time: appointmentTime ?? '',
        );
      }

      if (!mounted) return;

      // Non-emergency bookings are confirmed from the Payment screen, which
      // owns its own success snackbar + navigation. Only emergency bookings
      // (which skip payment) drive their own UX here.
      if (!_isEmergency) return;

      showAppSnack(
        context,
        'Emergency appointment started. Doctor has been notified.',
        tone: AppStatusTone.success,
      );
      context.go('/student-dashboard');
    } catch (e) {
      if (!mounted) return;
      showAppSnack(
        context,
        userFriendlyErrorMessage(
          e,
          defaultMessage:
              'Unable to complete your appointment booking. Please try again.',
        ),
        tone: AppStatusTone.danger,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  static const _weekdayLabels = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN',
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/student-dashboard');
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        body: SafeArea(
          child: Column(
            children: [
              const BloomScreenHeader(title: 'Book Appointment'),
              Expanded(
                child: _loadingDoctors
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _doctors.isEmpty
                    ? Center(
                        child: Text(
                          'No doctors available',
                          style: BloomTextStyles.inter(
                            color: AppColors.textMuted,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BloomFilterChips(
                              options: _categories,
                              selected: _category,
                              onSelect: (v) => setState(() => _category = v),
                            ),
                            const BloomSectionTitle('Available doctors'),
                            BloomCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 15,
                              ),
                              child: Column(
                                children: [
                                  for (
                                    int i = 0;
                                    i < _filteredDoctors.length;
                                    i++
                                  )
                                    _DoctorTile(
                                      doctor: _filteredDoctors[i],
                                      specialty: _specialtyOf(
                                        _filteredDoctors[i],
                                      ),
                                      selected:
                                          _selectedDoctor ==
                                          _filteredDoctors[i],
                                      showBorder:
                                          i != _filteredDoctors.length - 1,
                                      onTap: () => setState(
                                        () => _selectedDoctor =
                                            _filteredDoctors[i],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: BloomCard(
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Emergency appointment (immediate)',
                                        style: BloomTextStyles.inter(
                                          size: 12,
                                          weight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    BloomToggle(
                                      value: _isEmergency,
                                      activeColor: AppColors.error,
                                      onChanged: (v) =>
                                          setState(() => _isEmergency = v),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!_isEmergency) ...[
                              const BloomSectionTitle('Date'),
                              SizedBox(
                                height: 56,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: 7,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 7),
                                  itemBuilder: (context, i) {
                                    final date = DateTime.now().add(
                                      Duration(days: i),
                                    );
                                    final selected =
                                        date.day == _selectedDate.day &&
                                        date.month == _selectedDate.month;
                                    return GestureDetector(
                                      onTap: () =>
                                          setState(() => _selectedDate = date),
                                      child: Container(
                                        width: 52,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.primary
                                              : AppColors.surface,
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: selected
                                              ? null
                                              : Border.all(
                                                  color: AppColors.border,
                                                ),
                                        ),
                                        child: Text(
                                          '${_weekdayLabels[date.weekday - 1]}\n${date.day}',
                                          textAlign: TextAlign.center,
                                          style: BloomTextStyles.inter(
                                            size: 10.5,
                                            weight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const BloomSectionTitle('Time'),
                              Wrap(
                                spacing: 9,
                                runSpacing: 9,
                                children: _times.map((t) {
                                  final selected = t == _selectedTime;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedTime = t),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? AppColors.primary
                                            : AppColors.surface,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                        border: selected
                                            ? null
                                            : Border.all(
                                                color: AppColors.border,
                                              ),
                                      ),
                                      child: Text(
                                        t,
                                        style: BloomTextStyles.inter(
                                          size: 10.5,
                                          weight: FontWeight.w600,
                                          color: selected
                                              ? Colors.white
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                            const BloomSectionTitle('Reason for visit'),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: AppRadius.mdAll,
                                border: Border.all(color: AppColors.border),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: TextField(
                                controller: _reasonCtrl,
                                maxLines: 4,
                                onChanged: (_) => setState(() {}),
                                style: BloomTextStyles.inter(
                                  size: 12,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText:
                                      'Sore throat and mild fever since yesterday…',
                                  hintStyle: BloomTextStyles.inter(
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: BloomButton(
                  label: _isLoading
                      ? 'Please wait…'
                      : _isEmergency
                      ? 'Confirm appointment'
                      : 'Continue to payment',
                  isLoading: _isLoading,
                  onPressed: _canConfirm
                      ? (_isEmergency ? _confirm : _goToPayment)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorTile extends StatelessWidget {
  final Map<String, dynamic> doctor;
  final String specialty;
  final bool selected;
  final bool showBorder;
  final VoidCallback onTap;

  const _DoctorTile({
    required this.doctor,
    required this.specialty,
    required this.selected,
    required this.showBorder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: showBorder
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              )
            : null,
        child: Row(
          children: [
            const BloomAvatar(size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor['full_name'] as String? ?? 'Doctor',
                    style: BloomTextStyles.inter(
                      size: 12.5,
                      weight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    specialty,
                    style: BloomTextStyles.inter(
                      size: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 12, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
