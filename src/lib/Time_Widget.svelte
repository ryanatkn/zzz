<script lang="ts">
	import {format_timestamp} from '$lib/time_helpers.js';

	interface Props {
		value: Date;
	}

	const {value}: Props = $props();

	const timestamp = format_timestamp(value);
	const [time_number_part, time_am_pm_part] = timestamp.split(' ');
</script>

<div class="font_family_serif font_size_xl3">
	{time_number_part}
	<small class="font_size_xl">{time_am_pm_part}</small>
</div>
