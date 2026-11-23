# GAMEX launch setup

Everything in the code is ready. Each live service switches on when its keys
are added. Order that works best:

| # | Service | Time | Blocks |
|---|---------|------|--------|
| 1 | Release signing key | 5 min | Play Store, share links |
| 2 | Razorpay | 1-3 days (KYC) | Real payments |
| 3 | MSG91 + DLT | 3-7 days (DLT approval) | Real OTP login |
| 4 | Firebase | 15 min | Push when the app is closed |
| 5 | Shiprocket | 1 day (KYC) | Real AWB & tracking |
| 6 | Play Console | 1-3 days (verification) | Public app |

All commands run on **your computer** in the `GameX` folder. Secrets are typed
into the scripts (hidden), never into chat or git.

---

## 1. Release signing key (do this first)

```bash
bash scripts/android-keystore.sh
```

- Creates `~/gamex-keys/gamex-upload.jks` and `android/key.properties` + `merchant/android/key.properties`.
- Prints the **SHA-256** (needed for Firebase and share links).
- **Back up `~/gamex-keys/`** (Google Drive + pendrive). Losing it means you can't update the app.
- Apps signed with the new key replace the old test app only after one uninstall:
  `adb uninstall com.gamex.gamex_shop` and `adb uninstall com.gamex.seller`.

Build signed apps:

```bash
bash scripts/build-release.sh          # customer app: APK + AAB
bash scripts/build-release.sh seller   # seller app
```

## 2. Razorpay (payments)

1. Sign up at razorpay.com with the business PAN, GST (if any), bank account and website/app link
   (you can use `https://admin.deencircle.online/gamex/terms`).
2. Complete KYC (Account & Settings → Business details). Until approved you get **Test mode** keys.
3. Account & Settings → API Keys → Generate. Copy **Key ID** (`rzp_test_...` / `rzp_live_...`) and **Key Secret**.
4. Enable the methods you want: UPI, cards, wallets, **EMI** and **Pay Later** (Payment Methods page).
5. Add keys to the server: `bash deploy/set-secrets.sh` → `3`.

6. Webhooks → Add new webhook: URL `https://admin.deencircle.online/gamex/api/payments/razorpay/webhook`,
   events `refund.processed`, `refund.failed`, `payment.captured`, any secret → enter the same secret in step 5.

**Refunds are automatic:** when a return is approved for refund, a buyer refuses a prepaid parcel or a
prepaid order is cancelled, the server refunds through Razorpay. COD orders show up in
Admin → Returns → **Refunds** as "Pay to bank / UPI"; pay the buyer and press **Mark paid** with the UTR.

Test with `rzp_test_` keys first (Razorpay test cards / UPI `success@razorpay`), then switch to `rzp_live_`.

## 3. MSG91 (SMS OTP)

India requires DLT registration for every SMS.

1. Register your business on a DLT portal (Jio, Airtel, Vodafone Idea or BSNL) as **Principal Entity**.
2. Register a **Header** (sender ID), e.g. `GAMEXI`.
3. Register an **OTP / Service-Implicit content template**, for example:
   `{#var#} is your GAMEX login code. It is valid for 5 minutes. Do not share it with anyone. - GAMEX`
4. In MSG91: add the DLT Entity ID, header and template; create an **OTP template** with `##OTP##`
   in place of `{#var#}`.
5. Copy the **Auth key** (API keys) and the **OTP template ID**.
6. `bash deploy/set-secrets.sh` → `1`.

Before DLT is approved you can test with `7` (OTP test mode, shows the code in the app).
Turn it off again before launch.

## 4. Firebase (push notifications)

1. console.firebase.google.com → Add project → name `GAMEX` (Analytics optional).
2. Add app → **Android** → package name `com.gamex.gamex_shop`, SHA-1/SHA-256 from step 1 → Register.
3. Download **google-services.json** (do **not** put it in the project), then:
   ```bash
   bash scripts/firebase-config.sh ~/Downloads/google-services.json
   bash scripts/build-release.sh
   ```
4. Project settings → **Service accounts** → Generate new private key → save the JSON.
5. `bash deploy/set-secrets.sh` → `4` → path to that JSON.

Now price drops, offer replies, order and wallet updates reach phones even when the app is closed.

## 5. Shiprocket (courier)

1. Sign up at shiprocket.in, complete KYC, add a **pickup address** (note its name, e.g. `Primary`).
2. Settings → API → **Create an API user** (use a different email from your login).
3. `bash deploy/set-secrets.sh` → `5`.

When a seller taps **Ship**, GAMEX books the courier, gets a real AWB and the buyer sees live scans.
Sellers' pickup addresses must be added in Shiprocket too if they ship from their own shops.

## 6. Play Console

1. play.google.com/console → create a developer account (one-time fee, identity verification).
2. Create app **GAMEX** → upload `build/app/outputs/bundle/release/app-release.aab`.
3. **App content** → Privacy policy: `https://admin.deencircle.online/gamex/privacy`;
   Data deletion: `https://admin.deencircle.online/gamex/delete-account`.
4. Test and release → **App integrity** → copy the **App signing key SHA-256**.
5. `bash deploy/set-secrets.sh` → `6` (adds both the upload and Play SHA-256) so shared
   product links open the app directly.
6. Start with **Internal testing**, then Closed testing (needed for new personal accounts), then Production.

## Check status

```bash
bash deploy/set-secrets.sh   # then press s
```

or open Admin → **Settings → Launch setup**.

## Database & backups

The server stores everything in **PostgreSQL** (installed by `deploy.sh`; the old `db.json` is imported
once automatically). A full backup runs **every night at 03:30** into `/var/backups/gamex`
(database kept 14 days, uploaded photos 7 days).

```bash
ssh root@200.234.32.137 gamex-backup            # backup now
ssh root@200.234.32.137 ls -lh /var/backups/gamex
ssh root@200.234.32.137 gamex-restore /var/backups/gamex/<file>.dump   # asks you to type RESTORE
```

Off-site copy (recommended): set up `rclone` on the VPS and add `BACKUP_RCLONE_REMOTE=gdrive:gamex-backups`
to `/etc/gamex.env`.

## If something goes wrong

- Server log: `ssh root@200.234.32.137 journalctl -u gamex -n 100`
- Previous env files are kept as `/etc/gamex.env.bak.*` (last 5).
- Build download errors (Maven TLS / timeout): see the Maven mirror steps in the chat, or try another network.
