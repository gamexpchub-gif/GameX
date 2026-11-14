/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      fontFamily: { sans: ['Inter', 'system-ui', 'sans-serif'] },
      colors: {
        ink: '#0B1230',
        muted: '#5B6380',
        brand: { DEFAULT: '#1F5BFF', 50: '#EEF3FF', 100: '#DCE6FF', 600: '#1F5BFF', 700: '#1847CC' },
        violet: { DEFAULT: '#6A3DF5' },
      },
      boxShadow: { card: '0 1px 2px rgba(11,18,48,.04), 0 8px 24px -12px rgba(11,18,48,.12)' },
    },
  },
  plugins: [],
};
