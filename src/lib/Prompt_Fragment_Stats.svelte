<script lang="ts">
	import {print_number_with_separators} from '@ryanatkn/belt/print.js';

	interface Props {
		length: number;
		token_count: number;
	}

	const {length, token_count}: Props = $props();
</script>

<div class="flex gap_sm">
	<span>{print_number_with_separators(length + '', ',')} chars</span>
	<span>~{print_number_with_separators(token_count + '', ',')} tokens</span>
</div>
