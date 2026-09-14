import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';

class DoctorFinancesScreen extends StatefulWidget {
  const DoctorFinancesScreen({super.key});

  @override
  State<DoctorFinancesScreen> createState() => _DoctorFinancesScreenState();
}

class _DoctorFinancesScreenState extends State<DoctorFinancesScreen> {
  bool _isLoading = true;
  int _paidCount = 0;
  int _pendingCount = 0;
  double _revenue = 0.0;
  List<Map<String, dynamic>> _paidAppointments = [];
  List<Map<String, dynamic>> _pendingAppointments = [];

  @override
  void initState() {
    super.initState();
    _loadFinances();
  }

  Future<void> _loadFinances() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      List<Map<String, dynamic>> paidData = [];
      List<Map<String, dynamic>> pendingData = [];

      try {
        // Try loading with fee/payment_status columns
        paidData = List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('appointments')
              .select('id, fee, student_name, date, time')
              .eq('doctor_id', userId)
              .eq('payment_status', 'paid')
              .order('date', ascending: false),
        );

        pendingData = List<Map<String, dynamic>>.from(
          await Supabase.instance.client
              .from('appointments')
              .select('id, fee, student_name, date, time')
              .eq('doctor_id', userId)
              .eq('payment_status', 'pending')
              .order('date', ascending: false),
        );
      } catch (_) {
        // fee/payment_status columns may not exist yet - fall back
        // to showing completed appointments as "paid"
        try {
          final allAppts = await Supabase.instance.client
              .from('appointments')
              .select('id, student_name, date, time, status')
              .eq('doctor_id', userId)
              .order('date', ascending: false);

          for (final a in allAppts) {
            final appt = Map<String, dynamic>.from(a);
            appt['fee'] = 0; // no fee data available
            final status = (appt['status'] as String?) ?? '';
            if (status == 'completed' || status == 'done') {
              paidData.add(appt);
            } else if (status == 'pending' || status == 'confirmed') {
              pendingData.add(appt);
            }
          }
        } catch (e) {
          debugPrint('Finances fallback error: $e');
        }
      }

      // Calculate revenue
      double totalRevenue = 0.0;
      for (final appt in paidData) {
        final fee = appt['fee'];
        if (fee != null) {
          totalRevenue += (fee is int)
              ? fee.toDouble()
              : (fee as double? ?? 0.0);
        }
      }

      if (mounted) {
        setState(() {
          _paidAppointments = paidData;
          _pendingAppointments = pendingData;
          _paidCount = paidData.length;
          _pendingCount = pendingData.length;
          _revenue = totalRevenue;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load finances: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        title: const Text('Earnings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back to dashboard',
          onPressed: () => context.go('/doctor-dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadFinances,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : RefreshIndicator(
              onRefresh: _loadFinances,
              color: AppColors.primary,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Summary Cards
                  _SummarySection(
                    revenue: _revenue,
                    paidCount: _paidCount,
                    pendingCount: _pendingCount,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Paid Consultations
                  _AppointmentsListSection(
                    title: 'Paid Consultations',
                    subtitle: 'Successfully paid appointments',
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    appointments: _paidAppointments,
                    isPaid: true,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Pending Payments
                  _AppointmentsListSection(
                    title: 'Pending Payments',
                    subtitle: 'Awaiting payment',
                    icon: Icons.pending,
                    color: AppColors.warning,
                    appointments: _pendingAppointments,
                    isPaid: false,
                  ),
                ],
              ),
            ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final double revenue;
  final int paidCount;
  final int pendingCount;

  const _SummarySection({
    required this.revenue,
    required this.paidCount,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Total Revenue Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.success],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            children: [
              const Icon(
                Icons.account_balance_wallet,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Total Revenue',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: AppTypography.bodyLarge,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '\$${revenue.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // Stats Row
        Row(
          children: [
            Expanded(
              child: _StatBox(
                label: 'Paid',
                value: paidCount.toString(),
                icon: Icons.check_circle,
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _StatBox(
                label: 'Pending',
                value: pendingCount.toString(),
                icon: Icons.pending,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: AppTypography.titleLarge,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: AppTypography.labelSmall,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppointmentsListSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Map<String, dynamic>> appointments;
  final bool isPaid;

  const _AppointmentsListSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.appointments,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.smAll,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: AppTypography.titleLarge,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: AppTypography.labelSmall,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${appointments.length}',
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (appointments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 40,
                  color: AppColors.textMuted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'No appointments',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          ...appointments.map(
            (appt) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AppointmentFinanceCard(appointment: appt, isPaid: isPaid),
            ),
          ),
      ],
    );
  }
}

class _AppointmentFinanceCard extends StatelessWidget {
  final Map<String, dynamic> appointment;
  final bool isPaid;

  const _AppointmentFinanceCard({
    required this.appointment,
    required this.isPaid,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = (appointment['student_name'] as String?) ?? 'Student';
    final date = (appointment['date'] as String?) ?? '';
    final time = (appointment['time'] as String?) ?? '';
    final fee = appointment['fee'] ?? 0;
    final feeValue = fee is int ? fee.toDouble() : (fee as double? ?? 0.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isPaid ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.1),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(
              isPaid ? Icons.check_circle : Icons.pending,
              color: isPaid ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$date at $time',
                  style: const TextStyle(
                    fontSize: AppTypography.labelSmall,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${feeValue.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: AppTypography.titleMedium,
              fontWeight: FontWeight.w900,
              color: isPaid ? AppColors.success : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }
}
