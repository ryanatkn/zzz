<script lang="ts">
	import '@ryanatkn/moss/style.css';
	import '@ryanatkn/moss/theme.css';
	import '$routes/moss.css';
	import '$routes/style.css';

	import Themed from '@ryanatkn/fuz/Themed.svelte';
	import {onMount, type Snippet} from 'svelte';
	import Contextmenu_Root from '@ryanatkn/fuz/Contextmenu_Root.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {parse_package_meta} from '@ryanatkn/gro/package_meta.js';
	import {BROWSER} from 'esm-env';
	import {page} from '$app/state';
	import {onNavigate} from '$app/navigation';
	import {base} from '$app/paths';

	import {App} from '$lib/app.svelte.js';
	import Zzz_Root from '$lib/Zzz_Root.svelte';
	import {pkg_context} from '$lib/pkg.js';
	import {package_json, src_json} from '$lib/package.js';
	import {Prompt_Json} from '$lib/prompt.svelte.js';
	import {Provider_Json} from '$lib/provider.svelte.js';
	import create_zzz_config from '$lib/config.js';
	import {Model_Json} from '$lib/model.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	// TODO think through initialization
	onMount(() => {
		// TODO BLOCK pull `futuremode` and others from the query params or hash

		// TODO init properly from data
		const zzz_config = create_zzz_config();

		// TODO note the difference between these two APIs, look at both of them and see which makes more sense
		zzz.add_providers(zzz_config.providers.map((p) => Provider_Json.parse(p))); // TODO handle errors
		zzz.models.add_many(zzz_config.models.map((m) => Model_Json.parse(m))); // TODO handle errors

		// Initialize the session
		if (BROWSER) {
			void zzz.api.load_session();
		}
	});

	pkg_context.set(parse_package_meta(package_json, src_json));

	// Create our client App, which extends the Zzz class
	const zzz = new App();

	// Enhance schemas with metadata for deserialization - use class names
	// Safely access Zod schema internals using type assertion
	const prompt_json_obj = Prompt_Json as unknown as {shape?: {bits?: {_def?: {type?: any}}}};
	if (prompt_json_obj.shape?.bits?._def?.type) {
		// Store class name instead of schema id
		prompt_json_obj.shape.bits._def.type.class_name = 'Bit';
	}

	if (BROWSER) (window as any).app = (window as any).zzz = zzz; // no types for this, just for runtime convenience

	// TODO refactor, maybe per route?
	// Handle URL parameter synchronization
	$effect.pre(() => {
		// TODO I think we want a different state value for this, so that we can render links to the "selected_id_recent" or something
		zzz.chats.selected_id = zzz.url_params.get_uuid_param('chat_id');
		zzz.prompts.selected_id = zzz.url_params.get_uuid_param('prompt_id');
	});

	// TODO refactor this, doesn't belong here - see the comment at `to_nav_link_href`
	onNavigate(() => {
		const {pathname} = page.url;
		if (pathname === `${base}/chats`) {
			zzz.chats.selected_id_last_non_null = null;
		} else if (pathname === `${base}/prompts`) {
			zzz.prompts.selected_id_last_non_null = null;
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
					zzz.api.toggle_main_menu(true);
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

<Themed>
	<Contextmenu_Root>
		<Zzz_Root {zzz}>
			{@render children()}
		</Zzz_Root>
	</Contextmenu_Root>
</Themed>
