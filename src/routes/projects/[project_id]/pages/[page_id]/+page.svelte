<script lang="ts">
	import {goto} from '$app/navigation';

	import {projects_context} from '../../../projects.svelte.js';
	import Project_Sidebar from '../../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../../Section_Sidebar.svelte';
	import Pages_Sidebar from '../../../Pages_Sidebar.svelte';
	import {GLYPH_DELETE, GLYPH_PREVIEW, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const projects = projects_context.get();
	const zzz = zzz_context.get();

	const editor = $derived(projects.current_page_editor);

	// Preview mode state
	let preview_mode = $state(false);

	// Toggle preview mode
	const toggle_preview = () => {
		preview_mode = !preview_mode;
	};

	// TODO refactor with proper state/API
	/** Delete the current page and navigate back to pages list. */
	const delete_page = () => {
		const controller = projects.current_project_controller;
		if (!editor?.project || !editor.current_page || !controller) {
			return;
		}

		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to delete this page? This action cannot be undone.')) {
			controller.delete_project_page(editor.page_id);

			// Navigate back to pages list
			void goto(`/projects/${editor.project_id}/pages`);
		}
	};
</script>

{#if preview_mode}
	<div class="preview_fullscreen" class:offset_for_sidebar={zzz.ui.toggle_main_menu}>
		<div class="markdown_preview p_lg">
			<!-- eslint-disable-next-line svelte/no-at-html-tags -->
			{@html editor?.formatted_content}
		</div>

		<!-- Close preview button in top-right corner -->
		<button
			type="button"
			class="fixed t_0 r_0 icon_button plain radius_xs2"
			style:border-top-right-radius="0"
			style:border-bottom-left-radius="var(--radius_lg)"
			aria-label="Close preview"
			title="Close preview"
			onclick={toggle_preview}
		>
			<Glyph text={GLYPH_PREVIEW} />
		</button>
	</div>
{:else}
	<div class="editor_layout">
		<Project_Sidebar />
		<Section_Sidebar section="pages" />
		<Pages_Sidebar />

		<div class="editor_content">
			{#if editor?.project}
				<div class="h_100 column p_lg">
					<div>
						<div class="flex gap_sm align_items_center">
							<h1 class="mb_lg">
								{editor.is_new_page ? 'New page' : editor.current_page?.title || 'Page'}
							</h1>
						</div>

						<div class="flex w_100 justify_content_space_between gap_sm mb_lg">
							<div class="flex gap_sm">
								<button
									type="button"
									onclick={() => editor.save_page()}
									class="color_a"
									disabled={!editor.has_changes}
								>
									save
								</button>

								<button type="button" onclick={toggle_preview} class="plain" title="Preview page">
									{GLYPH_PREVIEW} preview
								</button>
							</div>

							{#if !editor.is_new_page}
								<button type="button" onclick={delete_page} class="color_c"
									>{GLYPH_DELETE} delete</button
								>
							{/if}
						</div>
					</div>

					<div class="panel p_md mb_md">
						<div class="flex gap_sm">
							<div class="flex_1">
								<label>
									Page title
									<input
										type="text"
										bind:value={editor.title}
										class="w_100"
										placeholder="Page title"
									/>
								</label>
							</div>
							<div class="flex_1">
								<label>
									Page path
									<input
										type="text"
										bind:value={editor.path}
										class="w_100"
										placeholder="/page-path"
									/>
								</label>
							</div>
						</div>
					</div>

					<div class="editor_area">
						<div class="panel p_md content_area">
							<textarea
								bind:value={editor.content}
								class="w_100 h_100 markdown_editor"
								placeholder="{GLYPH_PLACEHOLDER} markup"
							></textarea>
						</div>

						<div class="panel p_md preview_area">
							<!-- TODO hacky, replace with safe markdown -->
							<!-- eslint-disable-next-line svelte/no-at-html-tags -->
							<div class="markdown_preview">{@html editor.formatted_content}</div>
						</div>
					</div>
				</div>
			{:else}
				<div class="p_lg text_align_center">
					<p>Project not found.</p>
				</div>
			{/if}
		</div>
	</div>
{/if}

<style>
	.editor_layout {
		display: flex;
		height: 100%;
		overflow: hidden;
	}

	.editor_content {
		height: 100%;
		flex: 1;
		overflow: auto;
	}

	.editor_area {
		display: flex;
		gap: var(--size_md);
		flex: 1;
	}

	.content_area,
	.preview_area {
		width: 50%;
		overflow: auto;
	}

	.markdown_editor {
		width: 100%;
		height: 100%;
		resize: none;
		border: none;
		background: transparent;
		font-family: var(--font_mono);
		font-size: 1em;
		line-height: 1.5;
		padding: var(--size_xs);
		outline: none;
	}

	.markdown_preview {
		padding: var(--size_xs);
	}

	.preview_fullscreen {
		position: fixed;
		top: 0;
		left: 0;
		width: 100%;
		height: 100%;
		background: var(--bg);
		z-index: 1000;
		overflow: auto;
	}
	.preview_fullscreen.offset_for_sidebar {
		padding-left: var(--sidebar_width);
	}
</style>
