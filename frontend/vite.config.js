import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  server: {
    // Same-origin in development: the browser talks to Vite, Vite forwards /api to Rails.
    proxy: {
      '/api': process.env.API_PROXY_TARGET || 'http://localhost:3000',
    },
  },
})
