<script lang="ts">
	import {zzz_context} from '$lib/zzz.svelte.js';
	import File_List from '$lib/File_List.svelte';
	import Prompt_Responses_List from '$lib/Prompt_Responses_List.svelte';
	import Prompt_Form from '$lib/Prompt_Form.svelte';

	interface Props {}

	const {}: Props = $props();

	const zzz = zzz_context.get();

	const {pending_prompts} = $derived(zzz);

	let claude_text = $state('');
	let chatgpt_text = $state('');
	let gemini_text = $state('');

	const hello_server = () => {
		zzz.client.send({type: 'echo', data: 'hello server'});
	};
</script>

<section class="box width_md mx_auto p_md panel">
	<section>
		<button type="button" onclick={hello_server}>hello server</button>
	</section>

	<Prompt_Form
		name="claude"
		onsubmit={(text) => {
			void zzz.send_prompt(text);
			claude_text = text;
		}}
		pending={pending_prompts.has(claude_text)}
	/>
	<Prompt_Responses_List prompt_responses={zzz.prompt_responses} />
	<Prompt_Form
		name="chatgpt"
		onsubmit={(text) => {
			void zzz.send_prompt(text);
			chatgpt_text = text;
		}}
		pending={pending_prompts.has(chatgpt_text)}
	/>
	<Prompt_Form
		name="gemini"
		onsubmit={(text) => {
			void zzz.send_prompt(text);
			gemini_text = text;
		}}
		pending={pending_prompts.has(gemini_text)}
	/>
</section>
<section>
	<File_List files={zzz.files_by_id} />
</section>
