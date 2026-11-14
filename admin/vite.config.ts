import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In dev, API calls and media go to the GAMEX server (cd server && npm start).
const target = process.env.GAMEX_API || 'http://localhost:8080';

// Served at https://admin.deencircle.online/hisab/ (override with ADMIN_BASE).
const base = process.env.ADMIN_BASE || '/hisab/';

export default defineConfig({
  base,
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    proxy: { [base + 'api']: target, [base + 'uploads']: target },
  },
});
