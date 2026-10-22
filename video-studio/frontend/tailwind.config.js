/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          yellow: '#FFE600',
          dark: '#0F172A',
          card: '#1E293B',
          accent: '#38BDF8'
        }
      }
    },
  },
  plugins: [],
}
