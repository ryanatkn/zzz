<script lang="ts">
	import {projects_context} from '../../../projects.svelte.js';
	import Project_Sidebar from '../../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../../Section_Sidebar.svelte';
	import Domains_Sidebar from '../../../Domains_Sidebar.svelte';
	import {GLYPH_DELETE} from '$lib/glyphs.js';
	import External_Link from '$lib/External_Link.svelte';

	const projects = projects_context.get();

	const domains_controller = $derived(projects.current_domains_controller);
</script>

<div class="domain_layout">
	<Project_Sidebar />
	<Section_Sidebar section="domains" />
	<Domains_Sidebar />

	<div class="domain_content">
		{#if domains_controller?.project}
			<div class="p_lg">
				<h1 class="mb_lg">Edit domain</h1>

				<p>
					{#if domains_controller.domain_name}
						<External_Link href={`https://${domains_controller.domain_name}`}>
							{domains_controller.domain_name}
						</External_Link>
					{:else}
						[no domain name]
					{/if}
				</p>

				<div class="panel p_md width_md">
					<form
						onsubmit={(e) => {
							e.preventDefault();
							domains_controller.save_domain_settings();
						}}
					>
						<div class="mb_lg">
							<label>
								<h3 class="mt_0 mb_sm">Domain name</h3>
								<input type="text" bind:value={domains_controller.domain_name} class="w_100" />
							</label>
							<p>Enter the full domain name, like example.com or blog.example.com</p>
						</div>

						{#if domains_controller.domain}
							<p>
								<small>created {new Date(domains_controller.domain.created).toLocaleString()}</small
								>
								<br />
								<small>updated {new Date(domains_controller.domain.updated).toLocaleString()}</small
								>
							</p>
						{/if}

						<div class="mb_lg">
							<h3 class="mt_0 mb_sm">Status</h3>
							<div class="flex gap_xl3">
								<label class="flex align_items_center mb_0">
									<input
										type="radio"
										name="status"
										value="active"
										bind:group={domains_controller.domain_status}
									/>
									<span class="ml_xs">active</span>
								</label>
								<label class="flex align_items_center mb_0">
									<input
										type="radio"
										name="status"
										value="pending"
										bind:group={domains_controller.domain_status}
									/>
									<span class="ml_xs">pending</span>
								</label>
								<label class="flex align_items_center mb_0">
									<input
										type="radio"
										name="status"
										value="inactive"
										bind:group={domains_controller.domain_status}
									/>
									<span class="ml_xs">inactive</span>
								</label>
							</div>
						</div>

						<div class="mb_md">
							<label class="flex align_items_center">
								<input type="checkbox" bind:checked={domains_controller.ssl_enabled} />
								<span class="ml_xs">enable SSL</span>
							</label>
						</div>

						<div class="mb_lg">
							<h3 class="mb_sm">DNS</h3>
							<p class="mb_sm">TODO many things</p>

							{#if domains_controller.ssl_enabled}
								<div class="mb_sm">
									<h4>SSL Verification</h4>
									<p>To complete SSL setup, add this TXT record:</p>
									<code
										>_zzz-verify → verify-{domains_controller.domain_id || 'your-domain-id'}</code
									>
								</div>
							{/if}
						</div>

						<div class="w_100 flex justify_content_space_between gap_sm">
							<div>
								<button
									type="submit"
									class="color_a"
									disabled={domains_controller.domain && !domains_controller.has_changes}
								>
									{domains_controller.domain ? 'save changes' : 'add domain'}
								</button>
							</div>

							{#if domains_controller.domain}
								<button
									type="button"
									class="color_c"
									onclick={() => domains_controller.remove_domain()}
								>
									{GLYPH_DELETE} delete domain
								</button>
							{/if}
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
		height: 100%;
		overflow: hidden;
	}

	.domain_content {
		flex: 1;
		overflow: auto;
	}
</style>
