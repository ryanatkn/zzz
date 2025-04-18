<script lang="ts">
	import {base} from '$app/paths';

	import {projects_context} from '../projects.svelte.js';
	import Project_Sidebar from '../Project_Sidebar.svelte';
	import Section_Sidebar from '../Section_Sidebar.svelte';

	const projects = projects_context.get();

	const project_viewmodel = $derived(projects.current_project_viewmodel);
</script>

<div class="project_layout">
	<Project_Sidebar />
	<Section_Sidebar section="project" />

	<div class="project_content">
		{#if project_viewmodel?.project}
			<div class="p_lg">
				<h1 class="mb_0">{project_viewmodel.project.name}</h1>
				<div>
					{#if project_viewmodel.editing_project}
						<div class="flex gap_sm mb_sm">
							<button
								type="button"
								class="color_a"
								onclick={() => project_viewmodel.save_project_details()}
								disabled={!project_viewmodel.has_changes}>save</button
							>
							<button
								type="button"
								class="plain"
								onclick={() => {
									project_viewmodel.editing_project = false;
									project_viewmodel.reset_form();
								}}>cancel</button
							>
						</div>
					{:else}
						<button
							type="button"
							class="plain"
							onclick={() => (project_viewmodel.editing_project = true)}>edit</button
						>
					{/if}
				</div>

				{#if project_viewmodel.editing_project}
					<div class="panel p_md width_md mb_lg">
						<div class="mb_md">
							<label>
								Project name
								<input type="text" bind:value={project_viewmodel.edited_name} class="w_100" />
							</label>
						</div>
						<div>
							<label>
								Description
								<textarea bind:value={project_viewmodel.edited_description} class="w_100" rows="3"
								></textarea>
							</label>
						</div>
					</div>
				{:else if project_viewmodel.project.description}
					<p class="mb_lg width_md">{project_viewmodel.project.description}</p>
				{/if}

				<div class="flex gap_md mb_lg">
					<span class="chip"
						>{project_viewmodel.project.pages.length}
						{project_viewmodel.project.pages.length === 1 ? 'page' : 'pages'}</span
					>
					<span class="chip"
						>{project_viewmodel.project.domains.length}
						{project_viewmodel.project.domains.length === 1 ? 'domain' : 'domains'}</span
					>
					<span class="chip"
						>created {new Date(project_viewmodel.project.created).toLocaleDateString()}</span
					>
					<span class="chip"
						>updated {new Date(project_viewmodel.project.updated).toLocaleDateString()}</span
					>
				</div>

				<div class="projects_grid">
					<div class="panel p_md">
						<h2 class="mt_0 mb_lg">
							<a href="{base}/projects/{project_viewmodel.project_id}/pages">Pages</a>
						</h2>
						{#if project_viewmodel.project.pages.length === 0}
							<p class="text_color_5">No pages created yet.</p>
						{:else}
							<ul class="pages_list">
								{#each project_viewmodel.project.pages as page (page.id)}
									<li>
										<a href="{base}/projects/{project_viewmodel.project_id}/pages/{page.id}"
											>{page.title}</a
										>
										<span class="text_color_5">{page.path}</span>
									</li>
								{/each}
							</ul>
						{/if}
						<div class="mt_md">
							<button
								type="button"
								onclick={() => project_viewmodel.create_new_page()}
								class="color_a">+ add page</button
							>
						</div>
					</div>

					<div class="panel p_md">
						<h2 class="mt_0 mb_lg">
							<a href="{base}/projects/{project_viewmodel.project_id}/domains">Domains</a>
						</h2>
						{#if project_viewmodel.project.domains.length === 0}
							<p class="text_color_5">No domains configured yet.</p>
						{:else}
							<ul class="domains_list">
								{#each project_viewmodel.project.domains as domain (domain.id)}
									<li>
										<a href="{base}/projects/{project_viewmodel.project_id}/domains/{domain.id}">
											<span class="domain_name">{domain.name}</span>
										</a>
										<div class="domain_details">
											<span
												class="status_badge {domain.status === 'active'
													? 'status_active'
													: domain.status === 'pending'
														? 'status_pending'
														: 'status_inactive'}"
											>
												{domain.status}
											</span>
											{#if domain.ssl}
												<span class="ssl_badge">SSL</span>
											{/if}
										</div>
									</li>
								{/each}
							</ul>
						{/if}
						<div class="mt_md">
							<button
								type="button"
								onclick={() => project_viewmodel.create_new_domain()}
								class="color_a">+ add domain</button
							>
						</div>
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
	.project_layout {
		display: flex;
		height: 100%;
		overflow: hidden;
	}

	.project_content {
		flex: 1;
		overflow: auto;
	}

	.projects_grid {
		display: grid;
		grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
		gap: var(--size_md);
	}

	.pages_list,
	.domains_list {
		list-style: none;
		padding: 0;
		margin: var(--size_md) 0;
	}

	.pages_list li,
	.domains_list li {
		padding: var(--size_xs) 0;
		border-bottom: 1px solid var(--border_color_1);
		display: flex;
		flex-direction: column;
	}

	.domain_name {
		font-family: var(--font_mono);
		font-weight: 500;
	}

	.domain_details {
		display: flex;
		gap: var(--size_xs);
		margin-top: 4px;
	}

	.status_badge {
		display: inline-block;
		padding: 2px 6px;
		border-radius: 10px;
		font-size: 0.75em;
	}

	.ssl_badge {
		display: inline-block;
		padding: 2px 6px;
		border-radius: 10px;
		font-size: 0.75em;
		background-color: var(--bg_2);
	}

	.status_active {
		background-color: var(--color_b_2);
		color: var(--color_b_9);
	}

	.status_pending {
		background-color: var(--color_e_2);
		color: var(--color_e_9);
	}

	.status_inactive {
		background-color: var(--bg_2);
		color: var(--text_color_5);
	}
</style>
