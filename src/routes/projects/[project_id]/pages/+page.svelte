<script lang="ts">
	import {projects_context} from '../../projects.svelte.js';
	import Project_Sidebar from '../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../Section_Sidebar.svelte';
	import Pages_Sidebar from '../../Pages_Sidebar.svelte';

	const projects = projects_context.get();

	// Use the reactive current_project_controller instead of get_project_controller
	const controller = $derived(projects.current_project_controller);
</script>

<div class="project_layout">
	<Project_Sidebar />
	<Section_Sidebar section="pages" />
	<Pages_Sidebar />

	<div class="project_content">
		{#if controller?.project}
			<div class="p_lg">
				<h1 class="mb_lg">Pages</h1>

				{#if controller.project.pages.length === 0}
					<div class="panel p_lg text_align_center mb_lg">
						<p>This project doesn't have any pages yet.</p>
						<p>
							<button type="button" class="color_a" onclick={() => controller.create_new_page()}>
								Create your first page
							</button>
						</p>
					</div>
				{:else}
					<table class="w_100">
						<thead>
							<tr>
								<th>title</th>
								<th>path</th>
								<th>created</th>
								<th>updated</th>
							</tr>
						</thead>
						<tbody>
							{#each controller.project.pages as page (page.id)}
								<tr>
									<td>
										<a href="/projects/{controller.project_id}/pages/{page.id}">{page.title}</a>
									</td>
									<td>{page.path}</td>
									<td>{new Date(page.created).toLocaleString()}</td>
									<td>{new Date(page.updated).toLocaleString()}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}

				<div class="mb_lg">
					<button type="button" class="color_a" onclick={() => controller.create_new_page()}>
						+ new page
					</button>
				</div>
			</div>
		{:else}
			<div class="p_lg text_align_center">
				<p>Project not found.</p>
				<a href="/projects">back to sites</a>
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
