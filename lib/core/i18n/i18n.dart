import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../storage.dart';

/// App languages.
const kLanguages = [
  ('en', 'English', 'English'),
  ('hi', 'हिन्दी', 'Hindi'),
  ('bn', 'বাংলা', 'Bengali'),
];

class LocaleNotifier extends Notifier<String> {
  static const _key = 'app_language_v1';

  @override
  String build() => ref.read(localStoreProvider).readString(_key) ?? 'en';

  void set(String code) {
    state = code;
    ref.read(localStoreProvider).writeString(_key, code);
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, String>(
  LocaleNotifier.new,
);

/// English text → translation. Missing entries fall back to English.
const _hi = <String, String>{
  // Navigation
  'Home': 'होम',
  'Category': 'कैटेगरी',
  'Order': 'ऑर्डर',
  'Review': 'रिव्यू',
  'Account': 'अकाउंट',
  // Home
  'Search for your dream mobile...': 'अपना पसंदीदा फ़ोन खोजें...',
  'Phone\nFinder': 'फ़ोन\nफ़ाइंडर',
  'Smart\nFilter': 'स्मार्ट\nफ़िल्टर',
  'Exchange': 'एक्सचेंज',
  'Sell\nPhone': 'फ़ोन\nबेचें',
  'EMI': 'EMI',
  'Compare': 'तुलना',
  'Repair': 'रिपेयर',
  'Track\nOrder': 'ऑर्डर\nट्रैक',
  'Phone\nCheck': 'फ़ोन\nचेक',
  'Trust\nCenter': 'ट्रस्ट\nसेंटर',
  'Picked for You': 'आपके लिए चुने गए',
  'Best Value Right Now': 'अभी सबसे अच्छी डील',
  'Top Deals': 'टॉप डील्स',
  'Recently Viewed': 'हाल ही में देखे गए',
  'See All': 'सभी देखें',
  'Explore all phones': 'सभी फ़ोन देखें',
  '32-point\nQC check': '32-पॉइंट\nQC जाँच',
  'Open-box\ndelivery': 'ओपन-बॉक्स\nडिलीवरी', '7-day\nreturns': '7 दिन\nवापसी',
  'Up to 12 mo\nwarranty': '12 महीने तक\nवारंटी',
  'Popular Brands': 'लोकप्रिय ब्रांड',
  // Product
  'Buy Now': 'अभी खरीदें',
  'Add to Cart': 'कार्ट में डालें',
  'Make an offer': 'ऑफ़र दें',
  'Price alert': 'प्राइस अलर्ट',
  'Notify me': 'मुझे बताएं',
  'Add to compare': 'तुलना में जोड़ें',
  'Similar in budget': 'इसी बजट में',
  'Fair Price meter': 'सही दाम मीटर',
  'Great Deal': 'बढ़िया डील',
  'Fair Price': 'सही दाम',
  'Above Market': 'बाज़ार से महंगा',
  'Delivery & COD': 'डिलीवरी और COD',
  'Bank offers': 'बैंक ऑफ़र',
  'Protect your phone': 'अपने फ़ोन को सुरक्षित करें',
  'Frequently bought together': 'साथ में अक्सर खरीदे गए',
  // Cart & checkout
  'My Cart': 'मेरा कार्ट',
  'Checkout': 'चेकआउट',
  'Place Order': 'ऑर्डर करें',
  'Price Details': 'कीमत विवरण',
  'Order Summary': 'ऑर्डर सारांश',
  'Delivery Address': 'डिलीवरी पता',
  'Payment Method': 'भुगतान का तरीका',
  'Cash on Delivery': 'कैश ऑन डिलीवरी',
  'Total amount': 'कुल राशि',
  'Apply coupon': 'कूपन लगाएं',
  'Eta-o lagbe? Complete your setup': 'यह भी चाहिए? अपना सेटअप पूरा करें',
  'Exchange your old phone': 'अपना पुराना फ़ोन एक्सचेंज करें',
  // Account
  'My Orders': 'मेरे ऑर्डर',
  'Wishlist': 'विशलिस्ट',
  'Wallet & Refer': 'वॉलेट और रेफ़र',
  'My Offers': 'मेरे ऑफ़र',
  'Price & Stock Alerts': 'प्राइस और स्टॉक अलर्ट',
  'Sell Your Phone': 'अपना फ़ोन बेचें',
  'Repairs': 'रिपेयर',
  'Phone Setup & Health Check': 'फ़ोन सेटअप और हेल्थ चेक',
  'Trade-In / Exchange': 'ट्रेड-इन / एक्सचेंज',
  'EMI & Pay Later': 'EMI और पे लेटर',
  'Notifications': 'सूचनाएं',
  'Language': 'भाषा',
  'GAMEX Trust Center': 'GAMEX ट्रस्ट सेंटर',
  'Account Settings': 'अकाउंट सेटिंग्स',
  // Auth
  'Login with OTP': 'OTP से लॉगिन करें',
  'Login to GAMEX': 'GAMEX में लॉगिन करें',
};

const _bn = <String, String>{
  'Home': 'হোম',
  'Category': 'ক্যাটাগরি',
  'Order': 'অর্ডার',
  'Review': 'রিভিউ',
  'Account': 'অ্যাকাউন্ট',
  'Search for your dream mobile...': 'আপনার পছন্দের ফোন খুঁজুন...',
  'Phone\nFinder': 'ফোন\nফাইন্ডার',
  'Smart\nFilter': 'স্মার্ট\nফিল্টার',
  'Exchange': 'এক্সচেঞ্জ',
  'Sell\nPhone': 'ফোন\nবিক্রি',
  'EMI': 'EMI',
  'Compare': 'তুলনা',
  'Repair': 'রিপেয়ার',
  'Track\nOrder': 'অর্ডার\nট্র্যাক',
  'Phone\nCheck': 'ফোন\nচেক',
  'Trust\nCenter': 'ট্রাস্ট\nসেন্টার',
  'Picked for You': 'আপনার জন্য বাছাই',
  'Best Value Right Now': 'এখনকার সেরা ডিল',
  'Top Deals': 'সেরা ডিল',
  'Recently Viewed': 'সম্প্রতি দেখা',
  'See All': 'সব দেখুন',
  'Explore all phones': 'সব ফোন দেখুন',
  '32-point\nQC check': '৩২-পয়েন্ট\nQC চেক',
  'Open-box\ndelivery': 'ওপেন-বক্স\nডেলিভারি',
  '7-day\nreturns': '৭ দিনে\nফেরত',
  'Up to 12 mo\nwarranty': '১২ মাস পর্যন্ত\nওয়ারেন্টি',
  'Popular Brands': 'জনপ্রিয় ব্র্যান্ড',
  'Buy Now': 'এখনই কিনুন',
  'Add to Cart': 'কার্টে যোগ করুন',
  'Make an offer': 'দাম প্রস্তাব করুন',
  'Price alert': 'দাম অ্যালার্ট',
  'Notify me': 'আমাকে জানান',
  'Add to compare': 'তুলনায় যোগ করুন',
  'Similar in budget': 'একই বাজেটে',
  'Fair Price meter': 'ন্যায্য দাম মিটার',
  'Great Deal': 'দারুণ ডিল',
  'Fair Price': 'ন্যায্য দাম',
  'Above Market': 'বাজারের চেয়ে বেশি',
  'Delivery & COD': 'ডেলিভারি ও COD',
  'Bank offers': 'ব্যাংক অফার',
  'Protect your phone': 'ফোন সুরক্ষিত রাখুন',
  'Frequently bought together': 'একসাথে প্রায়ই কেনা হয়',
  'My Cart': 'আমার কার্ট',
  'Checkout': 'চেকআউট',
  'Place Order': 'অর্ডার করুন',
  'Price Details': 'দামের বিবরণ',
  'Order Summary': 'অর্ডার সারাংশ',
  'Delivery Address': 'ডেলিভারি ঠিকানা',
  'Payment Method': 'পেমেন্ট পদ্ধতি',
  'Cash on Delivery': 'ক্যাশ অন ডেলিভারি',
  'Total amount': 'মোট দাম',
  'Apply coupon': 'কুপন লাগান',
  'Eta-o lagbe? Complete your setup': 'এটাও লাগবে? সেটআপ সম্পূর্ণ করুন',
  'Exchange your old phone': 'পুরনো ফোন এক্সচেঞ্জ করুন',
  'My Orders': 'আমার অর্ডার',
  'Wishlist': 'উইশলিস্ট',
  'Wallet & Refer': 'ওয়ালেট ও রেফার',
  'My Offers': 'আমার অফার',
  'Price & Stock Alerts': 'দাম ও স্টক অ্যালার্ট',
  'Sell Your Phone': 'আপনার ফোন বিক্রি করুন',
  'Repairs': 'রিপেয়ার',
  'Phone Setup & Health Check': 'ফোন সেটআপ ও হেলথ চেক',
  'Trade-In / Exchange': 'ট্রেড-ইন / এক্সচেঞ্জ',
  'EMI & Pay Later': 'EMI ও পে লেটার',
  'Notifications': 'নোটিফিকেশন',
  'Language': 'ভাষা',
  'GAMEX Trust Center': 'GAMEX ট্রাস্ট সেন্টার',
  'Account Settings': 'অ্যাকাউন্ট সেটিংস',
  'Login with OTP': 'OTP দিয়ে লগইন',
  'Login to GAMEX': 'GAMEX-এ লগইন করুন',
};

/// Translates [en] into [code] (falls back to English).
String translate(String en, String code) => switch (code) {
  'hi' => _hi[en] ?? en,
  'bn' => _bn[en] ?? en,
  _ => en,
};

extension Tr on String {
  /// `'Buy Now'.tr(context)` in the app's language.
  String tr(BuildContext context) =>
      translate(this, Localizations.localeOf(context).languageCode);
}

/// Language picker sheet.
Future<void> showLanguageSheet(BuildContext context, WidgetRef ref) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Consumer(
          builder: (c, ref, _) {
            final cur = ref.watch(localeProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Language / भाषा / ভাষা',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final (code, native, english) in kLanguages)
                  ListTile(
                    title: Text(
                      native,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(english),
                    trailing: cur == code
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF3B5BFF),
                          )
                        : null,
                    onTap: () {
                      ref.read(localeProvider.notifier).set(code);
                      Navigator.pop(c);
                    },
                  ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
