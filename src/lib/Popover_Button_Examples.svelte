<script lang="ts">
	import {scale, fade} from 'svelte/transition';
	import Popover_Button from '$lib/Popover_Button.svelte';
	import {GLYPH_REMOVE} from '$lib/glyphs.js';

	interface Props {
		show_variants?: boolean;
	}

	const {show_variants = true}: Props = $props();

	// Mock data
	const color_options = ['bg_a', 'bg_b', 'bg_c', 'bg_d', 'bg_e', 'bg_f', 'bg_g', 'bg_h', 'bg_i'];
	let selected_color = $state('bg_c');

	// Helper function for keyboard handling
	const handle_keydown = (event: KeyboardEvent, callback: () => void) => {
		if (event.key === 'Enter' || event.key === ' ') {
			event.preventDefault();
			callback();
		}
	};
</script>

{#if show_variants}
	<div class="border_solid p_md radius_md">
		<h3 class="mt_0 mb_md">Popover Button Variants</h3>
		<div
			class="grid"
			style:grid-template-columns="repeat(auto-fit, minmax(220px, 1fr))"
			style:gap="var(--space_md)"
		>
			<!-- Basic usage -->
			<div>
				<h4>Basic tooltip</h4>
				<Popover_Button attrs={{class: 'plain'}} popover_class="bg_c_1 color_bg p_xs radius_md">
					{#snippet children(_popover)}
						Hover me
					{/snippet}

					{#snippet popover_content(_popover)}
						<div in:fade>This is a simple tooltip</div>
					{/snippet}
				</Popover_Button>
			</div>

			<!-- Button variations -->
			<div>
				<h4>Icon button</h4>
				<Popover_Button
					position="right"
					attrs={{class: 'icon_button bg_c_3 color_bg'}}
					popover_class="bg_c_1 color_bg p_sm radius_md max_width_sm"
				>
					{#snippet children(_popover)}
						?
					{/snippet}

					{#snippet popover_content(_popover)}
						<div in:fade>
							<strong>Help info</strong>
							<p class="m_0">This shows detailed help information for the user.</p>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<div>
				<h4>Text with icon</h4>
				<Popover_Button
					position="bottom"
					attrs={{class: 'flex gap_xs align_items_center plain'}}
					popover_class="bg_c_1 color_bg p_md radius_md"
				>
					{#snippet children(_popover)}
						<span class="icon">{GLYPH_REMOVE}</span>
						<span>Settings</span>
					{/snippet}

					{#snippet popover_content(popover)}
						<div in:scale={{duration: 100}}>
							<div class="mb_xs">Settings menu content</div>
							<button type="button" class="bg_c_3 color_bg" onclick={() => popover.hide()}
								>Close</button
							>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<!-- Positioning options -->
			<div>
				<h4>Top/start</h4>
				<Popover_Button
					position="top"
					align="start"
					attrs={{class: 'plain'}}
					popover_class="bg_c_1 color_bg p_xs radius_md"
				>
					{#snippet children(_popover)}
						Top start
					{/snippet}

					{#snippet popover_content(_popover)}
						<div in:fade>Popover at top/start</div>
					{/snippet}
				</Popover_Button>
			</div>

			<div>
				<h4>Bottom/end</h4>
				<Popover_Button
					position="bottom"
					align="end"
					attrs={{class: 'plain'}}
					popover_class="bg_c_1 color_bg p_xs radius_md"
				>
					{#snippet children(_popover)}
						Bottom end
					{/snippet}

					{#snippet popover_content(_popover)}
						<div in:fade>Popover at bottom/end</div>
					{/snippet}
				</Popover_Button>
			</div>

			<div>
				<h4>Center position</h4>
				<Popover_Button
					position="center"
					attrs={{class: 'plain'}}
					popover_class="bg_c_1 color_bg p_md radius_md text_align_center"
				>
					{#snippet children(_popover)}
						Center
					{/snippet}

					{#snippet popover_content(popover)}
						<div in:scale={{duration: 150}}>
							<div class="mb_sm">Centered dialog</div>
							<button type="button" class="bg_c_3 color_bg" onclick={() => popover.hide()}
								>Close</button
							>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<div>
				<h4>Overlay</h4>
				<Popover_Button
					position="overlay"
					attrs={{class: 'plain bg_c_4 color_bg p_xs radius_md'}}
					popover_class="bg_c_1 color_bg flex flex_column align_items_center justify_content_center"
				>
					{#snippet children(_popover)}
						Show fullscreen
					{/snippet}

					{#snippet popover_content(popover)}
						<div in:fade>
							<div class="mb_md text_align_center">
								<h3>Fullscreen overlay</h3>
								<p>This takes up the entire container</p>
							</div>
							<button
								type="button"
								class="bg_c_5 color_bg p_xs px_md radius_md"
								onclick={() => popover.hide()}
							>
								Close
							</button>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<!-- Custom popover content -->
			<div>
				<h4>List content</h4>
				<Popover_Button
					position="bottom"
					align="start"
					popover_class="bg_c_1 color_bg p_xs radius_md"
					attrs={{class: 'plain'}}
				>
					{#snippet children(_popover)}
						Show menu
					{/snippet}

					{#snippet popover_content(popover)}
						<div class="min_width_md" in:fade={{duration: 100}}>
							<button
								type="button"
								class="menu_item w_100 text_align_start"
								onclick={() => {
									console.log('Option 1');
									popover.hide();
								}}
								onkeydown={(e) =>
									handle_keydown(e, () => {
										console.log('Option 1');
										popover.hide();
									})}
							>
								Option 1
							</button>
							<button
								type="button"
								class="menu_item w_100 text_align_start"
								onclick={() => {
									console.log('Option 2');
									popover.hide();
								}}
								onkeydown={(e) =>
									handle_keydown(e, () => {
										console.log('Option 2');
										popover.hide();
									})}
							>
								Option 2
							</button>
							<button
								type="button"
								class="menu_item w_100 text_align_start"
								onclick={() => {
									console.log('Option 3');
									popover.hide();
								}}
								onkeydown={(e) =>
									handle_keydown(e, () => {
										console.log('Option 3');
										popover.hide();
									})}
							>
								Option 3
							</button>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<!-- Interactive content -->
			<div>
				<h4>Color picker</h4>
				<Popover_Button
					position="bottom"
					align="center"
					popover_class="bg_c_1 color_bg p_sm radius_md"
					attrs={{class: `${selected_color} color_bg p_xs px_sm radius_md`}}
				>
					{#snippet children(_popover)}
						Select color
					{/snippet}

					{#snippet popover_content(popover)}
						<div in:fade={{duration: 100}}>
							<div class="mb_xs">Choose a color:</div>
							<div
								class="grid"
								style:grid-template-columns="repeat(3, 1fr)"
								style:gap="var(--space_xs)"
							>
								{#each color_options as color}
									<button
										type="button"
										class="{color} color_bg p_sm radius_sm"
										onclick={() => {
											selected_color = color;
											popover.hide();
										}}
										onkeydown={(e) =>
											handle_keydown(e, () => {
												selected_color = color;
												popover.hide();
											})}
										aria-label="Select color {color}"
									></button>
								{/each}
							</div>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<div>
				<h4>Confirmation dialog</h4>
				<Popover_Button
					position="right"
					align="center"
					popover_class="bg_c_1 color_bg p_md radius_md"
					attrs={{class: 'bg_c_7 color_bg p_xs px_sm radius_md'}}
				>
					{#snippet children(_popover)}
						Delete account
					{/snippet}

					{#snippet popover_content(popover)}
						<div class="min_width_md" in:scale={{duration: 120}}>
							<h4 class="mt_0 mb_sm">Are you sure?</h4>
							<p class="mb_md">This action cannot be undone.</p>
							<div class="flex gap_sm">
								<button
									type="button"
									class="bg_c_7 color_bg p_xs px_sm radius_md"
									onclick={() => {
										console.log('Account deleted');
										popover.hide();
									}}
								>
									Confirm
								</button>
								<button
									type="button"
									class="bg_c_3 color_bg p_xs px_sm radius_md"
									onclick={() => popover.hide()}
								>
									Cancel
								</button>
							</div>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<!-- Advanced use cases -->
			<div>
				<h4>Mini form</h4>
				<Popover_Button
					position="bottom"
					align="start"
					disable_outside_click={true}
					popover_class="bg_c_1 color_bg p_md radius_md"
					attrs={{class: 'plain'}}
				>
					{#snippet children(_popover)}
						Add item
					{/snippet}

					{#snippet popover_content(popover)}
						<div class="min_width_md" in:scale={{duration: 100}}>
							<h4 class="mt_0 mb_sm">Add new item</h4>
							<div class="mb_sm">
								<input type="text" placeholder="Item name" class="w_100" />
							</div>
							<div class="flex gap_sm">
								<button
									type="button"
									class="bg_c_5 color_bg p_xs px_sm radius_md"
									onclick={() => {
										console.log('Item added');
										popover.hide();
									}}
								>
									Add
								</button>
								<button
									type="button"
									class="bg_c_3 color_bg p_xs px_sm radius_md"
									onclick={() => popover.hide()}
								>
									Cancel
								</button>
							</div>
						</div>
					{/snippet}
				</Popover_Button>
			</div>

			<div>
				<h4>Image preview</h4>
				<Popover_Button
					position="center"
					popover_class="bg_c_1 color_bg p_xs radius_md shadow_lg"
					attrs={{class: 'plain'}}
				>
					{#snippet children(_popover)}
						Preview image
					{/snippet}

					{#snippet popover_content(popover)}
						<div in:scale={{duration: 150}}>
							<div class="relative">
								<button
									type="button"
									class="absolute t_0 r_0 mt_xs mr_xs bg_c_1 color_bg radius_100 p_xs"
									style:line-height="0"
									onclick={() => popover.hide()}
								>
									<span class="icon size_xs">{GLYPH_REMOVE}</span>
								</button>
								<img
									src="https://placekitten.com/300/200"
									alt="Preview"
									width="300"
									height="200"
									style:display="block"
								/>
							</div>
						</div>
					{/snippet}
				</Popover_Button>
			</div>
		</div>
	</div>
{/if}
