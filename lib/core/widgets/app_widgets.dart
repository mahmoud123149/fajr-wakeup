import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Themed surface card (avoids the version-churny ThemeData.cardTheme type).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.navySurface,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: content,
    );
  }
}

/// A titled surface card used across the settings screens.
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.title, required this.children, this.icon});

  final String title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A label on one side and a value on the other.
class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small coloured status chip (granted / missing).
class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.ok, required this.label});

  final bool ok;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.success : AppColors.error;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(ok ? Icons.check_circle : Icons.error, color: color, size: 18),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

/// A warning banner with an action button.
class WarningBanner extends StatelessWidget {
  const WarningBanner({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x1FE5484D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x66E5484D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(message, style: const TextStyle(color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}
