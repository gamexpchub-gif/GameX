# GAMEX Server

One backend for the whole marketplace:

- **GAMEX app** (customers) reads approved phones and sends orders, live-review requests and sign-ups.
- **GAMEX Seller app** lists phones (with photo uploads), handles orders, live reviews and payouts.
- **Super Admin panel** QC-checks every listing, approves sellers (KYC), manages customers, orders, banners and coupons.

Data is saved in `data/db.json` (created on first start with demo data). Uploaded photos go to `uploads/`.

## Start

```bash
cd admin && npm install && npm run build   # once, so the server can host the admin panel
cd ../server && npm install && npm start
```

The terminal prints:

```
GAMEX server running on port 8080
Admin panel:   http://localhost:8080
Phones (Wi-Fi): http://192.168.x.x:8080
Admin login:   admin@gamex.in / gamex@123
```

## Connect the phones

Either option works. Do it for both apps.

1. **USB cable**: run `adb reverse tcp:8080 tcp:8080`. The apps' default address `http://127.0.0.1:8080` then reaches your computer.
2. **Same Wi-Fi**: in the app open **Server connection** (Seller app: ⚙ on login or Store → Server connection; GAMEX app: Account → GAMEX Server), enter the `Phones (Wi-Fi)` address and tap **Save & test**.

You can also bake the address into a build with `flutter build apk --dart-define=API_URL=http://192.168.x.x:8080`.

## The flow

1. A seller adds a phone in the Seller app. It goes to **QC Checking** in the admin panel.
2. The admin inspects it (automatic IMEI, duplicate, price and battery checks plus a 6-point checklist) and approves it. That creates a QR certificate. The admin can also reject it or request changes, with a message to the seller.
3. Approved phones from approved (KYC) sellers appear in the GAMEX app's New Listings.
4. Customer orders reach the seller app (accept within 4h → pack with IMEI check → courier pickup → delivered). Each status update shows in the customer's Orders page.
5. Payouts settle 7 days after delivery. The seller withdraws, or the admin pays from **Sellers**.

## Settings

| Variable | Default |
| --- | --- |
| `PORT` | `8080` |
| `ADMIN_EMAIL` | `admin@gamex.in` |
| `ADMIN_PASSWORD` | `gamex@123` (change it before going live) |

To reset all demo data, use **Settings → Reset demo data** in the admin panel, or stop the server and delete `data/db.json`.
