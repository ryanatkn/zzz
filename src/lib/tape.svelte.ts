import type {Model} from '$lib/model.svelte.js';
import {Strip, create_strip_from_text, create_strip_from_bit} from '$lib/strip.svelte.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Tape_Json} from '$lib/tape_types.js';
import {Completion_Request, Completion_Role} from '$lib/completion_types.js';
import {render_messages_to_string, render_completion_messages} from '$lib/tape_helpers.js';
import type {Bit_Type} from '$lib/bit.svelte.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {to_preview, estimate_token_count} from '$lib/helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';
import type {Uuid} from '$lib/zod_helpers.js';
import type {Strip_Json} from '$lib/strip_types.js';
import {UNKNOWN_ERROR_MESSAGE} from '$lib/constants.js';

// TODO add `tape.name` and lots of other things probably

export interface Tape_Options extends Cell_Options<typeof Tape_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
/**
 * A tape is a linear sequence of strips that maintains a chronological
 * record of interactions between the user and the AI.
 */
export class Tape extends Cell<typeof Tape_Json> {
	model_name: string = $state()!;
	readonly model: Model = $derived.by(() => {
		const model = this.app.models.find_by_name(this.model_name);
		if (!model) throw new Error(`Model "${this.model_name}" not found`); // TODO do this differently?
		return model;
	});

	readonly strips: Indexed_Collection<Strip> = new Indexed_Collection();

	enabled: boolean = $state()!;

	readonly content: string = $derived(render_messages_to_string(this.strips.by_id.values()));
	readonly length: number = $derived(this.content.length);
	readonly token_count: number = $derived(estimate_token_count(this.content));
	readonly content_preview: string = $derived(to_preview(this.content));

	constructor(options: Tape_Options) {
		super(Tape_Json, options);

		this.decoders = {
			strips: (items) => {
				if (Array.isArray(items)) {
					this.strips.clear();
					for (const item_json of items) {
						this.add_strip(item_json);
					}
				}
				return HANDLED;
			},
		};

		this.init();
	}

	/**
	 * Add a strip to this tape.
	 */
	add_strip(strip: Strip): void {
		strip.tape_id = this.id;
		this.strips.add(strip);
	}

	/**
	 * Create and add a user strip with the given content.
	 */
	add_user_strip(content: string, request?: Completion_Request): Strip {
		const strip = create_strip_from_text(content, 'user', {tape_id: this.id, request}, this.app);
		this.add_strip(strip);
		return strip;
	}

	/**
	 * Create and add an assistant strip with the given content.
	 */
	add_assistant_strip(content: string, json?: Partial<Strip_Json>): Strip {
		const strip = create_strip_from_text(
			content,
			'assistant',
			{...json, tape_id: this.id},
			this.app,
		);
		this.add_strip(strip);
		return strip;
	}

	/**
	 * Create and add a system strip with the given content.
	 */
	add_system_strip(content: string): Strip {
		const strip = create_strip_from_text(content, 'system', {tape_id: this.id}, this.app);
		this.add_strip(strip);
		return strip;
	}

	/**
	 * Create and add a strip from a bit.
	 */
	add_strip_from_bit(bit: Bit_Type, role: Completion_Role): Strip {
		const strip = create_strip_from_bit(bit, role, {
			tape_id: this.id,
		});
		this.add_strip(strip);
		return strip;
	}

	/**
	 * Remove all strips from this tape.
	 */
	remove_all_strips(): void {
		this.strips.clear();
	}

	/**
	 * Send a message to the AI and create corresponding strips.
	 */
	async send_message(content: string): Promise<Strip> {
		// TODO rethink this API with the completion request/response (see OpenAI/MCP/A2A)
		// TODO maybe do this in the `create_completion: {send_request:` handler?
		const completion_messages = render_completion_messages(this.strips.by_id.values());

		const user_strip = this.add_user_strip(content);

		const completion_request = Completion_Request.parse({
			created: user_strip.created,
			provider_name: this.model.provider_name,
			model: this.model.name,
			prompt: content,
			completion_messages,
		});

		// Create assistant strip with the request info so streaming updates can find it
		const assistant_strip = this.add_assistant_strip('', {request: completion_request});

		// Update the user strip with the request
		user_strip.request = completion_request;

		// Send the prompt with tape history
		try {
			await this.app.api.create_completion({
				completion_request,
				_meta: {progressToken: assistant_strip.id},
			});
		} catch (error) {
			// Update the assistant strip with the error message
			assistant_strip.error_message =
				error instanceof Error ? error.message : UNKNOWN_ERROR_MESSAGE; // TODO extract
			console.error('failed to create completion:', error);
		}

		return assistant_strip;
	}

	switch_model(model_id: Uuid): void {
		const model = this.app.models.items.by_id.get(model_id);
		if (model) {
			this.model_name = model.name; // TODO @many probably should be id
		} else {
			console.error(`model with id ${model_id} not found`);
		}
	}
}
