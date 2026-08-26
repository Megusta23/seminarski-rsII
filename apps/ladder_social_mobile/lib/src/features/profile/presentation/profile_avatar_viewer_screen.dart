import 'package:flutter/material.dart';
import 'package:ladder_social_mobile/src/core/widgets/mobile_widgets.dart';

final class ProfileAvatarViewerScreen extends StatelessWidget {
  const ProfileAvatarViewerScreen({
    required this.displayName,
    required this.avatarUrl,
    super.key,
  });

  final String displayName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(displayName),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return InteractiveViewer(
            minScale: 1,
            maxScale: 4,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: ProtectedImage(
                path: avatarUrl,
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }
}
