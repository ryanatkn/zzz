<script lang="ts">
	import {frontend_context} from '$lib/frontend.svelte.js';
	import type {Chat_Template} from '$lib/chat_template.js';
	import type {Model} from '$lib/model.svelte.js';
	import Model_Picker from '$lib/Model_Picker.svelte';
	import type {Uuid} from '$lib/zod_helpers.js';
	import type {Chat} from '$lib/chat.svelte.js';

	const app = frontend_context.get();

	interface Props {
		chat?: Chat;
		oninit?: (chat_id: Uuid) => void;
		heading?: string;
		items?: Array<Model>;
	}

	const {chat: chat_prop, oninit, heading = 'create new chat', items}: Props = $props();

	const get_or_create_chat = () => chat_prop ?? app.chats.add();

	const init_from_template = (template: Chat_Template): void => {
		const chat = get_or_create_chat();

		const models = app.models.filter_by_names(template.model_names);
		if (models && models.length > 0) {
			for (const model of models) {
				chat.add_tape(model);
			}

			if (models.length >= 2) {
				chat.view_mode = 'multi';
			}
		}

		oninit?.(chat.id);
	};

	const init_with_model = (model: Model): void => {
		const chat = get_or_create_chat();

		chat.add_tape(model);

		oninit?.(chat.id);
	};
</script>

{#if heading}
	<h2 class="mt_0 mb_lg">{heading}</h2>
{/if}

<div class="display_flex">
	<section class="width_md min_width_sm">
		<h3 class="mt_0 mb_lg">with model</h3>
		<Model_Picker
			onpick={(model) => {
				if (model) {
					init_with_model(model);
				}
			}}
			{items}
			heading=""
		/>
	</section>

	<section class="width_md min_width_sm">
		<h3 class="mt_0 mb_lg px_md">from template</h3>
		<menu class="unstyled column gap_xs px_md">
			{#each app.chats.chat_templates as chat_template (chat_template.id)}
				<button
					type="button"
					class="plain selectable w_100 py_sm text_align_left justify_content_start font_weight_400"
					onclick={() => init_from_template(chat_template)}
				>
					<div>
						<div class="font_size_lg mb_sm">{chat_template.name}</div>
						<div class="display_flex flex_wrap gap_xs2">
							{#each chat_template.model_names as model_name (model_name)}
								<small class="chip">{model_name}</small>
							{/each}
						</div>
					</div>
				</button>
			{/each}
		</menu>
	</section>
</div>
