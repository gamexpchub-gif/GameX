import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/product.dart';
import 'catalog_providers.dart';

class ListingsState {
  const ListingsState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.error = false,
  });

  final List<Product> items;
  final bool loading;
  final bool hasMore;
  final bool error;

  ListingsState copyWith({
    List<Product>? items,
    bool? loading,
    bool? hasMore,
    bool? error,
  }) => ListingsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    hasMore: hasMore ?? this.hasMore,
    error: error ?? this.error,
  );
}

/// Endless "New Listings" feed. Call [loadMore] when the user nears the end.
class ListingsNotifier extends Notifier<ListingsState> {
  static const pageSize = 12;
  int _page = 0;

  @override
  ListingsState build() {
    Future.microtask(loadMore);
    return const ListingsState();
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore) return;
    state = state.copyWith(loading: true, error: false);
    try {
      final next = await ref
          .read(productRepositoryProvider)
          .newListings(page: _page, pageSize: pageSize);
      _page++;
      state = state.copyWith(
        items: [...state.items, ...next],
        loading: false,
        hasMore: next.length == pageSize,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: true);
    }
  }

  Future<void> refresh() async {
    _page = 0;
    state = const ListingsState();
    await loadMore();
  }
}

final listingsProvider = NotifierProvider<ListingsNotifier, ListingsState>(
  ListingsNotifier.new,
);
