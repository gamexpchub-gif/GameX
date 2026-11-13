import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/widgets/brand_marks.dart';
import '../../../core/widgets/common.dart';
import '../../../data/mock/mock_data.dart';
import '../providers/catalog_providers.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Category'),
        actions: [
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: AsyncView(
        value: ref.watch(categoriesProvider),
        onRetry: () => ref.invalidate(categoriesProvider),
        data: (cats) {
          final counts = <String, int>{};
          for (final p in MockData.products) {
            counts[p.categoryId] = (counts[p.categoryId] ?? 0) + 1;
          }
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: cats.length + 1,
            itemBuilder: (context, i) {
              final all = i == cats.length;
              final c = all ? null : cats[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/category/${c?.id ?? 'all'}'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 52,
                        child: Center(
                          child: c == null
                              ? const Icon(Icons.apps_rounded, size: 44)
                              : BrandMark(c.icon, size: 46),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        c?.name ?? 'All Phones',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${c == null ? MockData.products.length : counts[c.id] ?? 0} phones',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
