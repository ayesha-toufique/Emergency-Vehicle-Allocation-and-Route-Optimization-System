import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/mock/demo_data.dart';
import '../../../core/mock/mock_repository.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/brand/resq_app_bar.dart';
import '../../../core/widgets/buttons/primary_gradient_button.dart';
import '../../../core/widgets/inputs/custom_text_field.dart';

class ReportEmergencyScreen extends StatefulWidget {
  final String? initialCategory;
  final bool isStandalone;

  const ReportEmergencyScreen({
    super.key,
    this.initialCategory,
    this.isStandalone = false,
  });

  @override
  State<ReportEmergencyScreen> createState() => _ReportEmergencyScreenState();
}

class _ReportEmergencyScreenState extends State<ReportEmergencyScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _selectedCategory;
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  int _severity = 3; // 1 to 5
  int _urgency = 3; // 1 to 5
  int _peopleAffected = 1;

  // Map and Location state
  LatLng _selectedLocation = AppConstants.defaultLocation;
  final MapController _mapController = MapController();
  bool _isDetectingGps = false;
  String? _gpsStatusMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? EmergencyCategory.medical;
    _addressController.text = 'Saddar, Karachi (Near Empress Market)';
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _detectGpsLocation() async {
    setState(() {
      _isDetectingGps = true;
      _gpsStatusMessage = 'Requesting device GPS permission...';
    });

    final result = await LocationService.getCurrentLocation();

    if (!mounted) return;

    if (result.isSuccess && result.position != null) {
      setState(() {
        _isDetectingGps = false;
        _selectedLocation = result.position!;
        _gpsStatusMessage = 'GPS location acquired successfully!';
        _addressController.text =
            'Detected GPS Location (${result.position!.latitude.toStringAsFixed(4)}, ${result.position!.longitude.toStringAsFixed(4)})';
      });
      _mapController.move(_selectedLocation, 15.0);
    } else {
      setState(() {
        _isDetectingGps = false;
        _gpsStatusMessage =
            result.error ?? 'Location unavailable. You can tap anywhere on the map to place your pin manually.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.statusPending,
          content: Text(
            result.error ?? 'GPS unavailable. Manual map pin enabled.',
            style: const TextStyle(fontSize: 12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
      _addressController.text =
          'Pin: ${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)} (Karachi)';
      _gpsStatusMessage = 'Location manually set by pin tap.';
    });
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = context.read<MockRepository>();
      final session = context.read<SessionService>();

      final apiService = ApiService();
      final response = await apiService.reportEmergency(
        category: _selectedCategory,
        severity: _severity,
        urgency: _urgency,
        peopleAffected: _peopleAffected,
        description: _descriptionController.text.trim().isEmpty
            ? 'Emergency report in $_selectedCategory category.'
            : _descriptionController.text.trim(),
        location: _selectedLocation,
        locationLabel: _addressController.text.trim().isEmpty
            ? 'Karachi Grid Location'
            : _addressController.text.trim(),
        userId: session.userName,
        mockRepo: repo,
      );

      final newEmergency = response.data ?? repo.emergencies.first;

      if (!mounted) return;

      _showSuccessDialog(newEmergency);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessDialog(DemoEmergency emergency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primaryTeal,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Report Dispatched!',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EMERGENCY ID: ${emergency.id}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Category: ${emergency.category} · Priority Triage Initiated',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your emergency has been received by Karachi Dispatch. [DEMO SIMULATION]',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.isStandalone && context.canPop()) {
                context.pop();
              } else {
                context.go('/role-shell');
              }
            },
            child: const Text('Back to Home'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryTeal),
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/citizen/details/${emergency.id}');
            },
            child: const Text('Track Status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step 1: Emergency Category
                Text(
                  '1. Select Emergency Type',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildCategoryChoice(
                      category: EmergencyCategory.medical,
                      label: 'Medical',
                      icon: Icons.medical_services_rounded,
                      color: AppColors.infoCyan,
                    ),
                    _buildCategoryChoice(
                      category: EmergencyCategory.fire,
                      label: 'Fire Hazard',
                      icon: Icons.local_fire_department_rounded,
                      color: const Color(0xFFE65100),
                    ),
                    _buildCategoryChoice(
                      category: EmergencyCategory.accident,
                      label: 'Road Accident',
                      icon: Icons.car_crash_rounded,
                      color: AppColors.emergencyPink,
                    ),
                    _buildCategoryChoice(
                      category: EmergencyCategory.rescue,
                      label: 'Rescue / Other',
                      icon: Icons.support_rounded,
                      color: AppColors.emergencyPurple,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Step 2: Location on Karachi 2D Map
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '2. Incident Location',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        side: const BorderSide(color: AppColors.primaryTeal),
                      ),
                      onPressed: _isDetectingGps ? null : _detectGpsLocation,
                      icon: _isDetectingGps
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 16, color: AppColors.primaryTeal),
                      label: Text(
                        _isDetectingGps ? 'Locating...' : 'Use My GPS',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap anywhere on the Karachi 2D map to adjust your emergency marker:',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // Map Container
                Container(
                  height: 220,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _selectedLocation,
                          initialZoom: 13.0,
                          onTap: _onMapTap,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.resq.resq_app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _selectedLocation,
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.emergencyPink,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.place_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Karachi Map · Tap to relocate pin',
                            style: GoogleFonts.inter(fontSize: 10, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_gpsStatusMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _gpsStatusMessage!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                CustomTextField(
                  controller: _addressController,
                  label: 'Address / Landmark',
                  hint: 'e.g. Near Empress Market, Saddar',
                  prefixIcon: Icons.location_city_rounded,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please specify location' : null,
                ),

                const SizedBox(height: 20),

                // Step 3: Severity & Urgency
                Text(
                  '3. Severity & Impact Details',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Severity Level',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getSeverityColor(_severity).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Level $_severity / 5',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _getSeverityColor(_severity),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _severity.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: _getSeverityColor(_severity),
                          label: 'Level $_severity',
                          onChanged: (val) => setState(() => _severity = val.round()),
                        ),
                        const SizedBox(height: 8),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Urgency Rating',
                              style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Rating $_urgency / 5',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Slider(
                          value: _urgency.toDouble(),
                          min: 1,
                          max: 5,
                          divisions: 4,
                          activeColor: AppColors.primaryTeal,
                          label: 'Urgency $_urgency',
                          onChanged: (val) => setState(() => _urgency = val.round()),
                        ),
                        const SizedBox(height: 12),

                        // People Affected Stepper
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'People Affected',
                                  style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Estimated number of injured or stranded individuals',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline_rounded),
                                  onPressed: _peopleAffected > 1
                                      ? () => setState(() => _peopleAffected--)
                                      : null,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                    ),
                                  ),
                                  child: Text(
                                    '$_peopleAffected',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline_rounded),
                                  color: AppColors.primaryTeal,
                                  onPressed: () => setState(() => _peopleAffected++),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Step 4: Description
                CustomTextField(
                  controller: _descriptionController,
                  label: 'Situation Description (Optional)',
                  hint: 'Describe what happened, any visible hazards, or specific medical needs...',
                  prefixIcon: Icons.notes_rounded,
                  maxLines: 3,
                ),

                const SizedBox(height: 24),

                // Submit CTA
                PrimaryGradientButton(
                  label: 'SUBMIT EMERGENCY REPORT',
                  isLoading: _isSubmitting,
                  onPressed: _submitReport,
                ),

                const SizedBox(height: 12),

                Center(
                  child: Text(
                    '⚠️ ResQ Frontend Prototype · Simulated Karachi Dispatch Queue',
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        appBar: const ResQAppBar(
          subtitle: 'Report Emergency',
          showBackButton: true,
        ),
        body: content,
      );
    }

    return Scaffold(body: content);
  }

  Widget _buildCategoryChoice({
    required String category,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = category),
        borderRadius: BorderRadius.circular(12),
        child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.15)
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.lightTextNavy)
                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Color _getSeverityColor(int level) {
    switch (level) {
      case 5:
        return AppColors.emergencyPink;
      case 4:
        return const Color(0xFFE65100);
      case 3:
        return AppColors.statusPending;
      case 2:
        return AppColors.statusAssigned;
      default:
        return AppColors.statusCompleted;
    }
  }
}
