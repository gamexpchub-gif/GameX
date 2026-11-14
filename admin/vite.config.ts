import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In dev, API calls and media go to the GAMEX server (cd server && npm start).
const target = process.env.GAMEX_API || 'http://localhost:8080';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
    proxy: { '/api': target, '/uploads': target },
  },
});
