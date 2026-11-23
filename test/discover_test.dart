import 'package:flutter_test/flutter_test.dart';
import 'package:gamex_shop/data/mock/mock_data.dart';
import 'package:gamex_shop/features/discover/data/phone_filter.dart';
import 'package:gamex_shop/features/discover/data/phone_intel.dart';
import 'package:gamex_shop/features/discover/data/pincode.dart';
import 'package:gamex_shop/features/discover/presentation/finder_screen.dart';

void main() {
  group('smart search', () {
    test('budget, brand and 5G', () {
      final f = parseSmartQuery('5G samsung under 30k');
      expect(f.maxPrice, 30000);
      expect(f.brands, {'Samsung'});
      expect(f.only5G, isTrue);
      expect(f.text, isEmpty);
    });

    test('Banglish budget and priority', () {
      final f = parseSmartQuery('battery valo phone 25 hazar er niche');
      expect(f.maxPrice, 25000);
      expect(f.priority, Priority.battery);
      expect(f.text, isEmpty);
    });

    test('keeps the model name, reads RAM and city', () {
      final f = parseSmartQuery('iphone 13 8gb ram in pune');
      expect(f.brands, {'Apple'});
      expect(f.text, 'iphone 13');
      expect(f.ram, {8});
      expect(f.city, 'Pune');
    });

    test('price range', () {
      final f = parseSmartQuery('gaming phone 20k-35k');
      expect(f.minPrice, 20000);
      expect(f.maxPrice, 35000);
      expect(f.priority, Priority.gaming);
    });

    test('plain model search is not a filter', () {
      final f = parseSmartQuery('galaxy s23 ultra');
      expect(f.brands, {'Samsung'});
      expect(f.text, 's23 ultra');
    });
  });

  group('filter engine', () {
    final pool = [
      ...MockData.products,
      for (var n = 0; n < 48; n++) MockData.listing(n),
    ];

    test('every result honours every filter', () {
      const f = PhoneFilter(
        maxPrice: 40000,
        minBattery: 85,
        only5G: true,
        warranty: true,
      );
      final r = f.apply(pool);
      expect(r, isNotEmpty);
      for (final p in r) {
        expect(p.price, lessThanOrEqualTo(40000));
        expect(batteryOf(p), greaterThanOrEqualTo(85));
        expect(modelInfo(p).is5G, isTrue);
        expect(p.warrantyMonths, greaterThan(0));
      }
    });

    test('iPhone 11 is 4G and filtered out by 5G', () {
      final r = const PhoneFilter(only5G: true).apply(pool);
      expect(r.any((p) => p.name == 'iPhone 11'), isFalse);
    });

    test('Phone Finder returns 3 distinct models', () {
      final (picks, _) = findPhones(
        pool,
        min: 20000,
        max: 35000,
        priority: Priority.gaming,
        brands: const {},
        grades: const {},
        need5G: true,
        city: 'Mumbai',
      );
      expect(picks.length, 3);
      expect({for (final p in picks) p.product.name}.length, 3);
      for (final p in picks) {
        expect(p.match, inInclusiveRange(50, 99));
      }
    });
  });

  group('fair price', () {
    test('cheaper copy of the same phone scores a better deal', () {
      final p = MockData.products.firstWhere((p) => p.name == 'iPhone 13');
      final cheap = fairPriceOf(p.copyWith(price: p.price * 0.8));
      final dear = fairPriceOf(p.copyWith(price: p.price * 1.3));
      expect(cheap.delta, lessThan(dear.delta));
      expect(dear.verdict, PriceVerdict.high);
      expect(cheap.market, dear.market);
    });

    test('better condition is worth more', () {
      final p = MockData.products.firstWhere((p) => p.name == 'iPhone 13');
      expect(
        fairPriceOf(p.copyWith(condition: 'Like New')).market,
        greaterThan(
          fairPriceOf(p.copyWith(condition: 'Good Condition')).market,
        ),
      );
    });
  });

  group('pincode', () {
    test('valid and invalid PINs', () {
      expect(lookupPin('400001')!.city, 'Mumbai');
      expect(lookupPin('560034')!.state, 'Karnataka');
      expect(lookupPin('781001')!.remote, isTrue);
      expect(lookupPin('12345'), isNull);
      expect(lookupPin('999999'), isNull);
    });

    test('same-city delivery is fastest; COD has a limit', () {
      final p = MockData.products.first;
      final from = shipsFrom(p);
      final local = {
        'Mumbai': '400001',
        'Delhi': '110001',
        'Bengaluru': '560001',
        'Hyderabad': '500001',
        'Chennai': '600001',
        'Kolkata': '700001',
        'Pune': '411001',
        'Ahmedabad': '380001',
      }[from]!;
      final near = quoteFor(p, lookupPin(local)!);
      final far = quoteFor(p, lookupPin('781001')!);
      expect(near.maxDays, lessThan(far.minDays));
      expect(far.cod, isFalse);
      expect(quoteFor(p, lookupPin(local)!, price: 90000).cod, isFalse);
    });
  });
}
