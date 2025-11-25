<script lang="ts">
	import {DEV} from 'esm-env';
	import {resolve} from '$app/paths';
	import {format_url} from '@ryanatkn/belt/url.js';

	import {pkg_context} from './pkg.js';
	import ExternalLink from './ExternalLink.svelte';

	const pkg = pkg_context.get();
</script>

<div>
	<p class="font_family_mono">{pkg.name}@{pkg.package_json.version}</p>
	<p class="font_family_mono">
		DEV: {DEV + ''}
	</p>
	<p><ExternalLink href={pkg.repo_url}>{format_url(pkg.repo_url)}</ExternalLink></p>
	<p><a href={resolve('/about')}>/about</a></p>
	<p><a href={resolve('/settings')}>/settings</a></p>
</div>
