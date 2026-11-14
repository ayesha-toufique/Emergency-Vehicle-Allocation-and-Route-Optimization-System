import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_repository.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/cards/dashboard_card.dart';
import '../../../core/widgets/feedback/status_chip.dart';

class DriverDashboardScreen extends StatefulWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const DriverDashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  bool _isOnDuty = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = context.watch<SessionService>();
    final repo = context.watch<MockRepository>();

    final activeMission = repo.getActiveMissionForDriver(session.userName);
    final history = repo.getMissionHistoryForDriver(session.userName);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Driver Header & Duty Toggle
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryTeal.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_shipping_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'FIELD RESPONDER · DEMO DRIVER',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  session.userName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Assigned Unit: Ambulance KHI-1122-AMB',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24, color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _isOnDuty ? AppColors.statusCompleted : AppColors.statusMaintenance,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isOnDuty ? 'STATUS: ON DUTY' : 'STATUS: OFF DUTY',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOnDuty,
                            activeThumbColor: AppColors.aquaAccent,
                            onChanged: (val) {
                              setState(() => _isOnDuty = val);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  duration: const Duration(seconds: 1),
                                  content: Text(val ? 'You are now ON DUTY.' : 'You are now OFF DUTY.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Metrics Grid
                Row(
                  children: [
                    Expanded(
                      child: DashboardCard(
                        title: 'Active Mission',
                        value: activeMission != null ? '1 Active' : 'None',
                        icon: Icons.emergency_rounded,
                        iconColor: activeMission != null ? AppColors.emergencyPink : AppColors.primaryTeal,
                        subtitle: activeMission != null ? activeMission.category : 'Standing By',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardCard(
                        title: 'Completed Today',
                        value: '${history.length}',
                        icon: Icons.task_alt_rounded,
                        iconColor: AppColors.statusCompleted,
                        subtitle: 'Resolved incidents',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Current Active Mission Card
                Text(
                  'Current Active Mission',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),

                if (activeMission == null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded, size: 48, color: AppColors.statusCompleted),
                        const SizedBox(height: 12),
                        Text(
                          'No Active Emergency Assigned',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are on standby at Karachi Central Depot. You will be alerted immediately when Dispatcher allocates a mission.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.emergencyPink, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emergencyPink.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.forCategory(activeMission.category).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                activeMission.category,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.forCategory(activeMission.category),
                                ),
                              ),
                            ),
                            StatusChip(status: activeMission.status),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          activeMission.id,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeMission.locationLabel,
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          activeMission.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 13),
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Severity: ${activeMission.severity}/5 · ${activeMission.peopleAffected} Affected',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                                  ),
                                  Text(
                                    'Simulated ETA: ~6 mins (2.8 km)',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryTeal),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryTeal,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(Icons.navigation_rounded, size: 16),
                              label: const Text('Open Mission', style: TextStyle(fontSize: 12)),
                              onPressed: () {
                                if (widget.onNavigateToTab != null) {
                                  widget.onNavigateToTab!(1); // Navigate to Mission tab
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Quick Navigation Tiles
                Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.navigation_rounded,
                        title: 'Navigation',
                        subtitle: 'Karachi Route Map',
                        onTap: () {
                          if (widget.onNavigateToTab != null) widget.onNavigateToTab!(2);
                        },
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickAction(
                        icon: Icons.history_rounded,
                        title: 'Mission History',
                        subtitle: 'Resolved Calls',
                        onTap: () {
                          if (widget.onNavigateToTab != null) widget.onNavigateToTab!(3);
                        },
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primaryTeal, size: 24),
              ),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
