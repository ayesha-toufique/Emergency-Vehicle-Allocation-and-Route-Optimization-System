import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/demo_data.dart';
import '../../../core/mock/mock_repository.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/cards/dashboard_card.dart';
import '../../../core/widgets/feedback/status_chip.dart';

class DispatcherDashboardScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const DispatcherDashboardScreen({
    super.key,
    this.onNavigateToTab,
  });

  void _showIncidentDetails(BuildContext context, DemoEmergency emergency) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(
                controller: scrollCtrl,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        emergency.id,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      StatusChip(status: emergency.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    emergency.category,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    emergency.description,
                    style: GoogleFonts.inter(fontSize: 13, height: 1.4),
                  ),
                  const Divider(height: 24),
                  _buildDetailRow('Location', emergency.locationLabel, Icons.place_rounded),
                  _buildDetailRow('Severity', '${emergency.severity} / 5', Icons.warning_amber_rounded),
                  _buildDetailRow('Urgency', '${emergency.urgency} / 5', Icons.timer_outlined),
                  _buildDetailRow('People Affected', '${emergency.peopleAffected}', Icons.people_outline_rounded),
                  if (emergency.assignedVehicle != null)
                    _buildDetailRow('Assigned Unit', '${emergency.assignedVehicle!.type} (${emergency.assignedVehicle!.licensePlate})', Icons.local_shipping_rounded),
                  const SizedBox(height: 20),
                  if (emergency.status == EmergencyStatus.reported)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primaryTeal),
                      icon: const Icon(Icons.account_tree_rounded, size: 18),
                      label: const Text('Open Allocation Assistant'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (onNavigateToTab != null) onNavigateToTab!(3); // Allocation tab
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryTeal),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = context.watch<SessionService>();
    final repo = context.watch<MockRepository>();

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
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
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'DISPATCH CONTROL · KARACHI SECTOR',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Welcome, ${session.userName}',
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Live emergency operations dashboard and DP resource triage',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.headset_mic_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Metrics Grid (2x2 on mobile, 4-col on tablet/desktop)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final int crossAxisCount = width > 768 ? 4 : (width > 340 ? 2 : 1);
                    final cardWidth = (width - ((crossAxisCount - 1) * 12)) / crossAxisCount;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: DashboardCard(
                            title: 'Total Emergencies',
                            value: '${repo.emergencies.length}',
                            icon: Icons.emergency_rounded,
                            iconColor: AppColors.primaryTeal,
                            subtitle: 'All sectors',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: DashboardCard(
                            title: 'Pending Triage',
                            value: '${repo.pendingEmergencies.length}',
                            icon: Icons.pending_actions_rounded,
                            iconColor: AppColors.statusPending,
                            subtitle: 'Action required',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: DashboardCard(
                            title: 'Assigned / En Route',
                            value: '${repo.assignedEmergencies.length}',
                            icon: Icons.local_shipping_rounded,
                            iconColor: AppColors.statusAssigned,
                            subtitle: 'Active units',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: DashboardCard(
                            title: 'Fleet Available',
                            value: '${repo.availableVehicles.length} / ${repo.vehicles.length}',
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: AppColors.statusCompleted,
                            subtitle: 'Ready to deploy',
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Active Alerts Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.emergencyPink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.emergencyPink.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.emergencyPink, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TRAFFIC ALERT: M.A. Jinnah Road Blocked',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.emergencyPink,
                              ),
                            ),
                            Text(
                              'Waterline rupture near Tibet Centre. Dijkstra routing is bypassing this road segment.',
                              style: GoogleFonts.inter(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // Quick Navigation Tiles
                Text(
                  'Quick Dispatch Actions',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildNavTile(
                      context,
                      title: 'Queue & Triage',
                      icon: Icons.format_list_bulleted_rounded,
                      color: AppColors.statusPending,
                      onTap: () => onNavigateToTab?.call(1),
                    ),
                    const SizedBox(width: 10),
                    _buildNavTile(
                      context,
                      title: 'Operations Map',
                      icon: Icons.map_rounded,
                      color: AppColors.primaryTeal,
                      onTap: () => onNavigateToTab?.call(2),
                    ),
                    const SizedBox(width: 10),
                    _buildNavTile(
                      context,
                      title: 'DP Allocation',
                      icon: Icons.account_tree_rounded,
                      color: AppColors.infoCyan,
                      onTap: () => onNavigateToTab?.call(3),
                    ),
                    const SizedBox(width: 10),
                    _buildNavTile(
                      context,
                      title: 'Fleet Status',
                      icon: Icons.directions_car_rounded,
                      color: AppColors.emergencyPurple,
                      onTap: () => onNavigateToTab?.call(4),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Live Emergency Feed
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Live Emergency Feed',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    TextButton(
                      onPressed: () => onNavigateToTab?.call(1),
                      child: Text(
                        'View All (${repo.emergencies.length})',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryTeal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                ...repo.emergencies.take(4).map((e) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      onTap: () => _showIncidentDetails(context, e),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.emergency_rounded, color: AppColors.primaryTeal, size: 20),
                      ),
                      title: Row(
                        children: [
                          Text(e.id, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryTeal)),
                          const SizedBox(width: 6),
                          Text('· ${e.category}', style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      subtitle: Text(
                        '${e.locationLabel}\n${e.description}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                      trailing: StatusChip(status: e.status),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavTile(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
