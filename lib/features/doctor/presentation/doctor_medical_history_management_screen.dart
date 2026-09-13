import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../student/data/medical_history_model.dart';
import '../../student/data/medical_history_repository.dart';

/// Doctor Medical History Management Screen
///
/// Allows doctors to:
/// - Select a student from their patient list
/// - View/edit student's medical history
/// - Approve or deny medical history with comments
class DoctorMedicalHistoryManagementScreen extends StatefulWidget {
  final String? studentId;
  final bool isEmbedded;
  final bool showApprovalOnly;

  const DoctorMedicalHistoryManagementScreen({
    super.key, 
    this.studentId,
    this.isEmbedded = false,
    this.showApprovalOnly = false,
  });

  @override
  State<DoctorMedicalHistoryManagementScreen> createState() =>
      _DoctorMedicalHistoryManagementScreenState();
}

class _DoctorMedicalHistoryManagementScreenState
    extends State<DoctorMedicalHistoryManagementScreen> {
  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic>? _selectedPatient;
  MedicalHistory? _history;
  bool _isLoadingPatients = true;
  bool _isLoadingHistory = false;
  // ignore: unused_field - kept for potential future error handling
  String? _error;

  SupabaseClient get _client => Supabase.instance.client;

  // Text controllers for editing
  final _chronicConditionsController = TextEditingController();
  final _pastIllnessesController = TextEditingController();
  final _hospitalizationsController = TextEditingController();
  final _familyConditionsController = TextEditingController();
  final _surgicalHistoryController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _immunizationsController = TextEditingController();
  final _socialHistoryController = TextEditingController();
  final _reviewOfSystemsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    // If a student ID was passed, we'll auto-select after loading
    if (widget.studentId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoSelectStudent(widget.studentId!);
      });
    }
  }

  Future<void> _autoSelectStudent(String studentId) async {
    // Wait for patients to load and then select
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    final patientIndex = _patients.indexWhere(
      (p) => p['student_id'] == studentId || p['id'] == studentId,
    );

    if (patientIndex >= 0) {
      final patient = _patients[patientIndex];
      final patientId =
          patient['student_id']?.toString() ?? patient['id']?.toString();
      setState(() {
        _selectedPatient = patient;
        _history = null;
      });
      if (patientId != null) {
        _loadStudentHistory(patientId);
      }
    }
  }

  @override
  void dispose() {
    _chronicConditionsController.dispose();
    _pastIllnessesController.dispose();
    _hospitalizationsController.dispose();
    _familyConditionsController.dispose();
    _surgicalHistoryController.dispose();
    _allergiesController.dispose();
    _immunizationsController.dispose();
    _socialHistoryController.dispose();
    _reviewOfSystemsController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoadingPatients = true;
      _error = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoadingPatients = false;
          _error = 'Not logged in';
        });
        return;
      }

      // Get patients from appointments (students doctor has consulted with)
      final appointmentsData = await Supabase.instance.client
          .from('appointments')
          .select('student_id')
          .eq('doctor_id', userId);

      // Get unique student IDs
      final studentIds = appointmentsData
          .map((a) => a['student_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (studentIds.isEmpty) {
        setState(() {
          _patients = [];
          _isLoadingPatients = false;
        });
        return;
      }

      // Fetch profiles only for the students this doctor has actually seen —
      // never the full patient roster.
      List<dynamic> profilesData = [];
      try {
        profilesData = await _client
            .from('profiles')
            .select('id, full_name, role')
            .inFilter('id', studentIds);
      } catch (e) {
        debugPrint('Error fetching profiles: $e');
      }

      final profiles = profilesData.cast<Map<String, dynamic>>();

      setState(() {
        _patients = profiles.where((p) => p['role'] == 'student').toList();
        _isLoadingPatients = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPatients = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadStudentHistory(String studentId) async {
    setState(() {
      _isLoadingHistory = true;
      _error = null;
    });

    try {
      final history = await MedicalHistoryRepository.instance.fetchForStudent(
        studentId,
      );
      setState(() {
        _history = history;
        _isLoadingHistory = false;
        _populateControllers(history);
      });
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
        _error = e.toString();
      });
    }
  }

  void _populateControllers(MedicalHistory history) {
    _chronicConditionsController.text = history.chronicConditions;
    _pastIllnessesController.text = history.pastIllnesses;
    _hospitalizationsController.text = history.hospitalizations;
    _familyConditionsController.text = history.familyConditions;
    _surgicalHistoryController.text = history.surgicalHistory;
    _allergiesController.text = history.allergies;
    _immunizationsController.text = history.immunizations;
    _socialHistoryController.text = history.socialHistory;
    _reviewOfSystemsController.text = history.reviewOfSystems;
  }

  Future<void> _saveHistory() async {
    if (_history == null) return;

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final updatedHistory = _history!.copyWith(
        chronicConditions: _chronicConditionsController.text,
        pastIllnesses: _pastIllnessesController.text,
        hospitalizations: _hospitalizationsController.text,
        familyConditions: _familyConditionsController.text,
        surgicalHistory: _surgicalHistoryController.text,
        allergies: _allergiesController.text,
        immunizations: _immunizationsController.text,
        socialHistory: _socialHistoryController.text,
        reviewOfSystems: _reviewOfSystemsController.text,
      );

      await MedicalHistoryRepository.instance.save(updatedHistory);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical history saved successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadStudentHistory(_selectedPatient!['id'].toString());
      }
    } catch (e) {
      setState(() {
        _isLoadingHistory = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _approveHistory() async {
    if (_history == null || _history!.id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.success),
            SizedBox(width: 8),
            Text('Approve Medical History'),
          ],
        ),
        content: const Text(
          'Are you sure you want to approve this medical history? '
          'The student will be able to download the PDF after approval.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await MedicalHistoryRepository.instance.approve(_history!.id);
      _loadStudentHistory(_selectedPatient!['id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical history approved!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _denyHistory() async {
    if (_history == null || _history!.id.isEmpty) return;

    final commentController = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AppColors.error),
            SizedBox(width: 8),
            Text('Deny Medical History'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Please provide a reason for denying this medical history:',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for denial...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, commentController.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (comment != null && comment.isNotEmpty && mounted) {
      await MedicalHistoryRepository.instance.deny(_history!.id, comment);
      _loadStudentHistory(_selectedPatient!['id'].toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medical history denied'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      children: [
        if (!widget.isEmbedded)
          // Student Selection Dropdown
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primary.withValues(alpha: 0.1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Select Student',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _isLoadingPatients
                    ? const Center(child: CircularProgressIndicator())
                    : _patients.isEmpty
                    ? const Text('No patients found')
                    : DropdownButtonFormField<Map<String, dynamic>>(
                        initialValue: _selectedPatient,
                        hint: const Text('Choose a student...'),
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        items: _patients.map((patient) {
                          return DropdownMenuItem(
                            value: patient,
                            child: Text(
                              (patient['full_name'] as String?) ??
                                  (patient['email'] as String?) ??
                                  'Unknown',
                            ),
                          );
                        }).toList(),
                        onChanged: (patient) {
                          setState(() {
                            _selectedPatient = patient;
                            _history = null;
                          });
                          if (patient != null) {
                            _loadStudentHistory(patient['id'].toString());
                          }
                        },
                      ),
              ],
            ),
          ),

          // Medical History Content
          Expanded(
            child: _selectedPatient == null && !widget.isEmbedded
                ? const Center(
                    child: Text(
                      'Please select a student to view their medical history',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  )
                : _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _history == null
                ? const Center(child: Text('No medical history found'))
                : _buildHistoryForm(),
          ),
        ],
      );

    if (widget.isEmbedded) {
      return body;
    }

    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(title: const Text('Medical histories')),
      body: body,
    );
  }

  Widget _buildHistoryForm() {
    final isApproved = _history!.isApproved;
    final hasDenial =
        _history!.denialReason != null && _history!.denialReason!.isNotEmpty;

    if (widget.showApprovalOnly) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(isApproved, hasDenial),
            const SizedBox(height: 16),
            if (!isApproved) _buildApprovalButtons(),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Fields
          _buildTextField(
            label: 'Chronic Conditions',
            controller: _chronicConditionsController,
            hint: 'e.g., Asthma, Diabetes, Hypertension',
          ),
          _buildTextField(
            label: 'Past Illnesses',
            controller: _pastIllnessesController,
            hint: 'e.g., Chickenpox, Pneumonia, COVID-19',
          ),
          _buildTextField(
            label: 'Hospitalizations',
            controller: _hospitalizationsController,
            hint: 'e.g., Surgery, Emergency visits',
          ),
          _buildTextField(
            label: 'Family Medical Conditions',
            controller: _familyConditionsController,
            hint: 'e.g., Heart Disease, Diabetes (parents)',
          ),
          _buildTextField(
            label: 'Surgical History',
            controller: _surgicalHistoryController,
            hint: 'e.g., Appendectomy, Tonsillectomy',
          ),
          _buildTextField(
            label: 'Allergies',
            controller: _allergiesController,
            hint: 'e.g., Penicillin, Peanuts',
          ),
          _buildTextField(
            label: 'Immunizations',
            controller: _immunizationsController,
            hint: 'e.g., MMR, DPT, Polio',
          ),
          _buildTextField(
            label: 'Social History',
            controller: _socialHistoryController,
            hint: 'e.g., Smoking, Alcohol, Exercise',
          ),
          _buildTextField(
            label: 'Review of Systems',
            controller: _reviewOfSystemsController,
            hint: 'Current health complaints',
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveHistory,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Changes'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Approval Buttons
          _buildApprovalButtons(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStatusCard(bool isApproved, bool hasDenial) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isApproved
                      ? Icons.verified
                      : hasDenial
                      ? Icons.cancel
                      : Icons.pending,
                  color: isApproved
                      ? AppColors.success
                      : hasDenial
                      ? AppColors.error
                      : AppColors.warning,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  isApproved
                      ? 'Approved'
                      : hasDenial
                      ? 'Denied'
                      : 'Pending Approval',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isApproved
                        ? AppColors.success
                        : hasDenial
                        ? AppColors.error
                        : AppColors.warning,
                  ),
                ),
              ],
            ),
            if (hasDenial) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Denial Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(_history!.denialReason!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _approveHistory,
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _denyHistory,
            icon: const Icon(Icons.close),
            label: const Text('Deny'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
