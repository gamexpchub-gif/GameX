import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../data/models/order.dart';
import '../../orders/providers/orders_provider.dart';

const _key = 'address_book_v1';

class AddressBook {
  const AddressBook({this.addresses = const [], this.selected = 0});
  final List<Address> addresses;
  final int selected;

  Address? get current => addresses.isEmpty
      ? null
      : addresses[selected.clamp(0, addresses.length - 1)];

  Map<String, dynamic> toJson() => {
    'addresses': addresses.map((a) => a.toJson()).toList(),
    'selected': selected,
  };

  factory AddressBook.fromJson(Map<String, dynamic> j) => AddressBook(
    addresses: (j['addresses'] as List)
        .map((e) => Address.fromJson(e as Map<String, dynamic>))
        .toList(),
    selected: j['selected'] as int? ?? 0,
  );
}

/// Saved delivery addresses + the one chosen for checkout.
class AddressBookNotifier extends Notifier<AddressBook> {
  @override
  AddressBook build() {
    final saved = ref
        .read(localStoreProvider)
        .readJson(_key, (j) => AddressBook.fromJson(j as Map<String, dynamic>));
    if (saved != null) return saved;
    // Seed from the most recent order, if any.
    final last = ref.read(savedAddressProvider);
    return AddressBook(addresses: last == null ? const [] : [last]);
  }

  void _save(AddressBook b) {
    state = b;
    ref.read(localStoreProvider).writeJson(_key, b.toJson());
  }

  void select(int i) =>
      _save(AddressBook(addresses: state.addresses, selected: i));

  /// Adds a new address (or replaces the one at [index]) and selects it.
  void upsert(Address a, {int? index}) {
    final list = [...state.addresses];
    if (index == null) {
      list.add(a);
      _save(AddressBook(addresses: list, selected: list.length - 1));
    } else {
      list[index] = a;
      _save(AddressBook(addresses: list, selected: index));
    }
  }

  void remove(int i) {
    final list = [...state.addresses]..removeAt(i);
    final sel = state.selected >= list.length
        ? list.length - 1
        : state.selected;
    _save(AddressBook(addresses: list, selected: sel < 0 ? 0 : sel));
  }
}

final addressBookProvider = NotifierProvider<AddressBookNotifier, AddressBook>(
  AddressBookNotifier.new,
);
