# GAMEX Seller (Merchant app)

Flutter app for sellers to list second-hand phones and fulfil orders on GAMEX.

## Build

```bash
cd merchant
flutter pub get
flutter build apk --release
flutter install
```

Demo login: any Indian mobile number (starting 6–9), OTP **123456**.

## Features

- **Sign in & store setup**: mobile + OTP, store name, owner, pickup city, optional GSTIN (format-checked)
- **Dashboard**: withdrawable balance, today's sales, orders to ship, active listings, store views, "Needs your attention" (new orders with acceptance timer, live review requests, low stock), 7-day sales chart, quick actions, holiday mode
- **Orders**: New → To ship → Shipped → Delivered → Cancelled/Returns tabs, search, 4-hour acceptance timer
  - Accept or reject with a reason
  - Pack: IMEI must match the listing, plus a 4-point packing checklist
  - Courier pickup: Delhivery / Blue Dart / Ekart and a time slot, which generates an AWB
  - Printable shipping label with barcode, earnings breakdown, timeline, masked buyer phone
- **Listings**: status filters, search by model/ID/IMEI, inline stock +/−, pause/resume, change price, duplicate, delete
- **Add / edit listing (5 steps)**: photos (camera or gallery) → details → condition grade, battery health, IMEI (Luhn-checked), 8 function checks, box contents → price with smart price range and a live payout breakdown → buyer preview → submit for QC
- **Live Reviews**: confirm or decline buyer requests, a live video room with an inspection checklist, record whether the buyer bought
- **Earnings**: available vs in-settlement balance, withdraw, 30-day gross/fees/net, payout history with UTR
- **Store**: profile edit, performance (rating, on-time dispatch, seller cancels), verification status, settings, policies, sign out

Fees: 8% commission + ₹49 fixed fee + 18% GST on fees. Free shipping. Payouts 7 days after delivery.

Data is stored on the device (demo data on first launch) until the shared backend is connected.
