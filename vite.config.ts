import {defineConfig} from 'vite';
import {sveltekit} from '@sveltejs/kit/vite';

export default defineConfig({
	plugins: [sveltekit()],
	server: {
		proxy: {
			'/api': 'http://localhost:3000', // equal to `PUBLIC_SERVER_HOSTNAME + ':' + PUBLIC_SERVER_PORT`
		},
	},
});
