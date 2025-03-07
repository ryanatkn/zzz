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
	import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
	import {browser} from '$app/environment';
	import {Unreachable_Error} from '@ryanatkn/belt/error.js';
	import {PUBLIC_SERVER_HOSTNAME, PUBLIC_SERVER_PORT} from '$env/static/public';

	import Zzz_Root from '$lib/Zzz_Root.svelte';
	import {pkg_context} from '$routes/pkg.js';
	import {package_json, src_json} from '$routes/package.js';
	import {Uuid} from '$lib/zod_helpers.js';
	import {zzz_config} from '$lib/zzz_config.js';
	import type {Diskfile_Path} from '$lib/diskfile_types.js';
	import {Prompt_Json} from '$lib/prompt.svelte.js';
	import {Zzz, cell_classes} from '$lib/zzz.svelte.js';
	import {Provider_Json} from '$lib/provider.svelte.js';
	import {Model_Json} from '$lib/model.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	pkg_context.set(parse_package_meta(package_json, src_json));

	let ws: WebSocket | undefined;
	let ws_connecting: Deferred<void> | undefined;

	// Create an instance of Zzz
	const zzz = new Zzz({
		cells: cell_classes,
	});

	// No more individual register calls needed!

	// Enhance schemas with metadata for deserialization - use class names
	// Safely access Zod schema internals using type assertion
	const prompt_json_obj = Prompt_Json as unknown as {shape?: {bits?: {_def?: {type?: any}}}};
	if (prompt_json_obj.shape?.bits?._def?.type) {
		// Store class name instead of schema ID
		prompt_json_obj.shape.bits._def.type.class_name = 'Bit';
	}

	// Add providers and models from config
	zzz.add_providers(zzz_config.providers.map((p) => Provider_Json.parse(p))); // TODO BLOCK @many probably want a config helper to bake the raw config, parsing should be an upstream concern
	zzz.add_models(zzz_config.models.map((m) => Model_Json.parse(m))); // TODO BLOCK @many probably want a config helper to bake the raw config, parsing should be an upstream concern

	zzz.messages.set_handlers(
		// Message sending handler
		async (message) => {
			if (!browser) return;
			if (!ws) {
				console.log('[page] creating ws');
				ws = new WebSocket(`ws://${PUBLIC_SERVER_HOSTNAME}:${PUBLIC_SERVER_PORT}/ws`);
				console.log('[page] ws', ws);
				ws.addEventListener('open', () => {
					console.log('[page] ws.onopen');
					ws_connecting?.resolve();
				});
				ws.addEventListener('close', () => {
					console.log('[page] ws.onclose');
				});
				ws.addEventListener('message', (e) => {
					const data = devalue.parse(e.data);
					console.log('[page] ws.onmessage', data);
					if (data.type === 'gro_server_message') {
						zzz.messages.receive(data.message);
					} else {
						console.error('unknown message', data);
					}
				});
				ws_connecting = create_deferred<void>();
			}
			await ws_connecting?.promise;
			console.log('[page] sending message', message);
			ws.send(JSON.stringify({type: 'gro_server_message', message}));
		},
		// Message receiving handler
		(message) => {
			console.log(`[page] received message`, message);
			switch (message.type) {
				case 'loaded_session': {
					console.log(`[page] loaded_session`, message);
					for (const [path_id, source_file] of Object.entries(message.data.files)) {
						if (!source_file) continue;
						zzz.diskfiles.handle_change({
							type: 'filer_change',
							id: Uuid.parse(undefined),
							change: {type: 'add', path: path_id as Diskfile_Path},
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
	);

	if (browser) (window as any).zzz = zzz; // no types for this, just for runtime convenience

	// TODO BLOCK refactor with capabilities
	onMount(async () => {
		await zzz.init_models();
		// TODO init properly
		zzz.chats.add();
		zzz.chats.add();
		zzz.chats.add();
		const prompt = zzz.prompts.add();
		prompt.add_bit('one');
		prompt.add_bit('2');
		prompt.add_bit('c');
		zzz.prompts.add().add_bit();
		zzz.prompts.add().add_bit();
	});

	$inspect('providers', zzz.providers);

	// Initialize the session
	zzz.messages.send({id: Uuid.parse(undefined), type: 'load_session'});
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
