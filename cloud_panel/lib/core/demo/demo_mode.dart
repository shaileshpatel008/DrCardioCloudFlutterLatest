/// Demo (clickable prototype) build switch.
///
///   flutter build apk --dart-define=DEMO_MODE=true
///   flutter run -d chrome --dart-define=DEMO_MODE=true
///
/// In demo mode no request leaves the device: every API call is answered by
/// [DemoApi] from built-in sample data (assets/demo/demo_data.json, fictional
/// hospitals, doctors and patients). Changes made in the demo (publishing a
/// report, adding a client…) live in memory and reset when the app restarts.
/// Without the flag the app talks to the real Panel API v2 as usual.
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');

/// Accounts offered on the demo sign-in screen. Any password works.
class DemoAccount {
  const DemoAccount(this.role, this.label, this.email, this.description);

  final String role;
  final String label;
  final String email;
  final String description;

  static const password = 'Demo@123';

  static const all = [
    DemoAccount('admin', 'Super Admin', 'admin@example.com', 'Every client, device, cardiologist and OEM partner'),
    DemoAccount('oem', 'OEM partner', 'oem@example.com', 'A distributor managing its own clients'),
    DemoAccount('client', 'Hospital / clinic', 'client@example.com', 'Sunrise Diagnostics: its ECGs and staff'),
    DemoAccount('cardio', 'Cardiologist', 'cardio@example.com', 'Dr. Ananya Rao: review ECGs and publish reports'),
  ];
}
