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
	import {PUBLIC_WEBSOCKET_URL} from '$env/static/public';
	import {page} from '$app/state';
	import {onNavigate} from '$app/navigation';
	import {base} from '$app/paths';

	import {App} from '$lib/app.svelte.js';
	import Zzz_Root from '$lib/Zzz_Root.svelte';
	import {pkg_context} from '$lib/pkg.js';
	import {package_json, src_json} from '$lib/package.js';
	import {create_uuid} from '$lib/zod_helpers.js';
	import {Prompt_Json} from '$lib/prompt.svelte.js';
	import {cell_classes} from '$lib/cell_classes.js';
	import {Provider_Json} from '$lib/provider.svelte.js';
	import create_zzz_config from '$lib/config.js';
	import {Model_Json} from '$lib/model.svelte.js';
	import {
		send_mutations,
		receive_mutations,
		create_action_mutation_context,
	} from '$lib/mutations.js';
	import type {Action_Client, Action_Server} from '$lib/schemas.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	// TODO think through initialization
	onMount(() => {
		// TODO init properly from data
		const zzz_config = create_zzz_config();

		// TODO note the difference between these two APIs, look at both of them and see which makes more sense
		zzz.add_providers(zzz_config.providers.map((p) => Provider_Json.parse(p))); // TODO handle errors
		zzz.models.add_many(zzz_config.models.map((m) => Model_Json.parse(m))); // TODO handle errors
	});

	pkg_context.set(parse_package_meta(package_json, src_json));

	// Create an instance of Zzz with socket_url
	const zzz = new App({
		cell_classes,
		socket_url: PUBLIC_WEBSOCKET_URL,
		onsend: (message: Action_Client) => {
			console.log('[page] sending message via socket', message);
			zzz.socket.send({type: 'server_message', message});

			const mutation = send_mutations[message.type];
			if (mutation) {
				// Create proper mutation context for sending actions
				const ctx = create_action_mutation_context(
					zzz,
					message.type,
					message, // For client actions, params are the full message
					undefined, // Result is undefined for sending
				);

				mutation(ctx);
			}
		},
		onreceive: (message: Action_Server) => {
			console.log(`[page] received message`, message);

			const mutation = receive_mutations[message.type];
			if (mutation) {
				// Create proper mutation context for received actions
				const ctx = create_action_mutation_context(
					zzz,
					message.type,
					message, // For received actions, params are the full message
					{
						ok: true,
						status: 200, // TODO need to forward status, use JSON RPC like MCP
						value: message,
						zzz,
					},
				);

				mutation(ctx);
			}

			// Handle specific actions after mutation
			switch (message.type) {
				case 'loaded_session': {
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
				const data = devalue.parse(event.data.toString());
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
