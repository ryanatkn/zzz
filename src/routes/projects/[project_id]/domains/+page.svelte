<script lang="ts">
	import {base} from '$app/paths';

	import {projects_context} from '../../projects.svelte.js';
	import Project_Sidebar from '../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../Section_Sidebar.svelte';
	import Domains_Sidebar from '../../Domains_Sidebar.svelte';
	import {GLYPH_ADD, GLYPH_CHECKMARK} from '$lib/glyphs.js';
	import Glyph from '$lib/Glyph.svelte';

	const projects = projects_context.get();

	const project_viewmodel = $derived(projects.current_project_viewmodel);
</script>

<div class="project_layout">
	<Project_Sidebar />
	<Section_Sidebar section="domains" />
	<Domains_Sidebar />

	<div class="project_content">
		{#if project_viewmodel?.project}
			<div class="p_lg">
				<h1 class="mb_lg">Domains</h1>

				{#if project_viewmodel.project.domains.length === 0}
					<div class="panel p_lg text_align_center mb_lg">
						<p>This project doesn't have any domains configured yet.</p>
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
