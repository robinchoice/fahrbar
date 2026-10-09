import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';

export default defineConfig({
  plugins: [sveltekit()],
  // In production hooks.server.ts forwards /api to the API service. API_INTERNAL_URL
  // moves the API in dev when another project holds port 3000.
  server: { proxy: { '/api': process.env.API_INTERNAL_URL || 'http://localhost:3000' } },
});
