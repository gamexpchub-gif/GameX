# GAMEX Super Admin

Web admin panel for the GAMEX app (React + Vite + TypeScript + Tailwind).

## Run

The panel talks to the GAMEX server (see `../server/README.md`).

```bash
cd server && npm install && npm start      # API on :8080
cd admin && npm install && npm run dev     # panel on :5173 (proxies /api to :8080)
```

Or run `npm run build` once and open http://localhost:8080. The server hosts the built panel.

Login: `admin@gamex.in` / `gamex@123` (set `ADMIN_PASSWORD` on the server to change it).

## Pages

- **Dashboard**: marketplace GMV, orders, sellers and customers, plus alerts for the QC queue, KYC approvals and unaccepted orders
- **QC Checking**: inspect every seller listing (photos, automatic IMEI/duplicate/price/battery checks, the seller's function checks, a 6-point inspector checklist), then approve with a QR certificate, reject, or request changes
- **Orders**: every order across sellers; step in (accept/pack/ship/deliver/cancel/return) and see late sellers
- **Products**: all listings by seller and status; feature, delist, relist, QR certificate, CSV export
- **Sellers**: approve KYC, suspend or reinstate, GMV and cancel %, payouts, message one seller or announce to all
- **Customers**: tiers, lifetime value, order history, block or unblock (blocked customers can't order)
- **Live Reviews, Home Banners, Coupons, Settings**: all saved on the server and used by the apps
