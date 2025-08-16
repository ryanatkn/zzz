import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import aiControlPlugin from './ai_control_vite_plugin.ts';

export default defineConfig({
  plugins: [svelte(), aiControlPlugin()],
  server: {
    port: 3000,
    open: true
  }
});