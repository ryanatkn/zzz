<script lang="ts">
	import {DEV} from 'esm-env';
	import {base} from '$app/paths';

	import {pkg_context} from '$routes/pkg.js';

	const pkg = pkg_context.get();
</script>

<div>
	<p class="font_mono">{pkg.name}@{pkg.package_json.version}</p>
	<p class="font_mono">
		DEV: {DEV + ''}
	</p>
	<p><a href="{base}/about">/about</a></p>
</div>
