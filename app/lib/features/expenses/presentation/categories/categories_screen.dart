import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/di/expenses_providers.dart';
import '../../../../core/money/money_formatter.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import '../shared/categories_provider.dart';
import '../shared/category_icon.dart';
import '../shared/failure_message.dart';
import 'category_sheet.dart';

/// Every category: the active ones (tap to edit, archive), then the
/// archived ones (restore). Archiving never touches expenses.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      body: ref
          .watch(categoriesProvider)
          .when(
            data: (categories) => _CategoryList(categories: categories),
            error: (error, _) => _LoadError(
              message: failureMessage(error),
              onRetry: () => ref.invalidate(categoriesProvider),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategorySheet(context),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
    );
  }
}

class _CategoryList extends ConsumerWidget {
  const _CategoryList({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = categories.where((c) => !c.archived).toList();
    final archived = categories.where((c) => c.archived).toList();
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 88), // clear of the add button
      children: [
        for (final category in active)
          _CategoryTile(
            category: category,
            onTap: () => showCategorySheet(context, category: category),
            action: IconButton(
              onPressed: () => _archive(context, ref, category),
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Archive ${category.name}',
            ),
          ),
        if (archived.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(
              'Archived',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Hidden when adding expenses. Their expenses keep them.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          for (final category in archived)
            _CategoryTile(
              category: category,
              dimmed: true,
              action: TextButton(
                onPressed: () => _restore(context, ref, category),
                child: const Text('Restore'),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _archive(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final restore = ref.read(restoreCategoryProvider);
    final result = await ref.read(archiveCategoryProvider)(category.id);
    messenger.hideCurrentSnackBar();
    switch (result) {
      case Ok():
        messenger.showSnackBar(
          SnackBar(
            content: Text('${category.name} archived'),
            // A snackbar with an action stays up until tapped by default.
            persist: false,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                if (await restore(category.id) case Err(:final failure)) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(failure.message)),
                  );
                }
              },
            ),
          ),
        );
      case Err(:final failure):
        messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(restoreCategoryProvider)(category.id);
    messenger.hideCurrentSnackBar();
    if (result case Err(:final failure)) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.action,
    this.onTap,
    this.dimmed = false,
  });

  final Category category;
  final Widget action;
  final VoidCallback? onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final limit = category.monthlyLimit;
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: ExcludeSemantics(child: Icon(categoryIcon(category.icon))),
        ),
        title: Text(category.name),
        subtitle: limit == null
            ? null
            : Text('Limit ${const MoneyFormatter().format(limit)} a month'),
        trailing: action,
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
