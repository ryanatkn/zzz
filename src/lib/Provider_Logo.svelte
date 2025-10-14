<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {chatgpt_logo, claude_logo, gemini_logo} from '@ryanatkn/fuz/logos.js';
	import type {Omit_Strict} from '@ryanatkn/belt/types.js';

	import type {Provider_Name} from '$lib/provider_types.js';
	import {ollama_logo} from '$lib/ollama_helpers.js';

	const {
		name,
		fill = 'var(--text_color)',
		size = 'var(--font_size, var(--font_size_xl))', // TODO remove after changing the default in Svg.svelte upstream
		inline = true,
		...rest
	}: Omit_Strict<ComponentProps<typeof Svg>, 'data'> & {
		name: Provider_Name;
		fill?: string | null | undefined;
		size?: string | undefined;
		inline?: boolean | undefined;
	} = $props();

	const provider_logos = {
		chatgpt: chatgpt_logo,
		claude: claude_logo,
		gemini: gemini_logo,
		ollama: ollama_logo,
	};
</script>

<Svg shrink={false} {...rest} data={provider_logos[name]} {fill} {size} {inline} />
