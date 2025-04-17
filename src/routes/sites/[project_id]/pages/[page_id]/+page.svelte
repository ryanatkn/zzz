<script lang="ts">
	import {projects_context} from '../../../projects.svelte.js';
	import Project_Sidebar from '../../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../../Section_Sidebar.svelte';
	import Pages_Sidebar from '../../../Pages_Sidebar.svelte';

	const projects = projects_context.get();

	// Use the reactive current_page_editor instead of get_page_editor
	const editor = $derived(projects.current_page_editor);

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
			window.location.href = `/sites/${editor.project_id}/pages`;
		}
	};
</script>

<div class="editor_layout">
	<Project_Sidebar />
	<Section_Sidebar section="pages" />
	<Pages_Sidebar />

	<div class="editor_content">
		{#if editor?.project}
			<div class="p_lg">
				<div>
					<div class="flex gap_sm align_items_center">
						<h1 class="m_0">
							{editor.is_new_page ? 'New Page' : `Edit: ${editor.current_page?.title || ''}`}
						</h1>
					</div>

					<div class="flex gap_sm">
						<button
							type="button"
							onclick={() => editor.save_page()}
							class="color_b"
							disabled={!editor.has_changes}
						>
							Save
						</button>
						<a href="/sites/{editor.project_id}/pages" class="plain">Cancel</a>

						{#if !editor.is_new_page}
							<button type="button" onclick={delete_page} class="color_c">Delete</button>
						{/if}
					</div>
				</div>

				<div class="panel p_md mb_md">
					<div class="flex gap_sm">
						<div class="flex_1">
							<label>
								Page Title
								<input
									type="text"
									bind:value={editor.title}
									class="w_100"
									placeholder="Page Title"
								/>
							</label>
						</div>
						<div class="flex_1">
							<label>
								Page Path
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
							placeholder="# Page Title&#10;&#10;Write your content here in Markdown format."
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

<style>
	.editor_layout {
		display: flex;
		height: 100vh;
		overflow: hidden;
	}

	.editor_content {
		flex: 1;
		overflow: auto;
	}

	.editor_area {
		display: flex;
		gap: var(--size_md);
		height: calc(100vh - 200px);
	}

	.content_area,
	.preview_area {
		width: 50%;
		overflow: auto;
	}

	.content_area {
		width: 100%;
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
</style>
