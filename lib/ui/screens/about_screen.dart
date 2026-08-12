import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const String appVersion = '1.0.0';
  static const String appBuild = '102';

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text('About App'), centerTitle: true),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: const [
            _AppHeaderSection(version: appVersion, build: appBuild),
            SizedBox(height: 24),
            _DeveloperSection(),
            SizedBox(height: 20),
            _AppDetailsSection(),
            SizedBox(height: 20),
            _LegalAndLicensesSection(),
          ],
        ),
      ),
    );
  }
}

/// App Brand & Version Banner
class _AppHeaderSection extends StatelessWidget {
  final String version;
  final String _build;

  const _AppHeaderSection({required this.version, required this._build});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          'Vizio Smart Remote',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Version $version ($_build)',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Developer / Creator Info Card
class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About the Developer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Created as an independent, lightweight alternative to standard remote utilities. Designed to connect seamlessly over local networks with low latency and clean custom controls.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Key Application Features & Tech Specs
class _AppDetailsSection extends StatelessWidget {
  const _AppDetailsSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: const Text('FEATURES'),
        ),
        Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            children: [
              ListTile(
                leading: Icon(Icons.wifi_find_rounded),
                title: Text('SSDP & mDNS Discovery'),
                subtitle: Text('Automatic local TV network scanning'),
              ),
              Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.phonelink_setup_rounded),
                title: Text('SmartCast REST API'),
                subtitle: Text('Direct HTTPS key command execution'),
              ),
              Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.vibration_rounded),
                title: Text('Haptic Feedback'),
                subtitle: Text('Tactile response for remote interactions'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Legal & Open Source Licenses
class _LegalAndLicensesSection extends StatelessWidget {
  const _LegalAndLicensesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.description_outlined),
          title: const Text('Open Source Licenses'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            showLicensePage(
              context: context,
              applicationName: 'Vizio Smart Remote',
              applicationVersion: '1.0.0',
              applicationIcon: Padding(
                padding: EdgeInsets.all(10.0),
                child: Image.asset(
                  "assets/icon/icon.png",
                  height: 128,
                  width: 128,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Disclaimer: This application is independently developed and is not affiliated with, endorsed by, or sponsored by Vizio, Inc.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}
