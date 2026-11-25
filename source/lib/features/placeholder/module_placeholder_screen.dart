import 'package:flutter/material.dart';

import '../../core/models/app_module.dart';
import '../../core/theme/app_colors.dart';

/// Shown for modules that are not implemented yet. Says so honestly.
class ModulePlaceholderScreen extends StatelessWidget {
  const ModulePlaceholderScreen({super.key, required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: module.color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(module.icon, color: module.color, size: 34),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    module.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    module.summary,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 18),
                  Chip(
                    label: Text('Not built yet - planned for Phase ${module.phase}'),
                    backgroundColor: AppColors.lightBlue,
                    side: BorderSide.none,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
