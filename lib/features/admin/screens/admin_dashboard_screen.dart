import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/mock/mock_repository.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/cards/dashboard_card.dart';

class AdminDashboardScreen extends StatelessWidget {
  final Function(int tabIndex)? onNavigateToTab;

  const AdminDashboardScreen({super.key, this.onNavigateToTab});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = context.watch<SessionService>();
    final repo = context.watch<MockRepository>();

    final totalEmergencies = repo.emergencies.length;
    final activeEmergencies = repo.activeEmergencies.length;
    final resolvedEmergencies = repo.resolvedEmergencies.length;

    final totalVehicles = repo.vehicles.length;
    final availableVehicles = repo.availableVehicles.length;

    final totalUsers = repo.accounts.length;
    final citizensCount = repo.totalCitizensCount;
    final staffCount = repo.totalDispatchersCount + repo.totalDriversCount;

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Executive Admin Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'SYSTEM ADMINISTRATION · MASTER CONTROL',
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
                              'Global operations overview, staff provisioning, fleet telemetry and resource audit',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Primary Metrics Grid
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
                            title: 'Total Users',
                            value: '$totalUsers',
                            icon: Icons.people_rounded,
                            iconColor: AppColors.primaryTeal,
                            subtitle: '$citizensCount citizens · $staffCount staff',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: DashboardCard(
                            title: 'Active Incidents',
                            value: '$activeEmergencies',
                            icon: Icons.crisis_alert_rounded,
                            iconColor: AppColors.emergencyPink,
                            subtitle: '$resolvedEmergencies resolved',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: DashboardCard(
                            title: 'Fleet Ready',
                            value: '$availableVehicles / $totalVehicles',
                            icon: Icons.local_shipping_rounded,
                            iconColor: AppColors.statusCompleted,
                            subtitle: '${totalVehicles - availableVehicles} in operation',
                          ),
                        ),
                        SizedBox(
                          width: cardWidth,
                          child: DashboardCard(
                            title: 'Resources Logged',
                            value: '${repo.resources.length}',
                            icon: Icons.inventory_2_rounded,
                            iconColor: AppColors.statusAssigned,
                            subtitle: 'Equipment & crew',
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Quick Navigation Cards
                Text(
                  'Administrative Modules',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final int crossAxisCount = width > 768 ? 4 : (width > 380 ? 2 : 1);
                    final double aspectRatio = width > 768 ? 1.6 : (width > 380 ? 1.25 : 2.0);

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: aspectRatio,
                      children: [
                        _buildAdminTile(
                          icon: Icons.badge_rounded,
                          title: 'Staff Management',
                          subtitle: 'Provision Dispatchers & Drivers',
                          badge: '$staffCount Staff',
                          onTap: () {
                            if (onNavigateToTab != null) onNavigateToTab!(1);
                          },
                          isDark: isDark,
                        ),
                        _buildAdminTile(
                          icon: Icons.directions_car_filled_rounded,
                          title: 'Fleet Management',
                          subtitle: 'Add & monitor vehicles',
                          badge: '$totalVehicles Units',
                          onTap: () {
                            if (onNavigateToTab != null) onNavigateToTab!(2);
                          },
                          isDark: isDark,
                        ),
                        _buildAdminTile(
                          icon: Icons.inventory_rounded,
                          title: 'Resource Allocation',
                          subtitle: 'Oxygen, trauma, fuel & crew',
                          badge: '${repo.resources.length} Items',
                          onTap: () {
                            if (onNavigateToTab != null) onNavigateToTab!(3);
                          },
                          isDark: isDark,
                        ),
                        _buildAdminTile(
                          icon: Icons.insights_rounded,
                          title: 'System Analytics',
                          subtitle: 'Performance & incident charts',
                          badge: '$totalEmergencies Reports',
                          onTap: () {
                            if (onNavigateToTab != null) onNavigateToTab!(4);
                          },
                          isDark: isDark,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // System Health & Infrastructure Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.dns_rounded, color: AppColors.primaryTeal, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'System Health & Infrastructure Telemetry',
                                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.statusCompleted.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ALL OPERATIONAL',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.statusCompleted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildHealthRow('Central Dispatch Hub', 'Active · Latency: 4ms [SIMULATED]', true),
                        _buildHealthRow('Dynamic Programming Engine', 'Ready for batch allocation [SIMULATED]', true),
                        _buildHealthRow('OpenStreetMap Tile Cache', 'Karachi Metropolitan sector cached', true),
                        _buildHealthRow('Backend Django Integration Layer', 'Ready for REST API Client hook', true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppColors.primaryTeal, size: 20),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryNavy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthRow(String label, String status, bool isHealthy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isHealthy ? Icons.check_circle_rounded : Icons.error_rounded,
                      size: 14,
                      color: isHealthy ? AppColors.statusCompleted : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 2),
                  child: Text(
                    status,
                    style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Icon(
                isHealthy ? Icons.check_circle_rounded : Icons.error_rounded,
                size: 16,
                color: isHealthy ? AppColors.statusCompleted : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text(
                  status,
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
