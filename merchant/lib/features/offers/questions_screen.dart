import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

/// Buyers' questions on the seller's listings. Answers show on the
/// product page for every buyer.
class QuestionsScreen extends ConsumerWidget {
  const QuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qs = ref.watch(questionsProvider);
    final open = qs.where((q) => q.open).toList();
    final done = qs.where((q) => !q.open).toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Buyer Q&A'),
          bottom: TabBar(
            labelColor: C.primary,
            unselectedLabelColor: C.muted,
            indicatorColor: C.primary,
            dividerColor: C.border,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
            ),
            tabs: [
              Tab(text: 'Unanswered (${open.length})'),
              Tab(text: 'Answered (${done.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _List(
              open,
              empty: 'No questions waiting. Fast answers help you sell faster.',
            ),
            _List(done, empty: 'Your answers appear here.'),
          ],
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List(this.items, {required this.empty});
  final List<BuyerQuestion> items;
  final String empty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            empty,
            textAlign: TextAlign.center,
            style: const TextStyle(color: C.muted),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final q = items[i];
        final l = ref.watch(listingByIdProvider(q.listingId));
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: C.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l == null
                    ? q.listingId
                    : '${l.brand} ${l.model} • ${l.storage}',
                style: const TextStyle(
                  fontSize: 12,
                  color: C.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Q: ${q.text}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              Text(
                '${q.author} • ${ago(q.createdAt)}',
                style: const TextStyle(fontSize: 12, color: C.faint),
              ),
              if (q.answer != null) ...[
                const SizedBox(height: 8),
                Text(
                  'A: ${q.answer}',
                  style: const TextStyle(
                    color: C.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => _answer(context, ref, q),
                    icon: const Icon(Icons.reply_rounded),
                    label: const Text('Answer'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    BuyerQuestion q,
  ) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Answer the buyer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(q.text, style: const TextStyle(color: C.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Your answer is shown on the product page',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(d, c.text.trim()),
            child: const Text('Post answer'),
          ),
        ],
      ),
    );
    if (text == null || text.length < 2 || !context.mounted) return;
    await runAction(
      context,
      () => ref.read(syncProvider.notifier).answerQuestion(q.id, text),
      done: 'Answer posted',
    );
  }
}
