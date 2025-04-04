<script lang="ts">
	import {base} from '$app/paths';
	import type {Snippet} from 'svelte';
	import {zzz_logo} from '@ryanatkn/fuz/logos.js';
	import {page} from '$app/state';
	import {onNavigate} from '$app/navigation';
	import Svg from '@ryanatkn/fuz/Svg.svelte';
	import {is_editable, swallow} from '@ryanatkn/belt/dom.js';

	import Nav_Link from '$lib/Nav_Link.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import {GLYPH_ARROW_LEFT, GLYPH_ARROW_RIGHT, GLYPH_SITE, GLYPH_TAB} from '$lib/glyphs.js';
	import {zzz_context} from '$lib/zzz.svelte.js';
	import {main_nav_items_default} from '$lib/nav.js';

	// TODO dashboard should be mounted with Markdown

	interface Props {
		children: Snippet;
	}

	const {children}: Props = $props();

	const zzz = zzz_context.get();

	const SIDEBAR_WIDTH_MAX = 180;
	const sidebar_width = $derived(zzz.ui.show_sidebar ? SIDEBAR_WIDTH_MAX : 0);

	let futureclicks = $state(0);
	const FUTURECLICKS = 3;
	// Track if futureclicks has been activated at least once
	let futureclicks_activated = $state(false);
	onNavigate((navigation) => {
		// Only reset clicks when navigating away from the root page
		// and we're not already in activated state
		if (
			!futureclicks_activated &&
			navigation.from?.route.id === '/' &&
			navigation.to?.route.id !== '/'
		) {
			console.log('resetting');
			futureclicks = 0;
		}
	});

	const dashboard_nav_items = $derived.by(() => {
		const nav_items = structuredClone(main_nav_items_default);

		if (zzz.futuremode) {
			// Add tabs to main group
			const main_group = nav_items.find((l) => l.group === 'main');
			if (main_group) {
				main_group.items.unshift({label: 'tabs', href: `${base}/tabs`, icon: GLYPH_TAB});
			}

			// Add sites to main group
			const main_section = nav_items.find((section) => section.group === 'main');
			if (main_section) {
				main_section.items.push({label: 'sites', href: `${base}/sites`, icon: GLYPH_SITE});
			}
		}

		return nav_items;
	});

	const sidebar_button_title = $derived(zzz.ui.show_sidebar ? 'hide sidebar' : 'show sidebar');
</script>

<svelte:window
	onkeydowncapture={(e) => {
		if (e.key === '`' && !is_editable(e.target)) {
			zzz.ui.toggle_sidebar();
			swallow(e);
		}
	}}
/>

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
				{#each dashboard_nav_items as section (section.group)}
					{#if section.group === 'main'}
						<div class="flex p_sm mb_sm">
							<Nav_Link
								href="{base}/"
								attrs={{
									title: zzz.futuremode ? 'futuremode' : 'home',
									class: 'click_effect_scale',
									onclick: () => {
										if (futureclicks_activated) {
											// If already activated once, toggle immediately when on root
											if (page.url.pathname === base + '/') {
												zzz.futuremode = !zzz.futuremode;
											}
										} else {
											futureclicks++;
											if (futureclicks >= FUTURECLICKS) {
												zzz.futuremode = !zzz.futuremode;
												futureclicks_activated = true;
											}
										}
									},
								}}
							>
								<Svg
									data={zzz_logo}
									size="var(--icon_size_md)"
									fill={zzz.futuremode ? 'var(--color_h_5)' : undefined}
									attrs={{
										style: 'transition: transform 200ms ease',
										class: zzz.futuremode ? 'flip_x' : '',
									}}
								/>
							</Nav_Link>
						</div>
					{:else}
						<div class="size_xl font_serif mt_xl7 mb_md text_color_3">
							{section.group}
						</div>
					{/if}

					{#each section.items as link (link.label)}
						<Nav_Link href={link.href}>
							{#snippet children(selected)}
								{#if typeof link.icon === 'string'}
									<Glyph icon={link.icon} attrs={{class: 'icon_xs'}} /> {link.label}
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

	<!-- Sidebar toggle button -->
	<!-- TODO shortcut key -->
	<button
		type="button"
		class="fixed b_0 l_0 icon_button plain radius_xs"
		style:border-bottom-left-radius="0"
		aria-label={sidebar_button_title}
		title={sidebar_button_title}
		onclick={() => zzz.ui.toggle_sidebar()}
	>
		<Glyph icon={zzz.ui.show_sidebar ? GLYPH_ARROW_LEFT : GLYPH_ARROW_RIGHT} />
	</button>
</div>
