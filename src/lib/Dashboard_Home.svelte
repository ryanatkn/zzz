<script lang="ts">
	import {base} from '$app/paths';

	import {frontend_context} from '$lib/frontend.svelte.js';
	import Actions_List from '$lib/Action_List.svelte';
	import Glyph from '$lib/Glyph.svelte';
	import Provider_Link from '$lib/Provider_Link.svelte';
	import Prompt_List from '$lib/Prompt_List.svelte';
	import Chat_List from '$lib/Chat_List.svelte';
	import Model_Link from '$lib/Model_Link.svelte';
	import {GLYPH_LOG, GLYPH_PROVIDER, GLYPH_MODEL} from '$lib/glyphs.js';
	import {to_nav_link_href} from '$lib/nav.js';
	import {GLYPH_ADD} from '$lib/glyphs.js';

	const app = frontend_context.get();
</script>

<div class="p_lg">
	<section class="display_flex align_items_start gap_lg">
		<div class="panel p_md flex_1 width_sm">
			<h3 class="mt_0 mb_lg display_flex align_items_center justify_content_space_between">
				<a class="font_weight_500" href={to_nav_link_href(app, 'chats', `${base}/chats`)}>chats</a>
				<button
					type="button"
					class="plain icon_button font_size_md"
					onclick={() => {
						const chat = app.chats.add();
						void app.chats.navigate_to(chat.id);
					}}
				>
					<Glyph glyph={GLYPH_ADD} />
				</button>
			</h3>
			{#if app.chats.ordered_items.length}
				<Chat_List />
			{:else}
				<div class="text_align_center p_md">
					<button
						type="button"
						class="color_a"
						onclick={() => {
							const chat = app.chats.add();
							void app.chats.navigate_to(chat.id);
						}}
					>
						create a new chat
					</button>
				</div>
			{/if}
		</div>
		<div class="panel p_md flex_1 width_sm">
			<h3 class="mt_0 mb_lg display_flex align_items_center justify_content_space_between">
				<a class="font_weight_500" href={to_nav_link_href(app, 'prompts', `${base}/prompts`)}
					>prompts</a
				>
				<button
					type="button"
					class="plain icon_button font_size_md"
					onclick={() => {
						const prompt = app.prompts.add();
						void app.prompts.navigate_to(prompt.id);
					}}
				>
					<Glyph glyph={GLYPH_ADD} />
				</button>
			</h3>
			{#if app.prompts.ordered_items.length}
				<Prompt_List />
			{:else}
				<div class="text_align_center p_md">
					<button
						type="button"
						onclick={() => {
							const prompt = app.prompts.add();
							void app.prompts.navigate_to(prompt.id);
						}}
					>
						create a new prompt
					</button>
				</div>
			{/if}
		</div>
	</section>
	<div class="display_flex align_items_start flex_wrap gap_lg mt_lg">
		<section class="panel p_md mb_0 flex_1 min_width_sm" style:max-width="480px">
			<div class="mb_lg">
				<a href="{base}/log"
					><Glyph glyph={GLYPH_LOG} />
					<h3 class="display_inline my_0">log</h3></a
				>
			</div>
			<Actions_List limit={5} attrs={{class: 'mt_sm'}} />
		</section>

		<section class="panel p_md mb_0 flex_1 min_width_sm" style:max-width="480px">
			<div class="mb_lg">
				<a href="{base}/providers"
					><Glyph glyph={GLYPH_PROVIDER} />
					<h3 class="display_inline my_0">providers</h3></a
				>
			</div>
			<div>
				<ul class="unstyled">
					{#each app.providers.items as provider (provider.name)}
						<li class="mb_xs">
							<Provider_Link
								{provider}
								icon="svg"
								class="menu_item row justify_content_start gap_xs"
							/>
						</li>
					{:else}
						<p>no providers configured yet</p>
					{/each}
				</ul>
			</div>
		</section>

		<section class="panel p_md mb_0 flex_1 min_width_sm" style:max-width="480px">
			<div class="mb_lg">
				<a href="{base}/models"
					><Glyph glyph={GLYPH_MODEL} />
					<h3 class="display_inline my_0">models</h3></a
				>
			</div>
			<div>
				<ul class="unstyled">
					{#each app.models.ordered_by_name as model (model.name)}
						<li class="mb_xs">
							<Model_Link {model} icon class="menu_item row justify_content_start gap_xs" />
						</li>
					{:else}
						<p>no models available yet</p>
					{/each}
				</ul>
			</div>
		</section>
	</div>
</div>
