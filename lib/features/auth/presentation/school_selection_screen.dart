import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/bloom_components.dart';

class SchoolSelectionScreen extends StatefulWidget {
  const SchoolSelectionScreen({super.key});

  @override
  State<SchoolSelectionScreen> createState() => _SchoolSelectionScreenState();
}

class _SchoolSelectionScreenState extends State<SchoolSelectionScreen> {
  final _searchCtrl = TextEditingController();
  String? _selectedSchool;
  List<String> _schools = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSchools();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSchools() async {
    try {
      final data = await Supabase.instance.client
          .from('schools')
          .select('name')
          .order('name', ascending: true);
      final rawNames = (data as List).map((e) => e['name'] as String).toList();
      // Dedupe defensively (case-insensitive, trimmed) — the schools table
      // can end up with duplicate name rows (e.g. re-seeded data), and a
      // repeated entry in this list is confusing during onboarding.
      final seen = <String>{};
      final names = <String>[];
      for (final raw in rawNames) {
        final trimmed = raw.trim();
        if (seen.add(trimmed.toLowerCase())) names.add(trimmed);
      }
      if (mounted) {
        setState(() {
          _schools = names;
          _selectedSchool = names.isNotEmpty ? names.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load schools: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  List<String> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _schools;
    return _schools.where((s) => s.toLowerCase().contains(q)).toList();
  }

  Future<void> _confirmSchool() async {
    if (_selectedSchool == null || _isSaving) return;
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        // `profiles` has no `school` column — it's `school_id` (uuid,
        // references `schools.id`). This upsert previously sent a raw
        // school *name* under a column that doesn't exist at all, so it
        // always failed with a Postgrest "column not found" error caught
        // below as "Failed: ...". Resolve the name to its id first. Note
        // `schools.name` isn't unique in the seed data (a few names have
        // duplicate rows with different ids) — this takes the first match,
        // which is a pre-existing data-quality issue, not something fixed
        // here.
        final schoolRow = await Supabase.instance.client
            .from('schools')
            .select('id')
            .eq('name', _selectedSchool!)
            .limit(1)
            .maybeSingle();
        final schoolId = schoolRow?['id'] as String?;
        await Supabase.instance.client
            .from('profiles')
            .upsert({'id': userId, if (schoolId != null) 'school_id': schoolId})
            .select('id');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/student-dashboard');
          });
        }
      } else {
        if (mounted) Navigator.pop(context, _selectedSchool);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  static const _avatarColors = [
    AppColors.success,
    AppColors.primaryLight,
    AppColors.primaryDark,
    AppColors.primary,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
          children: [
            // Header
            const BloomScreenHeader(title: 'Select your school'),

            // Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: BloomSearchField(
                hint: 'Search schools…',
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
              ),
            ),

            // Section label
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'All schools',
                  style: BloomTextStyles.inter(
                    size: 15,
                    weight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),

            // School list
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: BloomCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 6,
                  ),
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : _schools.isEmpty
                      ? Center(
                          child: Text(
                            'No schools found',
                            style: BloomTextStyles.inter(
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final s = _filtered[i];
                            final selected = s == _selectedSchool;
                            final color =
                                _avatarColors[i % _avatarColors.length];
                            return GestureDetector(
                              onTap: () => setState(() => _selectedSchool = s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                ),
                                decoration: i < _filtered.length - 1
                                    ? const BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: AppColors.border,
                                            width: 1,
                                          ),
                                        ),
                                      )
                                    : null,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.school_outlined,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s,
                                            style: BloomTextStyles.inter(
                                              size: 12.5,
                                              weight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            'Tap to select',
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
                                        child: const Icon(
                                          Icons.check,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),

            // Continue CTA
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: BloomButton(
                label: _isSaving ? 'Saving…' : 'Continue',
                isLoading: _isSaving,
                onPressed: _selectedSchool != null && !_isSaving
                    ? _confirmSchool
                    : null,
              ),
            ),
          ],
            ),
          ),
        ),
      ),
    );
  }
}
