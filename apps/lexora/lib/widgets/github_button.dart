import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

class GitHubButton extends StatelessWidget {
  const GitHubButton({super.key});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse('https://github.com/xiaozhangwangxue/lexora');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openGitHubFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const _GitHubProfileIcon(),
        label: Text(AppLocalizations.of(context).github),
      );
}

class _GitHubProfileIcon extends StatelessWidget {
  const _GitHubProfileIcon();

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 28,
        height: 22,
        child: Stack(children: [
          ClipOval(
            child: Image.asset(
              'assets/github/github-mark.png',
              width: 22,
              height: 22,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
                image: const DecorationImage(
                  image: AssetImage('assets/github/github-avatar.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ]),
      );
}
