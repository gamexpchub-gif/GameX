# GameX Shop 🛍️

A professional, mobile-only ecommerce app built with **Flutter** (Android & iOS).

## Features

- **Splash, Login, Register** (or continue as guest; you sign in at checkout)
- **Home**: auto-sliding promo banners, categories, flash sale with a live countdown, featured products, pull-to-refresh
- **Categories** and a **product listing** with sorting (popular, price, rating, newest) and an in-stock filter
- **Product details**: image gallery, colour/size picker, quantity, stock status, related products
- **Search** with debounce, recent searches and popular searches
- **Cart**: swipe to delete with undo, quantity stepper, promo codes (`GAMEX10`, `WELCOME20`), free-delivery progress bar
- **Checkout**: Bangladesh address form, payment by Cash on Delivery, bKash, Nagad or card
- **Orders**: order list, order details with a status timeline
- **Wishlist** and **Account** (edit profile, light/dark/system theme, coupons, log out)
- Cart, wishlist, orders, user and theme are saved on the device
- Currency is BDT (৳)

## Tech stack

| Concern | Package |
| --- | --- |
| State management | `flutter_riverpod` |
| Navigation | `go_router` (bottom-nav shell with `StatefulShellRoute`) |
| Images | `cached_network_image` |
| Local storage | `shared_preferences` |
| Formatting | `intl` |

## Project structure

```
lib/
├── main.dart                 # App entry, ProviderScope, theme
├── core/
│   ├── router/               # All routes (go_router)
│   ├── theme/                # Colors + light/dark Material 3 theme
│   ├── utils/                # Price/date formatters, form validators
│   ├── widgets/              # ProductCard, AppImage, skeletons, shared UI
│   └── storage.dart          # SharedPreferences wrapper
├── data/
│   ├── models/               # Product, Category, CartItem, Order, AppUser
│   ├── repositories/         # ProductRepository interface + mock impl
│   └── mock/                 # Demo catalogue
└── features/<feature>/
    ├── presentation/         # Screens
    └── providers/            # Riverpod state
```

## Connecting the Super Admin panel later

All product data goes through the `ProductRepository` interface in
`lib/data/repositories/product_repository.dart`. When the admin panel and its API are ready:

1. Write an `ApiProductRepository implements ProductRepository` that calls your API.
2. Change one line in `lib/features/catalog/providers/catalog_providers.dart`:
   `Provider<ProductRepository>((ref) => ApiProductRepository())`.

You don't need to change any screen. Auth (`auth_provider.dart`) and orders
(`orders_provider.dart`) work the same way: swap the local logic for API calls.

## Run / build

```bash
flutter pub get
flutter run                     # on a connected phone / emulator
flutter build apk --release     # build/app/outputs/flutter-apk/app-release.apk
```

You need Flutter 3.50 or newer (Dart 3.14). If an older version is installed, run `flutter upgrade` first.

## Test

```bash
flutter analyze
flutter test
```
