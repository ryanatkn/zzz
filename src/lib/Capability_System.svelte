<script lang="ts">
	import {DEV} from 'esm-env';
	import {base} from '$app/paths';
	import {format_url} from '@ryanatkn/belt/url.js';

	import {pkg_context} from '$lib/pkg.js';
	import External_Link from '$lib/External_Link.svelte';

	const pkg = pkg_context.get();
</script>

<div>
	<p class="font_family_mono">{pkg.name}@{pkg.package_json.version}</p>
	<p class="font_family_mono">
		DEV: {DEV + ''}
	</p>
	<p><External_Link href={pkg.repo_url}>{format_url(pkg.repo_url)}</External_Link></p>
	<p><a href="{base}/about">/about</a></p>
</div>
