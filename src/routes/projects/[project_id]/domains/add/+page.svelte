<script lang="ts">
	import {projects_context} from '../../../projects.svelte.js';
	import Project_Sidebar from '../../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../../Section_Sidebar.svelte';
	import Domains_Sidebar from '../../../Domains_Sidebar.svelte';

	const projects = projects_context.get();

	// Use the reactive current_domains_controller instead of get_domains_controller
	const domains_controller = $derived(projects.current_domains_controller);
</script>

<div class="domain_layout">
	<Project_Sidebar />
	<Section_Sidebar section="domains" />
	<Domains_Sidebar />

	<div class="domain_content">
		{#if domains_controller?.project}
			<div class="p_lg">
				<div>
					<h1>Add Domain</h1>
					<a href="/projects/{domains_controller.project_id}/domains">← Back to Domains</a>
				</div>

				<div class="panel p_md width_md">
					<form
						onsubmit={(e) => {
							e.preventDefault();
							domains_controller.add_new_domain();
						}}
					>
						<div class="mb_md">
							<label>
								Domain Name
								<input type="text" bind:value={domains_controller.domain_name} class="w_100" />
							</label>
							<p class="text_color_5 mt_xs">
								Enter the full domain name, like example.com or blog.example.com
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
										bind:group={domains_controller.domain_status}
									/>
									<span class="ml_xs">Active</span>
								</label>
								<label class="flex align_items_center">
									<input
										type="radio"
										name="status"
										value="pending"
										bind:group={domains_controller.domain_status}
									/>
									<span class="ml_xs">Pending</span>
								</label>
								<label class="flex align_items_center">
									<input
										type="radio"
										name="status"
										value="inactive"
										bind:group={domains_controller.domain_status}
									/>
									<span class="ml_xs">Inactive</span>
								</label>
							</div>
						</div>

						<div class="mb_md">
							<label class="flex align_items_center">
								<input type="checkbox" bind:checked={domains_controller.ssl_enabled} />
								<span class="ml_xs">Enable SSL</span>
							</label>
						</div>

						<div class="panel p_md bg_2 mb_lg">
							<h3 class="mb_sm">DNS Configuration</h3>
							<p class="mb_sm">After adding your domain, you'll need to configure DNS records:</p>

							<div class="mb_sm">
								<h4>A Record</h4>
								<code>@ → 192.0.2.1</code>
							</div>

							<div class="mb_sm">
								<h4>CNAME Record (for subdomains)</h4>
								<code
									>www → {domains_controller.project.name
										.toLowerCase()
										.replace(/\s+/g, '-')}.zzz.software</code
								>
							</div>
						</div>

						<div>
							<button type="submit" class="color_b">+ add domain</button>
							<a href="/projects/{domains_controller.project_id}/domains">cancel</a>
						</div>
					</form>
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
