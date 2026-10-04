import 'package:flutter/material.dart';

import '../tokens/app_spacing.dart';

enum InlineMessageTone { error, warning, info }

/// Mensaje en línea (error de envío, sesión expirada, datos sin conexión).
///
/// `liveRegion` hace que TalkBack lo anuncie al aparecer: un error visible
/// pero no anunciado es invisible para un usuario de lector de pantalla.
class InlineMessage extends StatelessWidget {
  const InlineMessage(
    this.text, {
    this.tone = InlineMessageTone.error,
    this.action,
    super.key,
  });

  final String text;
  final InlineMessageTone tone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground, icon) = switch (tone) {
      InlineMessageTone.error => (
        scheme.errorContainer,
        scheme.onErrorContainer,
        Icons.error_outline,
      ),
      InlineMessageTone.warning => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        Icons.warning_amber_outlined,
      ),
      InlineMessageTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        Icons.info_outline,
      ),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppSpacing.radius),
        ),
        child: Row(
          children: [
            ExcludeSemantics(child: Icon(icon, color: foreground)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(text, style: TextStyle(color: foreground)),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}
