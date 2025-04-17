<script lang="ts">
	import {page} from '$app/stores';
	import {goto} from '$app/navigation';

	import {Page_Editor} from '../page_editor.svelte.js';
	import Project_Sidebar from '../../../_components/Project_Sidebar.svelte';
	import {projects_store} from '../../../sites.svelte.js';

	const project_id = $page.params.project_id;
	const page_id = $page.params.page_id;

	// Create the editor instance
	const editor = new Page_Editor(project_id, page_id);

	// Get all projects for the sidebar
	const projects = $derived(projects_store.projects);
</script>

<div class="editor_layout">
	<Project_Sidebar {projects} />

	{#if editor.project}
		<div class="editor_container">
			<!-- Editor Header -->
			<header class="editor_header">
				<div class="flex justify_content_between align_items_center p_md">
					<h1>{editor.is_new_page ? 'Create New Page' : 'Edit Page'}</h1>
					<div class="flex gap_sm">
						<button type="button" class="plain" onclick={editor.toggle_view_mode}>
							{editor.view_mode === 'split' ? 'Full Preview' : 'Split View'}
						</button>
						<button type="button" class="color_b" onclick={editor.save_page}>Save Page</button>
						<button type="button" class="plain" onclick={() => goto(`/sites/${project_id}`)}
							>Cancel</button
						>
					</div>
				</div>

				<!-- Page Metadata -->
				{#if editor.view_mode === 'split'}
					<div class="p_md border_solid border_width_0 border_top_1">
						<div class="flex gap_md flex_wrap">
							<div class="flex_1">
								<label for="page_title">Title</label>
								<input
									type="text"
									id="page_title"
									bind:value={editor.title}
									class="w_100"
									placeholder="Page Title"
								/>
							</div>
							<div class="flex_1">
								<label for="page_path">Path</label>
								<input
									type="text"
									id="page_path"
									bind:value={editor.path}
									class="w_100"
									placeholder="/about"
								/>
							</div>
						</div>
					</div>
				{/if}
			</header>

			<!-- Editor Main Area -->
			{#if editor.view_mode === 'split'}
				<div class="editor_main">
					<!-- Left side: Markdown Editor -->
					<div class="editor_markdown">
						<textarea
							bind:value={editor.content}
							class="markdown_input"
							placeholder="# Your markdown content here"
						></textarea>
					</div>

					<!-- Right side: Preview -->
					<div class="editor_preview">
						<div class="preview_container">
							<!-- TODO safe markdown -->
							<!-- eslint-disable-next-line svelte/no-at-html-tags -->
							{@html editor.formatted_content}
						</div>
					</div>
				</div>
			{:else}
				<!-- Fullscreen Preview Mode -->
				<div class="fullscreen_preview">
					<div class="preview_header p_sm border_solid border_width_0 border_bottom_1">
						<div class="flex justify_content_between">
							<span class="text_color_5">{editor.path}</span>
							<span class="chip bg_1 p_xs radius_xs">{editor.title}</span>
						</div>
					</div>
					<div class="preview_content p_lg">
						<h1>{editor.title}</h1>
						<!-- TODO safe markdown -->
						<!-- eslint-disable-next-line svelte/no-at-html-tags -->
						{@html editor.formatted_content}
					</div>
				</div>
			{/if}
		</div>
	{:else}
		<div class="p_lg text_align_center">
			<p>Project not found.</p>
			<a href="/sites">Back to Sites</a>
		</div>
	{/if}
</div>

<style>
	.editor_layout {
		display: flex;
		height: 100vh;
		overflow: hidden;
	}

	.editor_container {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: hidden;
	}

	.editor_header {
		flex-shrink: 0;
		border-bottom: 1px solid var(--border_color_1);
		background: var(--bg_1);
	}

	.editor_main {
		display: flex;
		flex: 1;
		overflow: hidden;
	}

	.editor_markdown,
	.editor_preview {
		flex: 1;
		overflow: auto;
		height: 100%;
	}

	.editor_markdown {
		border-right: 1px solid var(--border_color_1);
	}

	.markdown_input {
		width: 100%;
		height: 100%;
		padding: var(--size_md);
		border: none;
		background: transparent;
		resize: none;
		font-family: var(--font_mono);
		font-size: 14px;
		line-height: 1.5;
	}

	.preview_container {
		padding: var(--size_md);
	}

	.fullscreen_preview {
		flex: 1;
		display: flex;
		flex-direction: column;
		overflow: auto;
	}

	.preview_content {
		flex: 1;
		overflow: auto;
	}

	.chip {
		display: inline-block;
		font-size: 0.85em;
	}
</style>
