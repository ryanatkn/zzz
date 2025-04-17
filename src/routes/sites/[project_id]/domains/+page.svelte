<script lang="ts">
	import {page} from '$app/stores';
	import {goto} from '$app/navigation';
	import {add_domain, projects_store, type Domain} from '../../sites.svelte.js';
	import {Domains_Controller} from './domains.svelte.js';
	import Project_Sidebar from '../../_components/Project_Sidebar.svelte';

	const project_id = $page.params.project_id;

	// Create controller instance
	const controller = new Domains_Controller(project_id);

	// Get all projects for the sidebar
	const projects = $derived(projects_store.projects);

	/**
	 * Computed full domain name based on input and domain type.
	 */
	const full_domain = $derived(
		controller.custom_domain ? controller.domain_name : `${controller.domain_name}.zzz.software`,
	);

	/**
	 * Adds a new domain to the project.
	 */
	const add_new_domain = () => {
		if (!controller.project || !controller.domain_name.trim()) return;

		// Basic validation
		if (!controller.domain_name.includes('.') && controller.custom_domain) {
			// eslint-disable-next-line no-alert
			alert('Please enter a valid domain name.');
			return;
		}

		const new_domain: Domain = {
			id: 'dom_' + Date.now(),
			name: full_domain,
			status: 'pending', // New domains always start as pending
			ssl: !controller.custom_domain, // Auto SSL for subdomains
			custom_domain: controller.custom_domain,
		};

		add_domain(project_id, new_domain);
		void goto(`/sites/${project_id}`);
	};
</script>

<div class="domains_layout">
	<Project_Sidebar {projects} />

	<div class="domains_content">
		{#if controller.project}
			<div class="p_lg">
				<div class="flex gap_sm align_items_center mb_lg">
					<button type="button" class="plain" onclick={() => goto(`/sites/${project_id}`)}
						>← Back</button
					>
					<h1>Add Domain</h1>
				</div>

				<div class="panel p_md width_lg">
					<h2 class="mb_md">New Domain</h2>

					<div class="mb_md">
						<label class="flex align_items_center">
							<input type="checkbox" bind:checked={controller.custom_domain} />
							<span class="ml_xs">Use custom domain</span>
						</label>
					</div>

					{#if controller.custom_domain}
						<div class="mb_md">
							<label for="domain_name">Custom Domain Name</label>
							<input
								type="text"
								id="domain_name"
								bind:value={controller.domain_name}
								class="w_100"
								placeholder="example.com"
							/>
							<p class="text_color_5 mt_xs">Enter your full domain name (e.g., example.com)</p>
						</div>

						<div class="panel p_md bg_2 mb_md">
							<h3 class="mb_sm">DNS Configuration</h3>
							<p class="mb_sm">To connect your custom domain, add these DNS records:</p>

							<div class="mb_sm">
								<h4>A Record</h4>
								<code>@ → 192.0.2.1</code>
							</div>

							<div class="mb_sm">
								<h4>CNAME Record</h4>
								<code
									>www → {controller.project.name
										.toLowerCase()
										.replace(/\s+/g, '-')}.zzz.software</code
								>
							</div>

							<p class="text_color_5">Note: DNS changes may take up to 48 hours to propagate.</p>
						</div>
					{:else}
						<div class="mb_md">
							<label for="domain_name">Subdomain</label>
							<div class="flex">
								<input
									type="text"
									id="domain_name"
									bind:value={controller.domain_name}
									class="flex_1"
									placeholder="mysite"
								/>
								<span class="p_sm">.zzz.software</span>
							</div>
							<p class="text_color_5 mt_xs">Choose a unique subdomain name</p>
						</div>
					{/if}

					<div class="mt_lg">
						<button
							type="button"
							class="color_b"
							onclick={add_new_domain}
							disabled={!controller.domain_name.trim()}
						>
							Add Domain
						</button>
					</div>
				</div>

				<div class="mt_xl">
					<h2 class="mb_md">Domain Management</h2>

					<div class="panel p_md">
						<h3 class="mb_sm">Current Domains</h3>

						{#if controller.project.domains.length === 0}
							<p class="text_color_5">No domains configured yet.</p>
						{:else}
							<table class="w_100">
								<thead>
									<tr>
										<th class="text_align_start p_xs">Domain</th>
										<th class="text_align_start p_xs">Type</th>
										<th class="text_align_start p_xs">Status</th>
										<th class="text_align_start p_xs">SSL</th>
										<th class="text_align_start p_xs">Actions</th>
									</tr>
								</thead>
								<tbody>
									{#each controller.project.domains as domain (domain.id)}
										<tr>
											<td class="p_xs">{domain.name}</td>
											<td class="p_xs">{domain.custom_domain ? 'Custom' : 'Subdomain'}</td>
											<td class="p_xs">
												<span
													class="chip {domain.status === 'active'
														? 'color_b'
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
												</div>
											</td>
										</tr>
									{/each}
								</tbody>
							</table>
						{/if}
					</div>
				</div>
			</div>
		{:else}
			<div class="p_lg text_align_center">
				<p>Project not found.</p>
				<a href="/sites">Back to Sites</a>
			</div>
		{/if}
	</div>
</div>

<style>
	.domains_layout {
		display: flex;
		height: 100vh;
		overflow: hidden;
	}

	.domains_content {
		flex: 1;
		overflow: auto;
	}

	.chip {
		display: inline-block;
		padding: 2px 8px;
		border-radius: 12px;
		font-size: 0.85em;
	}
</style>
