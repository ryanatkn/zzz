<script lang="ts">
	import {print_number_with_separators} from '@ryanatkn/belt/print.js';

	interface Props {
		length: number;
		token_count: number;
	}

	const {length, token_count}: Props = $props();
</script>

<div class="flex justify_content_space_between gap_sm font_mono">
	<span title="the token count is currently approximated and inaccurate"
		>~{print_number_with_separators(token_count + '', ',')} token{token_count === 1
			? ''
			: 's'}</span
	>
	<span>{print_number_with_separators(length + '', ',')} char{length === 1 ? '' : 's'}</span>
</div>
