import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';

/// Sidebar entries. `key` matches the `menu` keys the API returns per role,
/// so each role sees exactly the sections the web panel gives it.
class MenuItem {
  const MenuItem(this.key, this.label, this.icon, this.route, this.section, {this.countKey});

  final String key;
  final String label;
  final IconData icon;
  final String route;
  final String section;
  final String? countKey;
}

const kMenuItems = <MenuItem>[
  MenuItem('dashboard', 'Dashboard', Icons.space_dashboard_outlined, AppRoutes.dashboard, 'OVERVIEW'),
  MenuItem('ecg_records', 'ECG Records', Icons.monitor_heart_outlined, AppRoutes.ecgRecords, 'CLINICAL', countKey: 'ecg_records'),
  MenuItem('download_ecg', 'Download ECG', Icons.download_rounded, AppRoutes.downloadEcg, 'CLINICAL'),
  MenuItem('export_ecg_counts', 'Export ECG Counts', Icons.table_chart_outlined, AppRoutes.exportCounts, 'CLINICAL'),
  MenuItem('notifications', 'Notifications', Icons.notifications_none_rounded, AppRoutes.notifications, 'CLINICAL'),
  MenuItem('clients', 'Clients', Icons.apartment_rounded, AppRoutes.clients, 'NETWORK', countKey: 'clients'),
  MenuItem('admin_staffs', 'Staff', Icons.groups_2_outlined, AppRoutes.adminStaffs, 'NETWORK', countKey: 'staffs'),
  MenuItem('client_staffs', 'My Staff', Icons.groups_2_outlined, AppRoutes.myStaff, 'NETWORK', countKey: 'staffs'),
  MenuItem('cardiologists', 'Cardiologists', Icons.favorite_border_rounded, AppRoutes.cardiologists, 'NETWORK', countKey: 'cardiologists'),
  MenuItem('devices', 'Devices', Icons.developer_board_rounded, AppRoutes.devices, 'NETWORK', countKey: 'devices'),
  MenuItem('oem_users', 'OEM Users', Icons.verified_user_outlined, AppRoutes.oemUsers, 'NETWORK'),
  MenuItem('profile', 'My Profile', Icons.person_outline_rounded, AppRoutes.profile, 'ACCOUNT'),
];
