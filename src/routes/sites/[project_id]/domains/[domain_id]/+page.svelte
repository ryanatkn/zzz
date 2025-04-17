<script lang="ts">
	import {page} from '$app/state';
	import {goto} from '$app/navigation';

	import {Domains_Controller} from '../domains.svelte.js';
	import Project_Sidebar from '../../../_components/Project_Sidebar.svelte';

	const project_id = page.params.project_id;
	const domain_id = page.params.domain_id;

	// Create controller instance
	const controller = new Domains_Controller(project_id, domain_id);
</script>

<div class="domain_layout">
	<Project_Sidebar />

	<div class="domain_content">
		{#if controller.project && controller.domain}
			<div class="p_lg">
				<div class="flex gap_sm align_items_center mb_lg">
					<h1>Domain Settings</h1>
				</div>

				<div class="panel p_md width_lg">
					<h2 class="mt_0 mb_md">{controller.domain.name}</h2>

					<div class="flex gap_md mb_lg">
						<span
							class="chip {controller.domain.status === 'active'
								? 'color_b'
								: controller.domain.status === 'pending'
									? 'color_e'
									: 'color_5'}"
						>
							{controller.domain.status}
						</span>
						{#if controller.domain.ssl}
							<span class="chip color_b">SSL Enabled</span>
						{:else}
							<span class="chip color_5">No SSL</span>
						{/if}
					</div>

					<form
						onsubmit={(e) => {
							e.preventDefault();
							controller.save_domain_settings();
						}}
					>
						<div class="mb_md">
							<label for="domain_name">Domain Name</label>
							<input
								type="text"
								id="domain_name"
								bind:value={controller.domain_name}
								class="w_100"
								disabled={!controller.custom_domain}
							/>
							<p class="text_color_5 mt_xs">
								{controller.custom_domain
									? 'Custom domain name'
									: 'Subdomain names cannot be changed after creation'}
							</p>
						</div>

						<div class="mb_md">
							<div>Status</div>
							<div class="flex gap_md">
								<label class="flex align_items_center">
									<input
										type="radio"
										name="status"
										value="active"
										bind:group={controller.domain_status}
									/>
									<span class="ml_xs">Active</span>
								</label>
								<label class="flex align_items_center">
									<input
										type="radio"
										name="status"
										value="pending"
										bind:group={controller.domain_status}
									/>
									<span class="ml_xs">Pending</span>
								</label>
								<label class="flex align_items_center">
									<input
										type="radio"
										name="status"
										value="inactive"
										bind:group={controller.domain_status}
									/>
									<span class="ml_xs">Inactive</span>
								</label>
							</div>
						</div>

						<div class="mb_md">
							<label class="flex align_items_center">
								<input type="checkbox" bind:checked={controller.ssl_enabled} />
								<span class="ml_xs">Enable SSL</span>
							</label>
							<p class="text_color_5 mt_xs">
								SSL is automatically enabled for subdomains but must be configured manually for
								custom domains.
							</p>
						</div>

						{#if controller.custom_domain}
							<div class="panel p_md bg_2 mb_lg">
								<h3 class="mb_sm">DNS Configuration</h3>
								<p class="mb_sm">Make sure your domain has these DNS records:</p>

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

								{#if controller.ssl_enabled}
									<div class="mb_sm">
										<h4>SSL Verification</h4>
										<p>To complete SSL setup, add this TXT record:</p>
										<code>_zzz-verify → verify-{domain_id}</code>
									</div>
								{/if}
							</div>
						{/if}

						<div class="flex justify_content_between">
							<button type="submit" class="color_b">Save Changes</button>
							<button type="button" class="color_c" onclick={controller.remove_domain}
								>Remove Domain</button
							>
						</div>
					</form>
				</div>
			</div>
		{:else}
			<div class="p_lg text_align_center">
				<p>Domain not found.</p>
				<a href="/sites">Back to Sites</a>
			</div>
		{/if}
	</div>
</div>

<style>
	.domain_layout {
		display: flex;
		height: 100vh;
		overflow: hidden;
	}

	.domain_content {
		flex: 1;
		overflow: auto;
	}
</style>
