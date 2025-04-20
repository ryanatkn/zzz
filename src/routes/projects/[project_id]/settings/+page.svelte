<script lang="ts">
	import {projects_context} from '../../projects.svelte.js';
	import Project_Sidebar from '../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../Section_Sidebar.svelte';
	import {GLYPH_DELETE} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const projects = projects_context.get();

	const project_viewmodel = $derived(projects.current_project_viewmodel);
</script>

<div class="project_layout">
	<Project_Sidebar />
	<Section_Sidebar section="settings" />

	<div class="project_content">
		{#if project_viewmodel?.project}
			<div class="p_lg">
				<h1 class="mb_lg">Project settings</h1>

				<div class="panel p_md width_md my_lg">
					<div class="mb_md">
						<label>
							<div class="title">Project name</div>
							<input
								type="text"
								bind:value={project_viewmodel.edited_name}
								class="w_100"
								placeholder={project_viewmodel.project.name}
							/>
						</label>
					</div>

					<div class="mb_md">
						<label>
							<div class="title">Description</div>
							<textarea
								bind:value={project_viewmodel.edited_description}
								class="w_100"
								rows="3"
								placeholder={project_viewmodel.project.description || 'No description'}
							></textarea>
						</label>
					</div>

					<button
						type="button"
						onclick={() => project_viewmodel.save_project_details()}
						class="color_a"
						disabled={!project_viewmodel.has_changes}
					>
						save changes
					</button>
				</div>

				<div class="panel p_md width_md">
					<h2 class="mt_0 mb_md">Danger zone</h2>
					<p class="mb_md">These actions cannot be undone.</p>

					<button
						type="button"
						class="color_c"
						onclick={() => project_viewmodel.delete_current_project()}
					>
						<Glyph glyph={GLYPH_DELETE} attrs={{class: 'mr_xs2'}} /> delete project
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
