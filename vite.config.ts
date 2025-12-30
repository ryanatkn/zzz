import {defineConfig} from 'vite';
import {sveltekit} from '@sveltejs/kit/vite';
import {vite_plugin_library_well_known} from '@fuzdev/fuz_ui/vite_plugin_library_well_known.js';

export default defineConfig(({mode}) => ({
	plugins: [sveltekit(), vite_plugin_library_well_known()],
	// In test mode, use browser conditions so Svelte's mount() resolves to the client version
	resolve: mode === 'test' ? {conditions: ['browser']} : undefined,
	server: {
		proxy: {
			'/api': 'http://localhost:8999', // equal to `PUBLIC_SERVER_HOST + ':' + PUBLIC_SERVER_PROXIED_PORT`
		},
	},
}));
