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
	import {PUBLIC_SERVER_HOSTNAME, PUBLIC_SERVER_PORT} from '$env/static/public';
	import {BROWSER} from 'esm-env';
	import {Unreachable_Error} from '@ryanatkn/belt/error.js';
	import {page} from '$app/state';

	import Zzz_Root from '$lib/Zzz_Root.svelte';
	import {pkg_context} from '$routes/pkg.js';
	import {package_json, src_json} from '$routes/package.js';
	import {Uuid} from '$lib/zod_helpers.js';
	import {Prompt_Json} from '$lib/prompt.svelte.js';
	import {cell_classes} from '$lib/cell_classes.js';
	import {Zzz} from '$lib/zzz.svelte.js';
	import {Provider_Json} from '$lib/provider.svelte.js';
	import {Model_Json} from '$lib/model.svelte.js';
	import create_zzz_config from '$lib/config.js';
	import {Bit} from '$lib/bit.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	// TODO think through initialization
	onMount(async () => {
		const zzz_config = await create_zzz_config();

		// TODO note the difference between these two APIs, look at both of them and see which makes more sense
		zzz.add_providers(zzz_config.providers.map((p) => Provider_Json.parse(p))); // TODO handle errors
		zzz.models.add_many(zzz_config.models.map((m) => Model_Json.parse(m))); // TODO handle errors

		// TODO init properly
		zzz.chats.add();
		zzz.chats.add();
		zzz.chats.add();

		// Create prompts with bits using the new API
		const prompt1 = zzz.prompts.add();
		const bit1 = Bit.create(zzz, {type: 'text', content: 'one'});
		const bit2 = Bit.create(zzz, {type: 'text', content: '2'});
		const bit3 = Bit.create(zzz, {type: 'text', content: 'c'});

		prompt1.add_bit(bit1);
		prompt1.add_bit(bit2);
		prompt1.add_bit(bit3);

		// Create more prompts with bits
		const prompt2 = zzz.prompts.add();
		prompt2.add_bit(Bit.create(zzz, {type: 'text'}));

		const prompt3 = zzz.prompts.add();
		prompt3.add_bit(Bit.create(zzz, {type: 'text'}));
	});

	pkg_context.set(parse_package_meta(package_json, src_json));

	// Set the WebSocket URL
	const ws_url = BROWSER ? `ws://${PUBLIC_SERVER_HOSTNAME}:${PUBLIC_SERVER_PORT}/ws` : null;

	// Create an instance of Zzz with socket_url
	const zzz = new Zzz({
		cell_classes,
		socket_url: ws_url,
		onsend: (message) => {
			console.log('[page] sending message via socket', message);
			zzz.socket.send({type: 'server_message', message});
		},
		onreceive: (message) => {
			console.log(`[page] received message`, message);
			switch (message.type) {
				case 'loaded_session': {
					console.log(`[page] loaded_session`, message);
					// Set the zzz_dir property from the session data
					zzz.zzz_dir = message.data.zzz_dir;
					// Set the files from the session data
					for (const source_file of message.data.files) {
						zzz.diskfiles.handle_change({
							type: 'filer_change',
							id: Uuid.parse(undefined), // TODO shouldnt need to fake, maybe call an internal method directly? or do we want a single path?
							change: {type: 'add', path: source_file.id},
							source_file,
						});
					}
					break;
				}
				case 'completion_response': {
					// Simply use the message directly now that types are aligned
					zzz.receive_completion_response(message);
					break;
				}
				case 'filer_change': {
					zzz.diskfiles.handle_change(message);
					break;
				}
				case 'pong': {
					zzz.receive_pong(message);
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
		// Store class name instead of schema ID
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
					zzz.messages.receive(data.message);
				} else {
					console.error('unknown message', data);
				}
			} catch (err) {
				console.error('Error processing message', err);
			}
		};
	}

	if (BROWSER) (window as any).zzz = zzz; // no types for this, just for runtime convenience

	if (BROWSER) $inspect('providers', zzz.providers);

	// Initialize the session
	if (BROWSER) {
		zzz.messages.send({id: Uuid.parse(undefined), type: 'load_session'});
	}

	// TODO refactor how? schema with typesafe registration/dispatch?
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
		const file_id = zzz.url_params.get_uuid_param('file');
		if (file_id && zzz.diskfiles.items.by_id.has(file_id)) {
			zzz.diskfiles.select(file_id);
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
				content: 'Settings',
				icon: '?',
				run: () => {
					zzz.ui.show_main_dialog = true;
				},
			},
		},
		{
			snippet: 'text',
			props: {
				content: 'Reload',
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
