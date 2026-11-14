import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/session_service.dart';
import '../../../core/widgets/brand/resq_app_bar.dart';

// Citizen Screens
import '../../citizen/screens/citizen_home_screen.dart';
import '../../citizen/screens/citizen_profile_screen.dart';
import '../../citizen/screens/my_reports_screen.dart';
import '../../citizen/screens/report_emergency_screen.dart';

// Dispatcher Screens
import '../../dispatcher/screens/dispatcher_allocation_screen.dart';
import '../../dispatcher/screens/dispatcher_dashboard_screen.dart';
import '../../dispatcher/screens/dispatcher_emergency_screen.dart';
import '../../dispatcher/screens/dispatcher_map_screen.dart';
import '../../dispatcher/screens/dispatcher_notifications_screen.dart';
import '../../dispatcher/screens/dispatcher_profile_screen.dart';
import '../../dispatcher/screens/dispatcher_vehicles_screen.dart';

// Driver Screens
import '../../driver/screens/driver_dashboard_screen.dart';
import '../../driver/screens/driver_history_screen.dart';
import '../../driver/screens/driver_mission_screen.dart';
import '../../driver/screens/driver_navigation_screen.dart';
import '../../driver/screens/driver_notifications_screen.dart';
import '../../driver/screens/driver_profile_screen.dart';

// Admin Screens
import '../../admin/screens/admin_dashboard_screen.dart';
import '../../admin/screens/admin_profile_screen.dart';
import '../../admin/screens/admin_reports_screen.dart';
import '../../admin/screens/admin_resources_screen.dart';
import '../../admin/screens/admin_staff_screen.dart';
import '../../admin/screens/admin_vehicles_screen.dart';

class NavTabItem {
  final String label;
  final IconData icon;
  final Widget Function() builder;

  const NavTabItem({
    required this.label,
    required this.icon,
    required this.builder,
  });
}

class RoleShell extends StatefulWidget {
  final String initialRole;

  const RoleShell({super.key, required this.initialRole});

  @override
  State<RoleShell> createState() => _RoleShellState();
}

class _RoleShellState extends State<RoleShell> {
  int _currentIndex = 0;

  Map<String, List<NavTabItem>> get _roleTabConfigs => {
        'citizen': [
          NavTabItem(
            label: 'Home',
            icon: Icons.home_rounded,
            builder: () => CitizenHomeScreen(
              onNavigateToReport: () => setState(() => _currentIndex = 1),
              onNavigateToReportsList: () => setState(() => _currentIndex = 2),
            ),
          ),
          NavTabItem(
            label: 'Report',
            icon: Icons.add_alert_rounded,
            builder: () => const ReportEmergencyScreen(),
          ),
          NavTabItem(
            label: 'My Reports',
            icon: Icons.list_alt_rounded,
            builder: () => MyReportsScreen(
              onNavigateToReport: () => setState(() => _currentIndex = 1),
            ),
          ),
          NavTabItem(
            label: 'Profile',
            icon: Icons.person_rounded,
            builder: () => const CitizenProfileScreen(),
          ),
        ],
        'dispatcher': [
          NavTabItem(
            label: 'Dashboard',
            icon: Icons.dashboard_rounded,
            builder: () => DispatcherDashboardScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Queue',
            icon: Icons.emergency_rounded,
            builder: () => DispatcherEmergencyScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Operations Map',
            icon: Icons.map_rounded,
            builder: () => DispatcherMapScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Allocation',
            icon: Icons.account_tree_rounded,
            builder: () => DispatcherAllocationScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Fleet',
            icon: Icons.local_shipping_rounded,
            builder: () => DispatcherVehiclesScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Alerts',
            icon: Icons.notifications_rounded,
            builder: () => DispatcherNotificationsScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Profile',
            icon: Icons.person_rounded,
            builder: () => const DispatcherProfileScreen(),
          ),
        ],
        'driver': [
          NavTabItem(
            label: 'Home',
            icon: Icons.home_rounded,
            builder: () => DriverDashboardScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Mission',
            icon: Icons.assignment_rounded,
            builder: () => DriverMissionScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Navigation',
            icon: Icons.navigation_rounded,
            builder: () => DriverNavigationScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'History',
            icon: Icons.history_rounded,
            builder: () => DriverHistoryScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Alerts',
            icon: Icons.notifications_rounded,
            builder: () => DriverNotificationsScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Profile',
            icon: Icons.person_rounded,
            builder: () => const DriverProfileScreen(),
          ),
        ],
        'admin': [
          NavTabItem(
            label: 'Dashboard',
            icon: Icons.dashboard_rounded,
            builder: () => AdminDashboardScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Staff & Users',
            icon: Icons.people_rounded,
            builder: () => AdminStaffScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Fleet',
            icon: Icons.local_shipping_rounded,
            builder: () => AdminVehiclesScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Resources',
            icon: Icons.inventory_2_rounded,
            builder: () => AdminResourcesScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Reports',
            icon: Icons.insights_rounded,
            builder: () => AdminReportsScreen(
              onNavigateToTab: (idx) => setState(() => _currentIndex = idx),
            ),
          ),
          NavTabItem(
            label: 'Profile',
            icon: Icons.person_rounded,
            builder: () => const AdminProfileScreen(),
          ),
        ],
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = context.watch<SessionService>();
    final currentRole = session.role ?? widget.initialRole;
    final tabs = _roleTabConfigs[currentRole] ?? _roleTabConfigs['citizen']!;

    if (_currentIndex >= tabs.length) {
      _currentIndex = 0;
    }

    final activeTab = tabs[_currentIndex];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;

        return Scaffold(
          appBar: ResQAppBar(
            subtitle: '${currentRole.toUpperCase()} · ${activeTab.label}',
            showBackButton: false,
          ),
          body: Row(
            children: [
              // Tablet / Desktop Navigation Rail / Sidebar
              if (isDesktop || isTablet)
                NavigationRail(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
                  labelType: isDesktop ? null : NavigationRailLabelType.all,
                  extended: isDesktop,
                  minExtendedWidth: 180,
                  backgroundColor: Theme.of(context).cardTheme.color,
                  selectedIconTheme: const IconThemeData(color: Colors.white),
                  unselectedIconTheme: IconThemeData(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  selectedLabelTextStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryTeal,
                  ),
                  unselectedLabelTextStyle: GoogleFonts.inter(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  destinations: tabs.map((t) {
                    return NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(t.icon, color: Colors.white, size: 20),
                      ),
                      label: Text(t.label),
                    );
                  }).toList(),
                ),

              // Main Tab Content
              Expanded(
                child: activeTab.builder(),
              ),
            ],
          ),

          // Mobile Bottom Navigation Bar (< 600 px)
          bottomNavigationBar: (!isDesktop && !isTablet)
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        ),
                      ),
                    ),
                    child: Row(
                      children: List.generate(tabs.length, (n) {
                        final isSelected = _currentIndex == n;
                        final tab = tabs[n];

                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _currentIndex = n),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                gradient: isSelected ? AppColors.primaryGradient : null,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryTeal.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    tab.icon,
                                    size: tabs.length >= 6 ? 18 : 19,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.lightTextSecondary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tabs.length >= 6 && tab.label == 'Staff & Users'
                                        ? 'Staff'
                                        : (tabs.length >= 6 && tab.label == 'Operations Map'
                                            ? 'Map'
                                            : tab.label),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: tabs.length >= 6 ? 8.8 : 10.0,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? AppColors.darkTextSecondary
                                              : AppColors.lightTextSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
