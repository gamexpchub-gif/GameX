import 'package:flutter_test/flutter_test.dart';
import 'package:gamex_merchant/data/catalog.dart';

void main() {
  test('catalogue search finds category, brand and model', () {
    final hits = searchCatalog('iphone 13');
    expect(hits.first.model, 'iPhone 13');
    expect(hits.first.category.name, 'Mobile Phone');
    expect(hits.first.brand, 'Apple');
    expect(searchCatalog('galaxy tab s9').first.category.name, 'Tablet');
    expect(searchCatalog('samsung').any((h) => h.model == null), isTrue);
    expect(searchCatalog('airpods pro').first.category.name, 'Earbuds & Audio');
    expect(searchCatalog('redmi note 13 pro').first.model, 'Redmi Note 13 Pro');
    expect(kCategories.first.brands.length, greaterThan(40));
  });

  test('battery health only for Apple', () {
    expect(showsBatteryHealth('Apple', 'Mobile Phone'), isTrue);
    expect(showsBatteryHealth('Samsung', 'Mobile Phone'), isFalse);
  });
}
