<script lang="ts">
	import '@ryanatkn/moss/style.css';
	import '@ryanatkn/moss/theme.css';
	import '$routes/moss.css';
	import '$routes/style.css';

	import Themed from '@ryanatkn/fuz/Themed.svelte';
	import type {Snippet} from 'svelte';
	import Contextmenu_Root from '@ryanatkn/fuz/Contextmenu_Root.svelte';
	import {contextmenu_action} from '@ryanatkn/fuz/contextmenu_state.svelte.js';
	import {parse_package_meta} from '@ryanatkn/gro/package_meta.js';
	import * as devalue from 'devalue';
	import {create_deferred, type Deferred} from '@ryanatkn/belt/async.js';
	import {browser} from '$app/environment';
	import {page} from '$app/stores';
	import {Unreachable_Error} from '@ryanatkn/belt/error.js';

	import {Zzz} from '$lib/zzz.svelte.js';
	import Zzz_Root from '$lib/Zzz_Root.svelte';
	import {pkg_context} from '$routes/pkg.js';
	import {package_json, src_json} from '$routes/package.js';
	import {Zzz_Client} from '$lib/zzz_client.js';
	import {Agent} from '$lib/agent.svelte.js';
	import {random_id} from '$lib/id.js';
	import create_zzz_config from '$lib/config.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	// TODO load `project.json` in production to populate files

	const zzz_config = create_zzz_config();

	pkg_context.set(parse_package_meta(package_json, src_json));

	let ws: WebSocket | undefined;
	let ws_connecting: Deferred<void> | undefined;

	// gives app-wide support for Zzz
	const zzz = new Zzz({
		agents: zzz_config.agents.map((data) => new Agent({data})),
		client: new Zzz_Client({
			send: async (message) => {
				if (!browser) return;
				if (!ws) {
					console.log('[page] creating ws');
					ws = new WebSocket(`ws://${$page.url.hostname}:3000/ws`);
					console.log('[page] ws', ws);
					ws.addEventListener('open', () => {
						console.log('[page] ws.onopen');
						ws_connecting?.resolve();
					});
					ws.addEventListener('close', () => {
						console.log('[page] ws.onclose');
					});
					ws.addEventListener('message', (e) => {
						// last_receive_time = Date.now();
						// handle_message(e);
						const data = devalue.parse(e.data);
						console.log('[page] ws.onmessage', message);
						// TODO parse
						if (data.type === 'gro_server_message') {
							zzz.client.receive(data.message);
						} else {
							console.error('unknown message', data);
						}
					});
					ws_connecting = create_deferred<void>();
				}
				await ws_connecting?.promise;
				console.log('[page] sending zzz_client_message', message);
				ws.send(JSON.stringify({type: 'gro_server_message', message}));
			},
			receive: (message) => {
				console.log(`message`, message);
				// TODO where does this mutation code live?
				switch (message.type) {
					case 'loaded_session': {
						console.log(`[page] loaded_session`, message);
						for (const source_file of message.data.files.values()) {
							zzz.files_by_id.set(source_file.id, source_file);
						}
						break;
					}
					case 'prompt_response': {
						zzz.receive_prompt_response(message);
						break;
					}
					case 'filer_change': {
						zzz.receive_filer_change(message);
						break;
					}
					case 'echo': {
						zzz.receive_echo(message);
						break;
					}
					default:
						throw new Unreachable_Error(message);
				}
			},
		}),
	});
	if (browser) (window as any).zzz = zzz;
	$inspect(zzz.agents);

	// zzz.send({type: 'echo', data: 'echo from client'});
	zzz.client.send({id: random_id(), type: 'load_session'});
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
					zzz.data.show_main_menu = true;
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

<Zzz_Root {zzz}>
	<Themed>
		<Contextmenu_Root>
			{@render children()}
		</Contextmenu_Root>
	</Themed>
</Zzz_Root>
