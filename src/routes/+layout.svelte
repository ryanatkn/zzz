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
	import * as devalue from 'devalue';
	import {BROWSER} from 'esm-env';
	import {Unreachable_Error} from '@ryanatkn/belt/error.js';
	import {page} from '$app/state';
	import {PUBLIC_WEBSOCKET_URL} from '$env/static/public';

	import {App} from '$lib/app.svelte.js';
	import Zzz_Root from '$lib/Zzz_Root.svelte';
	import {pkg_context} from '$routes/pkg.js';
	import {package_json, src_json} from '$routes/package.js';
	import {create_uuid} from '$lib/zod_helpers.js';
	import {Prompt_Json} from '$lib/prompt.svelte.js';
	import {cell_classes} from '$lib/cell_classes.js';
	import {Provider_Json} from '$lib/provider.svelte.js';
	import create_zzz_config from '$lib/config.js';
	import {Bit} from '$lib/bit.svelte.js';
	import {Model_Json} from '$lib/model.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	// TODO think through initialization
	onMount(() => {
		const zzz_config = create_zzz_config();

		// TODO note the difference between these two APIs, look at both of them and see which makes more sense
		zzz.add_providers(zzz_config.providers.map((p) => Provider_Json.parse(p))); // TODO handle errors
		zzz.models.add_many(zzz_config.models.map((m) => Model_Json.parse(m))); // TODO handle errors

		// TODO init properly from data
		zzz.chats.add();
		zzz.chats.add();
		zzz.chats.add();

		// Create prompts with bits using the new API
		const prompt1 = zzz.prompts.add();
		prompt1.add_bit(Bit.create(zzz, {type: 'text', content: 'one'}));
		prompt1.add_bit(Bit.create(zzz, {type: 'text', content: '2'}));
		prompt1.add_bit(Bit.create(zzz, {type: 'diskfile'}));
		prompt1.add_bit(Bit.create(zzz, {type: 'sequence'}));

		// Create more prompts with bits
		const prompt2 = zzz.prompts.add();
		prompt2.add_bit(Bit.create(zzz, {type: 'text'}));

		const prompt3 = zzz.prompts.add();
		prompt3.add_bit(Bit.create(zzz, {type: 'text'}));
	});

	pkg_context.set(parse_package_meta(package_json, src_json));

	// Create an instance of Zzz with socket_url
	const zzz = new App({
		cell_classes,
		socket_url: PUBLIC_WEBSOCKET_URL,
		onsend: (message) => {
			console.log('[page] sending message via socket', message);
			zzz.socket.send({type: 'server_message', message});
		},
		onreceive: (message) => {
			console.log(`[page] received message`, message);
			switch (message.type) {
				case 'loaded_session': {
					console.log(`[page] loaded_session`, message);
					zzz.receive_session(message.data);
					break;
				}
				case 'completion_response': {
					zzz.receive_completion_response(message);
					break;
				}
				case 'filer_change': {
					zzz.diskfiles.handle_change(message);
					break;
				}
				case 'pong': {
					zzz.capabilities.receive_pong(message);
					break;
				}
				default:
					throw new Unreachable_Error(message);
			}
		},
	});

	// Enhance schemas with metadata for deserialization - use class names
	// Safely access Zod schema internals using type assertion
	const prompt_json_obj = Prompt_Json as unknown as {shape?: {bits?: {_def?: {type?: any}}}};
	if (prompt_json_obj.shape?.bits?._def?.type) {
		// Store class name instead of schema id
		prompt_json_obj.shape.bits._def.type.class_name = 'Bit';
	}

	// Set up the socket message handler
	if (BROWSER) {
		// Configure socket message handler
		zzz.socket.onmessage = (event) => {
			try {
				const data = devalue.parse(event.data);
				console.log('[page] socket message received', data);
				if (data.type === 'server_message') {
					zzz.actions.receive(data.message);
				} else {
					console.error('unknown message', data);
				}
			} catch (err) {
				console.error('Error processing message', err);
			}
		};
	}

	if (BROWSER) (window as any).app = (window as any).zzz = zzz; // no types for this, just for runtime convenience

	// Initialize the session
	if (BROWSER) {
		zzz.actions.send({id: create_uuid(), type: 'load_session'});
	}

	// TODO refactor, try to remove - how? schema with typesafe registration/dispatch?
	// Handle URL parameter synchronization
	$effect.pre(() => {
		// Re-run when URL search params change
		page.url.search;

		// TODO should these select null if present but not found? maybe one UX is better overall? also maybe clear invalid values from the url?

		// Sync chat selection
		const chat_id = zzz.url_params.get_uuid_param('chat');
		if (chat_id && zzz.chats.items.by_id.has(chat_id)) {
			zzz.chats.select(chat_id);
		}

		// Sync prompt selection
		const prompt_id = zzz.url_params.get_uuid_param('prompt');
		if (prompt_id && zzz.prompts.items.by_id.has(prompt_id)) {
			zzz.prompts.select(prompt_id);
		}

		// Sync file selection
		const diskfile_id = zzz.url_params.get_uuid_param('file');
		if (diskfile_id && zzz.diskfiles.items.by_id.has(diskfile_id)) {
			zzz.diskfiles.select(diskfile_id);
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
					zzz.ui.show_main_dialog = true;
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
