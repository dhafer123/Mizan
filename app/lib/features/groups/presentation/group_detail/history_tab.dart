import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/account_provider.dart';
import '../../../expenses/domain/entities/category.dart';
import '../../../expenses/presentation/shared/categories_provider.dart';
import '../../../expenses/presentation/shared/failure_message.dart';
import '../../domain/entities/group.dart';
import '../../domain/value_objects/change_kind.dart';
import '../shared/group_data_providers.dart';
import '../shared/load_error.dart';
import 'history_text.dart';

/// Who changed what ("Ali changed amount 120.000 DT → 150.000 DT"), newest
/// first. Only changes the server has accepted; edits that lost a conflict
/// or came after a delete are shown too, so nothing disappears silently.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({required this.group, super.key});

  final Group group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider(group.id)).value ?? const [];
    final dates = MaterialLocalizations.of(context);
    final text = HistoryText(
      members: members,
      currency: group.currency,
      myUserId: ref.watch(accountProvider).value?.id,
      categoryNames: {
        for (final c
            in ref.watch(categoriesProvider).value ?? const <Category>[])
          c.id: c.name,
      },
      formatDate: dates.formatMediumDate,
    );
    return ref
        .watch(groupHistoryProvider(group.id))
        .when(
          data: (entries) => entries.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No changes yet. Changes show up here once they sync.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(
                    bottom: 88 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    for (final e in entries)
                      ListTile(
                        leading: Icon(switch (e.kind) {
                          ChangeKind.created => Icons.add_circle_outline,
                          ChangeKind.deleted => Icons.delete_outline,
                          ChangeKind.restored => Icons.restore,
                          ChangeKind.overwritten ||
                          ChangeKind.discarded => Icons.warning_amber_outlined,
                          ChangeKind.changed => Icons.edit_outlined,
                        }),
                        title: Text(text.describe(e)),
                        subtitle: Text(
                          '${dates.formatMediumDate(e.changedAt.toLocal())} '
                          '${dates.formatTimeOfDay(TimeOfDay.fromDateTime(e.changedAt.toLocal()))}',
                        ),
                      ),
                  ],
                ),
          error: (error, _) => LoadError(
            message: failureMessage(error),
            onRetry: () => ref.invalidate(groupHistoryProvider(group.id)),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        );
  }
}
