<script lang="ts">
	import {projects_context} from '../../projects.svelte.js';
	import Project_Sidebar from '../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../Section_Sidebar.svelte';
	import {GLYPH_DELETE} from '$lib/glyphs.js';

	const projects = projects_context.get();

	// Use the reactive current_project_controller instead of get_project_controller
	const controller = $derived(projects.current_project_controller);
</script>

<div class="project_layout">
	<Project_Sidebar />
	<Section_Sidebar section="settings" />

	<div class="project_content">
		{#if controller?.project}
			<div class="p_lg">
				<h1 class="mb_lg">Project settings</h1>

				<div class="panel p_md width_lg mt_md">
					<div class="mb_md">
						<label>
							Project name
							<input
								type="text"
								bind:value={controller.edited_name}
								class="w_100"
								placeholder={controller.project.name}
							/>
						</label>
					</div>

					<div class="mb_md">
						<label>
							Description
							<textarea
								bind:value={controller.edited_description}
								class="w_100"
								rows="3"
								placeholder={controller.project.description || 'No description'}
							></textarea>
						</label>
					</div>

					<button
						type="button"
						onclick={() => controller.save_project_details()}
						class="color_a"
						disabled={!controller.has_changes}
					>
						save changes
					</button>
				</div>

				<div class="panel p_md width_lg mt_xl color_c_bg_1">
					<h2 class="mt_0 mb_md">Danger Zone</h2>
					<p class="mb_md">These actions cannot be undone.</p>

					<button type="button" class="color_c" onclick={() => controller.delete_current_project()}>
						{GLYPH_DELETE} delete project
					</button>
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
	.project_layout {
		display: flex;
		height: 100%;
		overflow: hidden;
	}

	.project_content {
		flex: 1;
		overflow: auto;
	}
</style>
