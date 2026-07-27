import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const lexoraReleaseNotesUri = 'https://lexora.12323456.xyz/#release-notes';

class ReleaseNotesContent extends StatelessWidget {
  const ReleaseNotesContent({
    super.key,
    required this.notes,
    required this.isZh,
    this.extra,
  });

  final List<String> notes;
  final bool isZh;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final availableHeight = MediaQuery.sizeOf(context).height;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: (availableHeight * .52).clamp(220, 430),
      ),
      child: Scrollbar(
        thumbVisibility: availableHeight < 700,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(right: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final note in notes) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Icon(Icons.circle, size: 5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(note)),
                  ],
                ),
                const SizedBox(height: 9),
              ],
              if (extra != null) ...[const SizedBox(height: 2), extra!],
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(lexoraReleaseNotesUri),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(
                    isZh ? '查看完整更新内容' : 'View complete release notes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
