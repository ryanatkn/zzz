<script lang="ts">
	import {projects_context} from '../../../projects.svelte.js';
	import Project_Sidebar from '../../../Project_Sidebar.svelte';
	import Section_Sidebar from '../../../Section_Sidebar.svelte';
	import Domains_Sidebar from '../../../Domains_Sidebar.svelte';
	import {GLYPH_DELETE} from '$lib/glyphs.js';
	import External_Link from '$lib/External_Link.svelte';
	import Glyph from '$lib/Glyph.svelte';

	const projects = projects_context.get();

	const domains_viewmodel = $derived(projects.current_domains_viewmodel);
</script>

<div class="domain_layout">
	<Project_Sidebar />
	<Section_Sidebar section="domains" />
	<Domains_Sidebar />

	<div class="domain_content">
		{#if domains_viewmodel?.project}
			<div class="p_lg">
				<h1 class="mb_lg">Edit domain</h1>

				<p>
					{#if domains_viewmodel.domain_name}
						<External_Link href={`https://${domains_viewmodel.domain_name}`}>
							{domains_viewmodel.domain_name}
						</External_Link>
					{:else}
						[no domain name]
					{/if}
				</p>

				<div class="panel p_md width_md">
					<form
						onsubmit={(e) => {
							e.preventDefault();
							domains_viewmodel.save_domain_settings();
						}}
					>
						<div class="mb_lg">
							<label>
								<h3 class="mt_0 mb_sm">Domain name</h3>
								<input type="text" bind:value={domains_viewmodel.domain_name} class="w_100" />
							</label>
							<p>Enter the full domain name, like example.com or blog.example.com</p>
						</div>

						{#if domains_viewmodel.domain}
							<p>
								<small>created {new Date(domains_viewmodel.domain.created).toLocaleString()}</small>
								<br />
								<small>updated {new Date(domains_viewmodel.domain.updated).toLocaleString()}</small>
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
										bind:group={domains_viewmodel.domain_status}
									/>
									<span class="ml_xs">active</span>
								</label>
								<label class="flex align_items_center mb_0">
									<input
										type="radio"
										name="status"
										value="pending"
										bind:group={domains_viewmodel.domain_status}
									/>
									<span class="ml_xs">pending</span>
								</label>
								<label class="flex align_items_center mb_0">
									<input
										type="radio"
										name="status"
										value="inactive"
										bind:group={domains_viewmodel.domain_status}
									/>
									<span class="ml_xs">inactive</span>
								</label>
							</div>
						</div>

						<div class="mb_md">
							<label class="flex align_items_center">
								<input type="checkbox" bind:checked={domains_viewmodel.ssl_enabled} />
								<span class="ml_xs">enable SSL</span>
							</label>
						</div>

						<div class="mb_lg">
							<h3 class="mb_sm">DNS</h3>
							<p class="mb_sm">TODO many things</p>

							{#if domains_viewmodel.ssl_enabled}
								<div class="mb_sm">
									<h4>SSL Verification</h4>
									<p>To complete SSL setup, add this TXT record:</p>
									<code>_zzz-verify → verify-{domains_viewmodel.domain_id || 'your-domain-id'}</code
									>
								</div>
							{/if}
						</div>

						<div class="w_100 flex justify_content_space_between gap_sm">
							<div>
								<button
									type="submit"
									class="color_a"
									disabled={domains_viewmodel.domain && !domains_viewmodel.has_changes}
								>
									{domains_viewmodel.domain ? 'save changes' : 'add domain'}
								</button>
							</div>

							{#if domains_viewmodel.domain}
								<button
									type="button"
									class="color_c"
									onclick={() => domains_viewmodel.remove_domain()}
								>
									<Glyph text={GLYPH_DELETE} attrs={{class: 'mr_xs2'}} /> delete domain
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
