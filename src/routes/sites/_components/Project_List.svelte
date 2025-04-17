<script lang="ts">
	import {projects_context, type Project} from '../projects.svelte.js';

	const projects = projects_context.get();

	let new_project_name = $state('');
	let is_creating = $state(false);

	const create_project = () => {
		if (new_project_name.trim()) {
			const new_project: Project = {
				id: 'proj_' + Date.now(),
				name: new_project_name,
				description: '',
				created_at: new Date().toISOString(),
				updated_at: new Date().toISOString(),
				domains: [],
				pages: [],
			};

			projects.add_project(new_project);
			new_project_name = '';
			is_creating = false;
		}
	};
</script>

<section class="project_list">
	<h2>Projects</h2>

	<div class="flex justify_content_between mb_lg">
		<div>
			<span class="text_color_5">{projects.projects.length} projects</span>
		</div>
		<div>
			{#if !is_creating}
				<button type="button" class="color_b" onclick={() => (is_creating = true)}
					>+ New Project</button
				>
			{/if}
		</div>
	</div>

	{#if is_creating}
		<div class="panel p_md mb_lg width_sm">
			<h3 class="mt_0">Create new project</h3>
			<div class="mb_md">
				<label for="project_name"
					>name
					<input type="text" id="project_name" bind:value={new_project_name} /></label
				>
			</div>
			<div class="flex gap_sm">
				<button type="button" onclick={create_project} class="color_b">create project</button>
				<button type="button" onclick={() => (is_creating = false)} class="plain">cancel</button>
			</div>
		</div>
	{/if}

	{#if projects.projects.length === 0}
		<div class="panel p_lg text_align_center">
			<p>You don't have any projects yet.</p>
		</div>
	{:else}
		<div class="projects_grid">
			{#each projects.projects as project (project.id)}
				<a href="/sites/{project.id}" class="project_card panel p_md font_weight_400">
					<h3 class="mt_0">{project.name}</h3>
					<p class="mb_md">{project.description || 'No description'}</p>
					<span>{project.domains.length} {project.domains.length === 1 ? 'domain' : 'domains'}</span
					>
					<span>{project.pages.length} {project.pages.length === 1 ? 'page' : 'pages'}</span>
				</a>
			{/each}
		</div>
	{/if}
</section>

<style>
	.projects_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--size_md);
	}

	.project_card {
		display: block;
		text-decoration: none;
		color: inherit;
		border: 1px solid var(--border_color_1);
	}

	.project_card:hover {
		border-color: var(--border_color_2);
	}
</style>
