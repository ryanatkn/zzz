<script lang="ts">
	import {print_number_with_separators} from '@ryanatkn/belt/print.js';

	interface Props {
		token_count: number;
	}

	const {token_count}: Props = $props();
</script>

<div class="display_flex justify_content_space_between gap_sm px_xs font_family_mono">
	<small
		title="the token count is currently approximated using just one algorithm, when in practice models differ"
		>≈ {print_number_with_separators(token_count + '', ',')} token{token_count === 1
			? ''
			: 's'}</small
	>
</div>
