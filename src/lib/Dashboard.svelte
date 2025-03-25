<script lang="ts">
	import {base} from '$app/paths';
	import type {Snippet} from 'svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import Svg, {type Svg_Data} from '@ryanatkn/fuz/Svg.svelte';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import Glyph_Icon from '$lib/Glyph_Icon.svelte';
	import {
		GLYPH_CAPABILITY,
		GLYPH_CHAT,
		GLYPH_FILE,
		GLYPH_LOG,
		GLYPH_MODEL,
		GLYPH_PROMPT,
		GLYPH_PROVIDER,
		GLYPH_SETTINGS,
		GLYPH_SITE,
		GLYPH_TAB,
	} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	const SIDEBAR_WIDTH_MAX = 200;
	const sidebar_width = $state(SIDEBAR_WIDTH_MAX);

	// TODO dashboard should be mounted with Markdown

	const zzz = zzz_context.get();

	let logo_clicks = $state(0);

	interface Nav_Link_Item {
		label: string;
		href: string;
		icon: string | Svg_Data;
	}
	interface Nav_Section {
		group: string;
		items: Array<Nav_Link_Item>;
	}
	const nav_links: Array<Nav_Section> = $derived([
		{
			group: 'main',
			items: [
				zzz.futuremode ? {label: 'tabs', href: `${base}/tabs`, icon: GLYPH_TAB} : null,
				{label: 'chats', href: `${base}/chats`, icon: GLYPH_CHAT},
				{label: 'prompts', href: `${base}/prompts`, icon: GLYPH_PROMPT},
				{label: 'files', href: `${base}/files`, icon: GLYPH_FILE},
				zzz.futuremode ? {label: 'sites', href: `${base}/sites`, icon: GLYPH_SITE} : null,
			].filter((v) => !!v),
		},
		{
			group: 'ai',
			items: [
				{label: 'models', href: `${base}/models`, icon: GLYPH_MODEL},
				{label: 'providers', href: `${base}/providers`, icon: GLYPH_PROVIDER},
			],
		},
		{
			group: 'system',
			items: [
				{label: 'about', href: `${base}/about`, icon: zzz_logo},
				{label: 'log', href: `${base}/log`, icon: GLYPH_LOG},
				{label: 'capabilities', href: `${base}/capabilities`, icon: GLYPH_CAPABILITY},
				{label: 'settings', href: `${base}/settings`, icon: GLYPH_SETTINGS},
			],
		},
	]);
</script>

<!-- TODO drive with data -->
<div class="dashboard" style:--sidebar_width="{sidebar_width}px">
	<div class="h_100 w_100 fixed t_0 l_0" style:padding-left="var(--sidebar_width)">
		{@render children()}
	</div>
	<div
		class="h_100 fixed t_0 l_0 overflow_auto scrollbar_width_thin"
		style:width="var(--sidebar_width)"
	>
		<!-- TODO refactor -->
		<div class="p_sm">
			<!-- TODO support `max_height_100` in Moss -->
			<nav class="size_lg">
				<div
					class="flex p_sm mb_sm"
					role="none"
					onclick={() => {
						logo_clicks++;
						if (logo_clicks >= 3) {
							zzz.futuremode = !zzz.futuremode;
						}
					}}
				>
					<Nav_Link
						href="{base}/"
						attrs={{
							title: 'home',
							style: 'width: auto; background: transparent',
							class: 'click_effect_scale',
						}}
					>
						<Svg
							data={zzz_logo}
							size="var(--icon_size_md)"
							fill={zzz.futuremode ? 'var(--color_h_5)' : undefined}
						/>
					</Nav_Link>
				</div>

				{#each nav_links as section (section.group)}
					{#if section.group !== 'main'}
						<div class="size_xl font_serif mt_xl7 mb_md text_color_3">
							{section.group}
						</div>
					{/if}

					{#each section.items as link (link.label)}
						<Nav_Link href={link.href}>
							{#snippet children(selected)}
								{#if typeof link.icon === 'string'}
									<Glyph_Icon icon={link.icon} attrs={{class: 'icon_xs'}} /> {link.label}
								{:else}
									<span class="icon_xs">
										<Svg
											data={link.icon}
											fill={selected ? 'var(--link_color)' : 'var(--text_color_1)'}
											size="var(--icon_size_xs)"
										/>
									</span>
									{link.label}
								{/if}
							{/snippet}
						</Nav_Link>
					{/each}
				{/each}
			</nav>
		</div>
	</div>
</div>
