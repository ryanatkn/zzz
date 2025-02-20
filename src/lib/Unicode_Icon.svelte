<script lang="ts">
	interface Props {
		icon: string;
		size?: string;
	}

	const {icon, size = 'var(--icon_size_md)'}: Props = $props();

	// TODO BLOCK refactor with `icon_xs`
</script>

<span
	class="inline_block text_align_center"
	style:width={size}
	style:height={size}
	style:font-size={size}>{icon}</span
>
