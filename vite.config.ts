import {defineConfig} from 'vitest/config';
import {sveltekit} from '@sveltejs/kit/vite';

export default defineConfig({
	plugins: [sveltekit()],
	test: {}, // use `// @vitest-environment jsdom` in test files for Svelte tests
	// Tell Vitest to use the `browser` entry points in `package.json` files, even though it's running in Node
	resolve: process.env.VITEST
		? {
				conditions: ['browser'],
			}
		: undefined,
	server: {
		proxy: {
			'/api': 'http://localhost:8999', // equal to `PUBLIC_SERVER_HOSTNAME + ':' + PUBLIC_SERVER_PORT`
		},
	},
});
