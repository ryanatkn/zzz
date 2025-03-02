<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {chatgpt_logo, claude_logo, gemini_logo, ollama_logo} from '@ryanatkn/fuz/logos.js';

	import type {Provider_Name} from '$lib/provider_types.js';

	interface Props {
		name: Provider_Name;
		fill?: string | null | undefined;
		size?: string;
		inline?: boolean;
		props?: ComponentProps<typeof Svg>;
	}

	const {
		name,
		fill = 'var(--text_color)',
		size = 'var(--size, var(--size_xl))', // TODO remove after changing the default in Svg.svelte upstream
		inline = true,
		props,
	}: Props = $props();

	const provider_logos = {
		chatgpt: chatgpt_logo,
		claude: claude_logo,
		gemini: gemini_logo,
		ollama: ollama_logo,
	};
</script>

<Svg data={provider_logos[name]} {...props} fill={fill ?? undefined} {size} {inline} />
