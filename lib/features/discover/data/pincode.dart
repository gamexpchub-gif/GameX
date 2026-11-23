import '../../../data/models/product.dart';
import 'phone_intel.dart';

/// Where an Indian PIN code is, from its first digits.
class PinPlace {
  const PinPlace({
    required this.pin,
    required this.city,
    required this.state,
    required this.zone,
    this.metro = false,
    this.remote = false,
  });
  final String pin;
  final String city;
  final String state;

  /// north / west / central / south / east / northeast.
  final String zone;
  final bool metro;
  final bool remote;

  String get label => city == state ? state : '$city, $state';
}

/// Delivery promise for one phone to one PIN code.
class DeliveryQuote {
  const DeliveryQuote({
    required this.place,
    required this.from,
    required this.minDays,
    required this.maxDays,
    required this.cod,
    required this.codNote,
    required this.openBox,
    required this.express,
  });
  final PinPlace place;
  final String from;
  final int minDays;
  final int maxDays;
  final bool cod;
  final String codNote;
  final bool openBox;
  final bool express;

  DateTime get earliest => _addWorkingDays(DateTime.now(), minDays);
  DateTime get latest => _addWorkingDays(DateTime.now(), maxDays);
}

DateTime _addWorkingDays(DateTime from, int days) {
  var d = from;
  var left = days;
  while (left > 0) {
    d = d.add(const Duration(days: 1));
    if (d.weekday != DateTime.sunday) left--;
  }
  return d;
}

/// Metro / big-city PIN prefixes (first 3 digits).
const _cities3 = <String, (String, String)>{
  '110': ('New Delhi', 'Delhi'),
  '400': ('Mumbai', 'Maharashtra'),
  '401': ('Thane', 'Maharashtra'),
  '410': ('Navi Mumbai', 'Maharashtra'),
  '411': ('Pune', 'Maharashtra'),
  '412': ('Pune', 'Maharashtra'),
  '560': ('Bengaluru', 'Karnataka'),
  '500': ('Hyderabad', 'Telangana'),
  '600': ('Chennai', 'Tamil Nadu'),
  '700': ('Kolkata', 'West Bengal'),
  '380': ('Ahmedabad', 'Gujarat'),
  '382': ('Ahmedabad', 'Gujarat'),
  '201': ('Noida / Ghaziabad', 'Uttar Pradesh'),
  '122': ('Gurugram', 'Haryana'),
  '302': ('Jaipur', 'Rajasthan'),
  '226': ('Lucknow', 'Uttar Pradesh'),
  '160': ('Chandigarh', 'Chandigarh'),
  '452': ('Indore', 'Madhya Pradesh'),
  '440': ('Nagpur', 'Maharashtra'),
  '395': ('Surat', 'Gujarat'),
  '641': ('Coimbatore', 'Tamil Nadu'),
  '682': ('Kochi', 'Kerala'),
  '781': ('Guwahati', 'Assam'),
  '751': ('Bhubaneswar', 'Odisha'),
  '800': ('Patna', 'Bihar'),
  '403': ('Goa', 'Goa'),
  '744': ('Port Blair', 'Andaman & Nicobar'),
  '737': ('Gangtok', 'Sikkim'),
  '194': ('Leh', 'Ladakh'),
};

const _metroCities = {
  'New Delhi',
  'Mumbai',
  'Thane',
  'Navi Mumbai',
  'Pune',
  'Bengaluru',
  'Hyderabad',
  'Chennai',
  'Kolkata',
  'Ahmedabad',
  'Noida / Ghaziabad',
  'Gurugram',
};

/// State / zone by the first 2 digits.
const _states2 = <String, (String, String)>{
  '11': ('Delhi', 'north'),
  '12': ('Haryana', 'north'),
  '13': ('Haryana', 'north'),
  '14': ('Punjab', 'north'),
  '15': ('Punjab', 'north'),
  '16': ('Punjab', 'north'),
  '17': ('Himachal Pradesh', 'north'),
  '18': ('Jammu & Kashmir', 'remote'),
  '19': ('Jammu & Kashmir', 'remote'),
  '20': ('Uttar Pradesh', 'north'),
  '21': ('Uttar Pradesh', 'north'),
  '22': ('Uttar Pradesh', 'north'),
  '23': ('Uttar Pradesh', 'north'),
  '24': ('Uttarakhand', 'north'),
  '25': ('Uttar Pradesh', 'north'),
  '26': ('Uttarakhand', 'north'),
  '27': ('Uttar Pradesh', 'north'),
  '28': ('Uttar Pradesh', 'north'),
  '30': ('Rajasthan', 'west'),
  '31': ('Rajasthan', 'west'),
  '32': ('Rajasthan', 'west'),
  '33': ('Rajasthan', 'west'),
  '34': ('Rajasthan', 'west'),
  '36': ('Gujarat', 'west'),
  '37': ('Gujarat', 'west'),
  '38': ('Gujarat', 'west'),
  '39': ('Gujarat', 'west'),
  '40': ('Maharashtra', 'west'),
  '41': ('Maharashtra', 'west'),
  '42': ('Maharashtra', 'west'),
  '43': ('Maharashtra', 'west'),
  '44': ('Maharashtra', 'west'),
  '45': ('Madhya Pradesh', 'central'),
  '46': ('Madhya Pradesh', 'central'),
  '47': ('Madhya Pradesh', 'central'),
  '48': ('Madhya Pradesh', 'central'),
  '49': ('Chhattisgarh', 'central'),
  '50': ('Telangana', 'south'),
  '51': ('Andhra Pradesh', 'south'),
  '52': ('Andhra Pradesh', 'south'),
  '53': ('Andhra Pradesh', 'south'),
  '56': ('Karnataka', 'south'),
  '57': ('Karnataka', 'south'),
  '58': ('Karnataka', 'south'),
  '59': ('Karnataka', 'south'),
  '60': ('Tamil Nadu', 'south'),
  '61': ('Tamil Nadu', 'south'),
  '62': ('Tamil Nadu', 'south'),
  '63': ('Tamil Nadu', 'south'),
  '64': ('Tamil Nadu', 'south'),
  '67': ('Kerala', 'south'),
  '68': ('Kerala', 'south'),
  '69': ('Kerala', 'south'),
  '70': ('West Bengal', 'east'),
  '71': ('West Bengal', 'east'),
  '72': ('West Bengal', 'east'),
  '73': ('West Bengal', 'east'),
  '74': ('West Bengal', 'east'),
  '75': ('Odisha', 'east'),
  '76': ('Odisha', 'east'),
  '77': ('Odisha', 'east'),
  '78': ('Assam', 'northeast'),
  '79': ('North East', 'northeast'),
  '80': ('Bihar', 'east'),
  '81': ('Jharkhand', 'east'),
  '82': ('Jharkhand', 'east'),
  '83': ('Jharkhand', 'east'),
  '84': ('Bihar', 'east'),
  '85': ('Bihar', 'east'),
};

/// Seller / hub city → its zone.
const _cityZone = {
  'Mumbai': 'west',
  'Pune': 'west',
  'Ahmedabad': 'west',
  'Delhi': 'north',
  'New Delhi': 'north',
  'Bengaluru': 'south',
  'Hyderabad': 'south',
  'Chennai': 'south',
  'Kolkata': 'east',
};

/// Parses a 6-digit PIN code. Returns null when it is not a valid one.
PinPlace? lookupPin(String raw) {
  final pin = raw.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^[1-8]\d{5}$').hasMatch(pin)) return null;
  final s2 = _states2[pin.substring(0, 2)];
  if (s2 == null) return null;
  final c3 = _cities3[pin.substring(0, 3)];
  final remote =
      s2.$2 == 'remote' ||
      s2.$2 == 'northeast' ||
      const {'744', '737', '194'}.contains(pin.substring(0, 3));
  final zone = s2.$2 == 'remote' ? 'north' : s2.$2;
  final city = c3?.$1 ?? s2.$1;
  return PinPlace(
    pin: pin,
    city: city,
    state: c3?.$2 ?? s2.$1,
    zone: zone,
    metro: _metroCities.contains(city),
    remote: remote,
  );
}

/// Max order value for Cash on Delivery.
const kCodLimit = 50000.0;

/// Delivery estimate for [p] to [place].
DeliveryQuote quoteFor(Product p, PinPlace place, {double? price}) {
  final from = shipsFrom(p);
  final fromZone = _cityZone[from] ?? 'west';
  final sameCity =
      place.city == from ||
      (from == 'Delhi' && place.city == 'New Delhi') ||
      (from == 'Mumbai' && const {'Thane', 'Navi Mumbai'}.contains(place.city));
  final (minD, maxD) = place.remote
      ? (6, 8)
      : sameCity
      ? (1, 1)
      : place.zone == fromZone
      ? (place.metro ? (2, 2) : (2, 3))
      : (place.metro ? (3, 4) : (4, 6));
  final value = price ?? p.price;
  final cod = !place.remote && value <= kCodLimit;
  return DeliveryQuote(
    place: place,
    from: from,
    minDays: minD,
    maxDays: maxD,
    cod: cod,
    codNote: place.remote
        ? 'Prepaid only for this area'
        : cod
        ? 'Pay in cash or UPI at your door'
        : 'COD up to ₹50,000. Pay online or use EMI',
    openBox: !place.remote,
    express: sameCity && place.metro,
  );
}
