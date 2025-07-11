<script lang="ts">
	// @slop Claude Opus 4

	import {base} from '$app/paths';

	import {projects_context} from '$routes/projects/projects.svelte.js';
	import Project_Sidebar from '$routes/projects/Project_Sidebar.svelte';
	import Section_Sidebar from '$routes/projects/Section_Sidebar.svelte';
	import Domains_Sidebar from '$routes/projects/Domains_Sidebar.svelte';
	import {GLYPH_ADD, GLYPH_CHECKMARK} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';
	import Project_Not_Found from '$routes/projects/Project_Not_Found.svelte';

	const projects = projects_context.get();

	const project_viewmodel = $derived(projects.current_project_viewmodel);
</script>

<div class="project_layout">
	<!-- TODO @many refactor for better component instance stability for e.g. transitions -->
	<Project_Sidebar />
	{#if projects.current_project}
		<Section_Sidebar project={projects.current_project} section="domains" />
		<Domains_Sidebar />
	{/if}

	<div class="project_content">
		{#if project_viewmodel?.project}
			<div class="p_lg">
				<h1 class="mb_lg">domains</h1>

				{#if project_viewmodel.project.domains.length === 0}
					<div class="panel p_lg mb_lg">
						<p>no domains yet</p>
						<p>
							<button
								type="button"
								class="color_a"
								onclick={() => project_viewmodel.create_new_domain()}
							>
								<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> add your first domain
							</button>
						</p>
					</div>
				{:else}
					<table class="w_100">
						<thead>
							<tr>
								<th>domain name</th>
								<th>status</th>
								<th>SSL</th>
								<th>created</th>
								<th>updated</th>
							</tr>
						</thead>
						<tbody>
							{#each project_viewmodel.project.domains as domain (domain.id)}
								<tr>
									<td>
										<a href="{base}/projects/{project_viewmodel.project_id}/domains/{domain.id}">
											{domain.name || '[new domain]'}
										</a>
									</td>
									<td>
										<span
											class="status_badge {domain.status === 'active'
												? 'status_active'
												: domain.status === 'pending'
													? 'status_pending'
													: 'status_inactive'}"
										>
											{domain.status}
										</span>
									</td>
									<td>{domain.ssl ? GLYPH_CHECKMARK : ''}</td>
									<td>{new Date(domain.created).toLocaleString()}</td>
									<td>{new Date(domain.updated).toLocaleString()}</td>
								</tr>
							{/each}
						</tbody>
					</table>
				{/if}

				<div>
					<button
						type="button"
						class="color_a"
						onclick={() => project_viewmodel.create_new_domain()}
					>
						<Glyph glyph={GLYPH_ADD} attrs={{class: 'mr_xs2'}} /> new domain
					</button>
				</div>
			</div>
		{:else}
			<Project_Not_Found />
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

	.status_badge {
		display: inline-block;
		padding: 2px 6px;
		border-radius: 10px;
		font-size: 0.75em;
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
