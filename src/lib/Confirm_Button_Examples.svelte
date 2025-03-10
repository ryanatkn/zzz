<script lang="ts">
	import Confirm_Button from '$lib/Confirm_Button.svelte';

	interface Props {
		show_variants?: boolean;
	}

	const {show_variants = true}: Props = $props();

	// Mock handlers
	const handle_delete = () => console.log('Item deleted');
</script>

{#if show_variants}
	<div class="border_solid p_md radius_md">
		<h3 class="mt_0 mb_md">Delete Button Variants</h3>
		<div
			class="grid"
			style:grid-template-columns="repeat(auto-fit, minmax(200px, 1fr))"
			style:gap="var(--space_md)"
		>
			<!-- Basic usage -->
			<div>
				<h4>Basic (left/center)</h4>
				<Confirm_Button onconfirm={handle_delete} />
			</div>

			<!-- Positioning variants -->
			<div>
				<h4>Right position</h4>
				<Confirm_Button onconfirm={handle_delete} position="right" />
			</div>

			<div>
				<h4>Top position</h4>
				<Confirm_Button onconfirm={handle_delete} position="top" />
			</div>

			<div>
				<h4>Bottom position</h4>
				<Confirm_Button onconfirm={handle_delete} position="bottom" />
			</div>

			<!-- Alignment options -->
			<div>
				<h4>left/start align</h4>
				<Confirm_Button onconfirm={handle_delete} position="left" align="start"
					>a<br />b<br />c</Confirm_Button
				>
			</div>
			<div>
				<h4>left/center align</h4>
				<Confirm_Button onconfirm={handle_delete} position="left" align="center"
					>a<br />b<br />c</Confirm_Button
				>
			</div>
			<div>
				<h4>left/end align</h4>
				<Confirm_Button onconfirm={handle_delete} position="left" align="end"
					>a<br />b<br />c</Confirm_Button
				>
			</div>
			<div>
				<h4>right/start align</h4>
				<Confirm_Button onconfirm={handle_delete} position="right" align="start"
					>a<br />b<br />c</Confirm_Button
				>
			</div>
			<div>
				<h4>right/center align</h4>
				<Confirm_Button onconfirm={handle_delete} position="right" align="center"
					>a<br />b<br />c</Confirm_Button
				>
			</div>
			<div>
				<h4>right/end align</h4>
				<Confirm_Button onconfirm={handle_delete} position="right" align="end"
					>a<br />b<br />c</Confirm_Button
				>
			</div>

			<div>
				<h4>top/start align</h4>
				<Confirm_Button onconfirm={handle_delete} position="top" align="start">
					button with content
				</Confirm_Button>
			</div>
			<div>
				<h4>top/center align</h4>
				<Confirm_Button onconfirm={handle_delete} position="top" align="center">
					button with content
				</Confirm_Button>
			</div>
			<div>
				<h4>top/end align</h4>
				<Confirm_Button onconfirm={handle_delete} position="top" align="end">
					button with content
				</Confirm_Button>
			</div>
			<div>
				<h4>bottom/start align</h4>
				<Confirm_Button onconfirm={handle_delete} position="bottom" align="start">
					button with content
				</Confirm_Button>
			</div>
			<div>
				<h4>bottom/center align</h4>
				<Confirm_Button onconfirm={handle_delete} position="bottom" align="center">
					button with content
				</Confirm_Button>
			</div>
			<div>
				<h4>bottom/end align</h4>
				<Confirm_Button onconfirm={handle_delete} position="bottom" align="end">
					button with content
				</Confirm_Button>
			</div>

			<!-- Custom titles -->
			<div>
				<h4>With title text</h4>
				<Confirm_Button onconfirm={handle_delete} attrs={{title: 'Delete'}} />
			</div>

			<div>
				<h4>Custom title with icon</h4>
				<Confirm_Button
					onconfirm={handle_delete}
					attrs={{
						class: 'plain flex gap_xs align_items_center',
						title: `<span class="icon">&times;</span> Remove`,
					}}
				/>
			</div>

			<!-- Custom styling -->
			<div>
				<h4>Custom button style</h4>
				<Confirm_Button
					onconfirm={handle_delete}
					attrs={{
						class: 'bg_c_3 color_bg p_xs radius_md',
					}}
				/>
			</div>

			<div>
				<h4>Custom confirm style</h4>
				<Confirm_Button
					onconfirm={handle_delete}
					position="bottom"
					popover_button_attrs={{
						class: 'bg_c_7 color_bg p_sm radius_md',
					}}
				/>
			</div>

			<!-- Interaction options -->
			<div>
				<h4>No outside click</h4>
				<Confirm_Button
					onconfirm={handle_delete}
					position="top"
					disable_outside_click={true}
					attrs={{title: 'Click to remove'}}
				/>
			</div>

			<!-- Specialized use cases -->
			<div>
				<h4>Warning style</h4>
				<Confirm_Button
					onconfirm={handle_delete}
					attrs={{
						class: 'bg_c_7 color_bg p_xs px_sm radius_md',
						title: 'Delete',
					}}
					popover_button_attrs={{
						class: 'bg_c_8 color_bg',
					}}
				/>
			</div>

			<div>
				<h4>Minimal style</h4>
				<Confirm_Button
					onconfirm={handle_delete}
					attrs={{
						class: 'plain color_6 size_xs',
					}}
				/>
			</div>

			<div>
				<h4>Center overlay</h4>
				<Confirm_Button
					onconfirm={handle_delete}
					position="center"
					attrs={{
						class: 'bg_c_4 color_bg p_xs radius_md',
						title: 'Delete Item',
					}}
					popover_button_attrs={{
						class: 'size_lg bg_c_7 color_bg',
					}}
				/>
			</div>
		</div>
	</div>
{/if}
