<script lang="ts">
	import {goto} from '$app/navigation';
	import {base} from '$app/paths';

	import {projects_context} from '$routes/projects/projects.svelte.js';
	import Project_Sidebar from '$routes/projects/Project_Sidebar.svelte';
	import Section_Sidebar from '$routes/projects/Section_Sidebar.svelte';
	import Pages_Sidebar from '$routes/projects/Pages_Sidebar.svelte';
	import Project_Not_Found from '$routes/projects/Project_Not_Found.svelte';
	import {GLYPH_DELETE, GLYPH_PREVIEW, GLYPH_PLACEHOLDER} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import {zzz_context} from '$lib/zzz.svelte.js';

	const projects = projects_context.get();
	const zzz = zzz_context.get();

	const page_viewmodel = $derived(projects.current_page_viewmodel);

	// Preview mode state
	let preview_mode = $state(false);

	// Toggle preview mode
	const toggle_preview = () => {
		preview_mode = !preview_mode;
	};

	// TODO refactor with proper state/API
	/** Delete the current page and navigate back to pages list. */
	const delete_page = () => {
		const controller = projects.current_project_viewmodel;
		if (!page_viewmodel?.project || !page_viewmodel.current_page || !controller) {
			return;
		}

		// eslint-disable-next-line no-alert
		if (confirm('Are you sure you want to delete this page? This action cannot be undone.')) {
			controller.delete_project_page(page_viewmodel.page_id);

			// Navigate back to pages list
			void goto(`${base}/projects/${page_viewmodel.project_id}/pages`);
		}
	};

	const project = $derived(projects.current_project);
</script>

{#if preview_mode}
	<div class="preview_fullscreen" class:offset_for_sidebar={zzz.ui.toggle_main_menu}>
		<div class="markdown_preview p_lg">
			<!-- eslint-disable-next-line svelte/no-at-html-tags -->
			{@html page_viewmodel?.formatted_content}
		</div>

		<!-- Close preview button in top-right corner -->
		<button
			type="button"
			class="position_fixed t_0 r_0 icon_button plain border_radius_xs2"
			style:border-top-right-radius="0"
			style:border-bottom-left-radius="var(--border_radius_lg)"
			aria-label="Close preview"
			title="Close preview"
			onclick={toggle_preview}
		>
			<Glyph glyph={GLYPH_PREVIEW} />
		</button>
	</div>
{:else}
	<div class="editor_layout">
		<!-- TODO @many refactor for better component instance stability for e.g. transitions -->
		<Project_Sidebar />
		{#if project}
			<Section_Sidebar {project} section="pages" />
			<Pages_Sidebar />
		{/if}

		<div class="editor_content">
			{#if page_viewmodel && project}
				<div class="h_100 column p_lg">
					<div>
						<div class="display_flex gap_sm align_items_center">
							<h1 class="mb_lg">
								{page_viewmodel.current_page?.title || 'Page'}
							</h1>
						</div>

						<div class="display_flex w_100 justify_content_space_between gap_sm mb_lg">
							<div class="display_flex gap_sm">
								<button
									type="button"
									onclick={() => page_viewmodel.save_page()}
									class="color_a"
									disabled={!page_viewmodel.has_changes}
								>
									save
								</button>

								<button type="button" onclick={toggle_preview} class="plain" title="Preview page">
									<Glyph glyph={GLYPH_PREVIEW} attrs={{class: 'mr_xs2'}} /> preview
								</button>
							</div>

							<button type="button" onclick={delete_page} class="color_c"
								><Glyph glyph={GLYPH_DELETE} attrs={{class: 'mr_xs2'}} /> delete</button
							>
						</div>
					</div>

					<div class="panel p_md mb_md">
						<div class="display_flex gap_sm">
							<div class="flex_1">
								<label>
									Page title
									<input
										type="text"
										bind:value={page_viewmodel.title}
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
										bind:value={page_viewmodel.path}
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
								bind:value={page_viewmodel.content}
								class="w_100 h_100 markdown_editor"
								placeholder="{GLYPH_PLACEHOLDER} markup"
							></textarea>
						</div>

						<div class="panel p_md preview_area">
							<!-- TODO hacky, replace with safe markdown -->
							<!-- eslint-disable-next-line svelte/no-at-html-tags -->
							<div class="markdown_preview">{@html page_viewmodel.formatted_content}</div>
						</div>
					</div>
				</div>
			{:else}
				<Project_Not_Found />
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
		gap: var(--font_size_md);
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
		font-family: var(--font_family_mono);
		font-size: 1em;
		line-height: 1.5;
		padding: var(--font_size_xs);
		outline: none;
	}

	.markdown_preview {
		padding: var(--font_size_xs);
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
