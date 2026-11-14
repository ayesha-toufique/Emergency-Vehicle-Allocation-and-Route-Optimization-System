import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/demo_data.dart';
import '../../../core/mock/mock_repository.dart';
import '../../../core/services/api_service.dart';
import '../../../core/widgets/feedback/state_widgets.dart';
import '../../../core/widgets/feedback/status_chip.dart';

class DispatcherAllocationScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const DispatcherAllocationScreen({super.key, this.onNavigateToTab});

  @override
  State<DispatcherAllocationScreen> createState() => _DispatcherAllocationScreenState();
}

class _DispatcherAllocationScreenState extends State<DispatcherAllocationScreen> {
  DemoEmergency? _selectedEmergency;
  DemoVehicle? _selectedVehicle;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = context.watch<MockRepository>();

    final pendingEmergencies = repo.pendingEmergencies;
    final availableVehicles = repo.availableVehicles;

    // Auto-select first pending if none selected
    if (_selectedEmergency == null && pendingEmergencies.isNotEmpty) {
      _selectedEmergency = pendingEmergencies.first;
    } else if (_selectedEmergency != null &&
        !pendingEmergencies.any((e) => e.id == _selectedEmergency!.id)) {
      _selectedEmergency = pendingEmergencies.isNotEmpty ? pendingEmergencies.first : null;
    }

    // Auto-select best matching vehicle if available
    if (_selectedVehicle == null && availableVehicles.isNotEmpty && _selectedEmergency != null) {
      _selectedVehicle = _findBestMatchVehicle(_selectedEmergency!, availableVehicles);
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // DP Algorithm Simulation Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryNavy,
                        AppColors.primaryTeal.withValues(alpha: 0.9),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.aquaAccent.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'DYNAMIC PROGRAMMING (DP) ALLOCATION ASSISTANT',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.aquaAccent,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 22),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Simulated Optimization Engine',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '[SIMULATED DEMO] Dynamic Programming solves knapsack/multi-criteria resource dispatch (Severity × Urgency ÷ Distance). Backend will execute live algorithms via Django REST API.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                if (pendingEmergencies.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: EmptyState(
                        'No Pending Emergencies',
                        subtitle: 'All reported incidents have been allocated to response units.',
                        icon: Icons.check_circle_outline_rounded,
                        action: widget.onNavigateToTab != null
                            ? OutlinedButton.icon(
                                icon: const Icon(Icons.list_alt_rounded),
                                label: const Text('View All Emergencies'),
                                onPressed: () => widget.onNavigateToTab!(1),
                              )
                            : null,
                      ),
                    ),
                  )
                else ...[
                  // Step 1: Select Pending Incident
                  Text(
                    '1. Select Pending Emergency Request',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 125,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: pendingEmergencies.length,
                      itemBuilder: (context, index) {
                        final item = pendingEmergencies[index];
                        final isSelected = _selectedEmergency?.id == item.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedEmergency = item;
                              _selectedVehicle = _findBestMatchVehicle(item, availableVehicles);
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 295,
                            margin: const EdgeInsets.only(right: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primaryTeal : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                width: isSelected ? 2.5 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isSelected
                                      ? AppColors.primaryTeal.withValues(alpha: 0.2)
                                      : Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item.id,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primaryTeal,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.forCategory(item.category).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.category,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.forCategory(item.category),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  item.locationLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 13, color: AppColors.forSeverity(item.severity)),
                                    const SizedBox(width: 2),
                                    Text('Sev ${item.severity}', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.people_outline_rounded, size: 13, color: Colors.grey),
                                    const SizedBox(width: 2),
                                    Text('${item.peopleAffected} pers', style: GoogleFonts.inter(fontSize: 10)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Step 2: Algorithmic Recommendation Details
                  if (_selectedEmergency != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryTeal.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryTeal, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'DP Optimization Recommendation',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryTeal,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.statusCompleted.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Optimal Match Score: 96%',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.statusCompleted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getRecommendationExplanation(_selectedEmergency!),
                            style: GoogleFonts.inter(fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Step 3: Available Vehicles Selection
                    Text(
                      '2. Choose Response Unit to Dispatch',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),

                    if (availableVehicles.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No vehicles currently available. All units are currently busy or en route.',
                          style: TextStyle(color: Colors.red),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: availableVehicles.length,
                        itemBuilder: (context, idx) {
                          final vehicle = availableVehicles[idx];
                          final isSelected = _selectedVehicle?.id == vehicle.id;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedVehicle = vehicle),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primaryTeal
                                      : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? AppColors.primaryTeal.withValues(alpha: 0.15)
                                        : Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.primaryTeal : Colors.grey.withValues(alpha: 0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primaryTeal,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryNavy.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      vehicle.type.contains('Fire')
                                          ? Icons.fire_truck_rounded
                                          : vehicle.type.contains('Rescue')
                                              ? Icons.airport_shuttle_rounded
                                              : Icons.emergency_rounded,
                                      color: AppColors.primaryNavy,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              vehicle.licensePlate,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            StatusChip(status: vehicle.status.toUpperCase()),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${vehicle.type} · Driver: ${vehicle.driverName ?? "Available Pool"}',
                                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '~6-8 min ETA',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primaryTeal,
                                        ),
                                      ),
                                      Text(
                                        'Simulated Distance: ~3.2 km',
                                        style: GoogleFonts.inter(fontSize: 10, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 24),

                    // Confirm Assignment Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: (_selectedEmergency == null || _selectedVehicle == null || _isProcessing)
                          ? null
                          : () async {
                              setState(() => _isProcessing = true);
                              
                              // Trigger backend DP allocation sync in background if online
                              try {
                                final emergencyIdInt = int.tryParse(
                                  _selectedEmergency!.id.replaceAll(RegExp(r'[^0-9]'), ''),
                                );
                                await ApiService().triggerAllocation(emergencyId: emergencyIdInt);
                              } catch (_) {}

                              repo.assignVehicleToEmergency(
                                _selectedEmergency!.id,
                                _selectedVehicle!.id,
                                notes: 'Dispatched via DP allocation assistant to ${_selectedEmergency!.locationLabel}',
                              );

                              if (!context.mounted) return;
                              setState(() {
                                _isProcessing = false;
                                _selectedEmergency = null;
                                _selectedVehicle = null;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.statusCompleted,
                                  content: Text('Vehicle successfully dispatched! Assignment confirmed in shared repository.'),
                                ),
                              );
                            },
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.send_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Confirm Assignment & Dispatch Unit',
                                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  DemoVehicle? _findBestMatchVehicle(DemoEmergency emergency, List<DemoVehicle> vehicles) {
    if (vehicles.isEmpty) return null;

    if (emergency.category == EmergencyCategory.fire) {
      final fire = vehicles.where((v) => v.type.contains('Fire'));
      if (fire.isNotEmpty) return fire.first;
    } else if (emergency.category == EmergencyCategory.rescue) {
      final rescue = vehicles.where((v) => v.type.contains('Rescue'));
      if (rescue.isNotEmpty) return rescue.first;
    }

    // Default to Ambulance or first available
    final amb = vehicles.where((v) => v.type.contains('Ambulance'));
    if (amb.isNotEmpty) return amb.first;

    return vehicles.first;
  }

  String _getRecommendationExplanation(DemoEmergency emergency) {
    if (emergency.category == EmergencyCategory.medical) {
      return 'Selected Medical Transport based on reported patient injury and vital support requirements. Proximity algorithm estimated shortest traversal route through Karachi central sector.';
    } else if (emergency.category == EmergencyCategory.fire) {
      return 'Prioritized Fire Brigade unit with foam dispersion capability. High severity rating (${emergency.severity}/5) elevates dispatch priority above non-structural calls.';
    } else if (emergency.category == EmergencyCategory.accident) {
      return 'Dispatched Rescue vehicle equipped with hydraulic extrication tools and dual paramedic trauma kits for vehicular collision triage.';
    }
    return 'Allocated highest-ranked available response unit considering latency score and equipment readiness.';
  }
}
