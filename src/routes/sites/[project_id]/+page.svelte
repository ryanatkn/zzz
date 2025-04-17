<script lang="ts">
	import {page} from '$app/state';
	import {goto} from '$app/navigation';
	import {Project_Controller} from './project_controller.svelte.js';
	import Project_Sidebar from '../_components/Project_Sidebar.svelte';

	const project_id = page.params.project_id;
	const controller = new Project_Controller(project_id);
</script>

<div class="project_layout">
	<Project_Sidebar />

	<div class="project_content">
		{#if controller.project}
			<div class="p_lg">
				<div class="flex justify_content_between align_items_center">
					<div>
						{#if !controller.editing_project}
							<h1>{controller.project.name}</h1>
							<p class="text_color_5">{controller.project.description || 'No description'}</p>
						{:else}
							<div class="panel p_md mb_md">
								<div class="mb_sm">
									<label for="project_name">Project Name</label>
									<input
										type="text"
										id="project_name"
										bind:value={controller.edited_name}
										class="w_100"
									/>
								</div>
								<div class="mb_md">
									<label for="project_description">Description</label>
									<textarea
										id="project_description"
										bind:value={controller.edited_description}
										class="w_100"
										rows="3"
									></textarea>
								</div>
								<div class="flex gap_sm">
									<button type="button" onclick={controller.save_project_details} class="color_b"
										>Save</button
									>
									<button
										type="button"
										onclick={() => (controller.editing_project = false)}
										class="plain">Cancel</button
									>
								</div>
							</div>
						{/if}
					</div>

					<div>
						{#if !controller.editing_project}
							<button
								type="button"
								class="plain"
								onclick={() => (controller.editing_project = true)}>Edit</button
							>
						{/if}
					</div>
				</div>

				<!-- Project Navigation -->
				<div class="flex border_solid border_width_0 border_bottom_1 mb_lg">
					<button
						type="button"
						class="tab_button plain p_sm"
						class:active={controller.active_tab === 'pages'}
						onclick={() => (controller.active_tab = 'pages')}
					>
						Pages
					</button>
					<button
						type="button"
						class="tab_button plain p_sm"
						class:active={controller.active_tab === 'domains'}
						onclick={() => (controller.active_tab = 'domains')}
					>
						Domains
					</button>
					<button
						type="button"
						class="tab_button plain p_sm"
						class:active={controller.active_tab === 'settings'}
						onclick={() => (controller.active_tab = 'settings')}
					>
						Settings
					</button>
				</div>

				<!-- Tab Content -->
				{#if controller.active_tab === 'pages'}
					<div>
						<div class="flex justify_content_between mb_md">
							<h2>Pages</h2>
							<button
								type="button"
								class="color_b"
								onclick={() => goto(`/sites/${project_id}/editor/new`)}>+ New Page</button
							>
						</div>

						{#if controller.project.pages.length === 0}
							<div class="panel p_md text_align_center">
								<p>This project doesn't have any pages yet.</p>
							</div>
						{:else}
							<div class="panel">
								<table class="w_100">
									<thead>
										<tr>
											<th class="text_align_start p_xs">Title</th>
											<th class="text_align_start p_xs">Path</th>
											<th class="text_align_start p_xs">Updated</th>
											<th class="text_align_start p_xs">Actions</th>
										</tr>
									</thead>
									<tbody>
										{#each controller.project.pages as page (page.id)}
											<tr>
												<td class="p_xs">{page.title}</td>
												<td class="p_xs"><code>{page.path}</code></td>
												<td class="p_xs">{new Date(page.updated_at).toLocaleDateString()}</td>
												<td class="p_xs">
													<div class="flex gap_xs">
														<a href={`/sites/${project_id}/editor/${page.id}`} class="plain">Edit</a
														>
														<button
															type="button"
															class="plain color_c"
															onclick={() => controller.delete_project_page(page.id)}
														>
															Delete
														</button>
													</div>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						{/if}
					</div>
				{:else if controller.active_tab === 'domains'}
					<div>
						<div class="flex justify_content_between mb_md">
							<h2>Domains</h2>
							<button
								type="button"
								class="color_b"
								onclick={() => goto(`/sites/${project_id}/domains`)}>+ Add Domain</button
							>
						</div>

						{#if controller.project.domains.length === 0}
							<div class="panel p_md text_align_center">
								<p>This project doesn't have any domains yet.</p>
							</div>
						{:else}
							<div class="panel">
								<table class="w_100">
									<thead>
										<tr>
											<th class="text_align_start p_xs">Domain</th>
											<th class="text_align_start p_xs">Status</th>
											<th class="text_align_start p_xs">SSL</th>
											<th class="text_align_start p_xs">Actions</th>
										</tr>
									</thead>
									<tbody>
										{#each controller.project.domains as domain (domain.id)}
											<tr>
												<td class="p_xs">{domain.name}</td>
												<td class="p_xs">
													<span
														class="chip {domain.status === 'active'
															? 'color_a'
															: domain.status === 'pending'
																? 'color_e'
																: 'color_5'}"
													>
														{domain.status}
													</span>
												</td>
												<td class="p_xs">{domain.ssl ? '✓' : '✗'}</td>
												<td class="p_xs">
													<div class="flex gap_xs">
														<a href={`/sites/${project_id}/domains/${domain.id}`} class="plain"
															>Settings</a
														>
														<button type="button" class="plain color_c">Remove</button>
													</div>
												</td>
											</tr>
										{/each}
									</tbody>
								</table>
							</div>
						{/if}
					</div>
				{:else if controller.active_tab === 'settings'}
					<div>
						<h2>Settings</h2>
						<div class="panel p_md">
							<div class="mb_md">
								<h3 class="mb_xs">Danger Zone</h3>
								<p class="mb_sm">These actions cannot be undone.</p>
								<button type="button" class="color_c" onclick={controller.delete_current_project}>
									Delete Project
								</button>
							</div>
						</div>
					</div>
				{/if}
			</div>
		{:else}
			<div class="p_lg text_align_center">
				<p>Loading project...</p>
			</div>
		{/if}
	</div>
</div>

<style>
	.project_layout {
		display: flex;
		height: 100vh;
		overflow: hidden;
	}

	.project_content {
		flex: 1;
		overflow: auto;
	}

	.tab_button {
		border-bottom: 2px solid transparent;
	}

	.tab_button.active {
		border-bottom: 2px solid var(--color_b_5);
		font-weight: bold;
	}

	.chip {
		display: inline-block;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 0.85em;
	}
</style>
