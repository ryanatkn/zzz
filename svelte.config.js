import {vitePreprocess} from '@sveltejs/vite-plugin-svelte';
import {create_csp_directives} from '@ryanatkn/fuz/csp.js';
import {csp_trusted_sources_of_ryanatkn} from '@ryanatkn/fuz/csp_of_ryanatkn.js';

// Dynamically import adapter based on the ZZZ_BUILD env var.
// ZZZ_BUILD=node for production Node server, otherwise static for GitHub Pages.
const build_mode = process.env.ZZZ_BUILD;
const is_node_build = build_mode === 'node';

const adapter_module = is_node_build
	? await import('@sveltejs/adapter-node')
	: await import('@sveltejs/adapter-static');

const adapter = adapter_module.default;

/** @type {import('@sveltejs/kit').Config} */
export default {
	preprocess: [vitePreprocess()],
	compilerOptions: {runes: true},
	vitePlugin: {inspector: true},
	kit: {
		adapter: adapter(),
		paths: {relative: false}, // use root-absolute paths for SSR path comparison: https://kit.svelte.dev/docs/configuration#paths
		alias: {$routes: 'src/routes'},
		csp: {
			directives: create_csp_directives({
				trusted_sources: csp_trusted_sources_of_ryanatkn,
				directives: {
					'connect-src': [
						'self',
						// TODO switch to use env vars
						'ws://localhost:8999',
					],
					'frame-src': [
						'self',
						// enable iframing for the example sites
						'https://moss.ryanatkn.com/',
						'https://fuz.dev/',
						'https://*.fuz.dev/',
					],
				},
			}),
		},
		prerender: {
			handleUnseenRoutes: 'ignore',
		},
	},
};
