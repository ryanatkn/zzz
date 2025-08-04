<script lang="ts">
	import '@ryanatkn/moss/style.css';
	import '@ryanatkn/moss/theme.css';
	import '$routes/moss.css';
	import '$routes/style.css';

	import {onMount, type Snippet} from 'svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {parse_pkg} from '@ryanatkn/belt/pkg.js';
	import {BROWSER} from 'esm-env';
	import {page} from '$app/state';
	import {onNavigate} from '$app/navigation';
	import {base} from '$app/paths';

	import {App} from '$lib/app.svelte.js';
	import Frontend_Root from '$lib/Frontend_Root.svelte';
	import {pkg_context} from '$lib/pkg.js';
	import {package_json, src_json} from '$lib/package.js';
	import {Prompt_Json} from '$lib/prompt.svelte.js';
	import {Provider_Json} from '$lib/provider.svelte.js';
	import create_zzz_config from '$lib/config.js';
	import {Model_Json} from '$lib/model.svelte.js';

	const {
		children,
	}: {
		children: Snippet;
	} = $props();

	// TODO think through initialization
	onMount(() => {
		// TODO init properly from data
		const zzz_config = create_zzz_config();

		// TODO note the difference between these two APIs, look at both of them and see which makes more sense
		app.add_providers(zzz_config.providers.map((p) => Provider_Json.parse(p))); // TODO handle errors
		app.models.add_many(zzz_config.models.map((m) => Model_Json.parse(m))); // TODO handle errors

		// init the session
		if (BROWSER) {
			void app.api.load_session();
		}

		// init Ollama
		if (BROWSER) {
			void app.ollama.refresh();
		}
	});

	pkg_context.set(parse_pkg(package_json, src_json));

	// Create the frontend's App, which extends Frontend
	const app = new App();

	// Enhance schemas with metadata for deserialization - use class names
	// Safely access Zod schema internals using type assertion
	const prompt_json_obj = Prompt_Json as unknown as {shape?: {bits?: {_def?: {type?: any}}}};
	if (prompt_json_obj.shape?.bits?._def?.type) {
		// Store class name instead of schema id
		prompt_json_obj.shape.bits._def.type.class_name = 'Bit';
	}

	if (BROWSER) (window as any).app = (window as any).app = app; // no types for this, just for runtime convenience

	// TODO refactor, maybe per route?
	// Handle URL parameter synchronization
	$effect.pre(() => {
		// TODO I think we want a different state value for this, so that we can render links to the "selected_id_recent" or something
		app.chats.selected_id = app.url_params.get_uuid_param('chat_id');
		app.prompts.selected_id = app.url_params.get_uuid_param('prompt_id');
	});

	// TODO refactor this, doesn't belong here - see the comment at `to_nav_link_href`
	onNavigate(() => {
		const {pathname} = page.url;
		if (pathname === `${base}/chats`) {
			app.chats.selected_id_last_non_null = null;
		} else if (pathname === `${base}/prompts`) {
			app.prompts.selected_id_last_non_null = null;
		}
	});
</script>

<svelte:head>
	<title>Zzz</title>
</svelte:head>

<svelte:body
	use:contextmenu_action={[
		{
			snippet: 'text',
			props: {
				content: 'settings',
				icon: '?',
				run: () => {
					console.log('show main dialog');
					app.api.toggle_main_menu({show: true});
				},
			},
		},
		{
			snippet: 'text',
			props: {
				content: 'reload',
				icon: '⟳',
				run: () => {
					location.reload();
				},
			},
		},
	]}
/>

<Frontend_Root {app}>
	{@render children()}
</Frontend_Root>
