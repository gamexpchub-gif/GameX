# GAMEX Super Admin

Web admin panel for the GAMEX app (React + Vite + TypeScript + Tailwind).

## Run

```bash
cd admin
npm install
npm run dev
```

Open http://localhost:5173 and sign in with any email and a password of 6+ characters (demo login).

## Pages

- **Dashboard**: revenue, orders, customers, live-review conversion, charts, recent orders, low-stock alerts
- **Orders**: filter, search, step-by-step fulfilment (pending → delivered), cancel/return, CSV export
- **Products**: add/edit/duplicate/delete, condition grade, battery, IMEI, featured toggle, bulk actions, CSV export
- **Live Reviews**: queue of "see it live" requests from the app; confirm, assign an expert, go live, mark bought or not bought
- **Customers**: tiers, lifetime value, order history, block/unblock
- **Home Banners**: the 4 home carousel banners, with reorder, show/hide, edit and a live phone preview
- **Coupons**: percent or flat codes, with minimum order, cap, usage limit and expiry
- **Settings**: shipping, COD, GST, live-review hours, maintenance mode

Data is stored in the browser (localStorage) for now. A backend API comes next so the app and the panel share data.
