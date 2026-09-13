import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() =>
      _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadAppointments();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Fetch appointments booked directly against this doctor's id.
      var data = await Supabase.instance.client
          .from('appointments')
          .select()
          .eq('doctor_id', userId)
          .order('created_at', ascending: false);

      // Some older rows may have been written keyed by doctor_name instead
      // of doctor_id — fall back to that, but stay scoped to this doctor.
      // Never fall back to an unfiltered query: that would show every
      // patient's appointments to any doctor whose own list is empty.
      if (data.isEmpty) {
        try {
          final profile = await Supabase.instance.client
              .from('profiles')
              .select('full_name')
              .eq('id', userId)
              .maybeSingle();

          final doctorName = profile?['full_name'] as String?;
          if (doctorName != null) {
            data = await Supabase.instance.client
                .from('appointments')
                .select()
                .eq('doctor_name', doctorName)
                .order('created_at', ascending: false);
          }
        } catch (_) {
          // Non-fatal — the doctor simply has no legacy-keyed appointments.
        }
      }

      if (mounted) {
        setState(() {
          _appointments = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showAppSnack(
          context,
          userFriendlyErrorMessage(
            e,
            defaultMessage:
                'Unable to load appointments right now. Please pull down to refresh.',
          ),
          tone: AppStatusTone.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back to dashboard',
            onPressed: () => context.go('/doctor-dashboard'),
          ),
          title: const Text('Appointments'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadAppointments,
              tooltip: 'Refresh',
            ),
          ],
          bottom: TabBar(
            controller: _tab,
            tabs: [
              Tab(text: 'All (${_appointments.length})'),
              const Tab(text: 'Upcoming'),
              const Tab(text: 'Completed'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : TabBarView(
                controller: _tab,
                children: [
                  // Tab 0: All appointments
                  _buildSimpleList(_appointments, 'All'),
                  // Tab 1: Upcoming (pending, confirmed)
                  _buildSimpleList(
                    _appointments
                        .where(
                          (a) =>
                              a['status'] == 'pending' ||
                              a['status'] == 'confirmed' ||
                              a['status'] == 'emergency',
                        )
                        .toList(),
                    'Upcoming',
                  ),
                  // Tab 2: Completed
                  _buildSimpleList(
                    _appointments
                        .where((a) => a['status'] == 'completed')
                        .toList(),
                    'Completed',
                  ),
                ],
      ),
    );
  }

  Widget _buildSimpleList(List<Map<String, dynamic>> items, String label) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'No appointments in $label',
              style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final appt = items[index];
        final studentName = (appt['student_name'] as String?) ?? 'Student';
        final date = (appt['date'] as String?) ?? '';
        final time = (appt['time'] as String?) ?? '';
        final status = (appt['status'] as String?) ?? 'unknown';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                studentName.toString().isNotEmpty
                    ? studentName.toString()[0].toUpperCase()
                    : 'S',
                style: const TextStyle(color: AppColors.primary),
              ),
            ),
            title: Text(studentName.toString()),
            subtitle: Text('$date at $time'),
            trailing: Chip(
              label: Text(status.toString().toUpperCase()),
              backgroundColor: _getStatusColor(
                status.toString(),
              ).withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: _getStatusColor(status.toString()),
                fontSize: 12,
              ),
            ),
            onTap: () {
              context.push('/appointment-detail', extra: appt);
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'confirmed':
        return AppColors.success;
      case 'completed':
        return AppColors.primary;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }
}
