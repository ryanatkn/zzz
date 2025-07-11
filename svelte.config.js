import {vitePreprocess} from '@sveltejs/vite-plugin-svelte';
import adapter from '@sveltejs/adapter-static';
import {create_csp_directives} from '@ryanatkn/fuz/csp.js';
import {csp_trusted_sources_of_ryanatkn} from '@ryanatkn/fuz/csp_of_ryanatkn.js';

/** @type {import('@sveltejs/kit').Config} */
export default {
	preprocess: [vitePreprocess()],
	compilerOptions: {runes: true},
	vitePlugin: {inspector: true},
	kit: {
		adapter: adapter({fallback: '404.html'}), // for Github Pages
		paths: {relative: false}, // use root-absolute paths: https://kit.svelte.dev/docs/configuration#paths
		alias: {$routes: 'src/routes'},
		csp: {
			directives: create_csp_directives({
				trusted_sources: csp_trusted_sources_of_ryanatkn,
				directives: {
					'connect-src': [
						'self',
						// TODO switch these to use env vars
						'ws://localhost:8999',
						'http://127.0.0.1:11434', // for Ollama, OLLAMA_URL
					],
					'frame-src': [
						'self',
						// enable iframing for the example sites
						'https://ryanatkn.com/',
						'https://*.ryanatkn.com/',
						'https://fuz.dev/',
						'https://*.fuz.dev/',
					],
				},
			}),
		},
	},
};
