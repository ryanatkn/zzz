<script lang="ts">
	import type {ComponentProps} from 'svelte';
	import Svg from '@fuzdev/fuz_ui/Svg.svelte';
	import {chatgpt_logo, claude_logo, gemini_logo} from '@fuzdev/fuz_ui/logos.js';
	import type {OmitStrict} from '@fuzdev/fuz_util/types.js';

	import type {ProviderName} from './provider_types.js';
	import {ollama_logo} from './ollama_helpers.js';

	const {
		name,
		fill = 'var(--text_color)',
		size = 'var(--font_size, var(--font_size_xl))', // TODO remove after changing the default in Svg.svelte upstream
		inline = true,
		...rest
	}: OmitStrict<ComponentProps<typeof Svg>, 'data'> & {
		name: ProviderName;
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
