<script lang="ts">
	import {print_number_with_separators} from '@ryanatkn/belt/print.js';

	interface Props {
		length: number;
		token_count: number;
	}

	const {length, token_count}: Props = $props();
</script>

<div class="flex_1 flex justify_content_space_between gap_sm font_mono">
	<small
		title="the token count is currently approximated using just one algorithm, when in practice models differ"
		>≈ {print_number_with_separators(token_count + '', ',')} token{token_count === 1
			? ''
			: 's'}</small
	> <small>{print_number_with_separators(length + '', ',')} char{length === 1 ? '' : 's'}</small>
</div>
