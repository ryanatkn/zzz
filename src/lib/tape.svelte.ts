import {encode as tokenize} from 'gpt-tokenizer';

import {type Model} from '$lib/model.svelte.js';
import {Strip, Strip_Role, create_strip, create_strip_from_bit} from '$lib/strip.svelte.js';
import {Cell, type Cell_Options} from '$lib/cell.svelte.js';
import {Tape_Json} from '$lib/tape_types.js';
import {render_tape} from '$lib/tape_helpers.js';
import {type Bit_Type} from '$lib/bit.svelte.js';
import {HANDLED} from '$lib/cell_helpers.js';
import {to_completion_response_text} from '$lib/response_helpers.js';
import {Completion_Request, type Completion_Response} from '$lib/action_types.js';
import {to_preview} from '$lib/helpers.js';
import {Indexed_Collection} from '$lib/indexed_collection.svelte.js';

// TODO add `tape.name` probably

export interface Tape_Options extends Cell_Options<typeof Tape_Json> {} // eslint-disable-line @typescript-eslint/no-empty-object-type
/**
 * A tape is a linear sequence of strips that maintains a chronological
 * record of interactions between the user and the AI.
 */
export class Tape extends Cell<typeof Tape_Json> {
	model_name: string = $state()!;
	readonly model: Model = $derived.by(() => {
		const model = this.zzz.models.find_by_name(this.model_name);
		if (!model) throw Error(`Model "${this.model_name}" not found`); // TODO do this differently?
		return model;
	});

	strips: Indexed_Collection<Strip> = new Indexed_Collection();

	enabled: boolean = $state()!;

	readonly content: string = $derived(render_tape([...this.strips.by_id.values()]));
	readonly length: number = $derived(this.content.length);
	readonly tokens: Array<number> = $derived(tokenize(this.content));
	readonly token_count: number = $derived(this.tokens.length);
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
		const strip = create_strip(content, 'user', {tape_id: this.id, request}, this.zzz);
		this.add_strip(strip);
		return strip;
	}

	/**
	 * Create and add an assistant strip with the given content.
	 */
	add_assistant_strip(content: string, response?: Completion_Response): Strip {
		const strip = create_strip(content, 'assistant', {tape_id: this.id, response}, this.zzz);
		this.add_strip(strip);
		return strip;
	}

	/**
	 * Create and add a system strip with the given content.
	 */
	add_system_strip(content: string): Strip {
		const strip = create_strip(content, 'system', {tape_id: this.id}, this.zzz);
		this.add_strip(strip);
		return strip;
	}

	/**
	 * Create and add a strip from a bit.
	 */
	add_strip_from_bit(bit: Bit_Type, role: Strip_Role): Strip {
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
		// TODO hacky, rethink these interfaces, and this method API
		// Build message history for the model with normalized content
		const tape_history: Completion_Request['tape_history'] = [];
		for (const s of this.strips.by_id.values()) {
			tape_history.push({
				role: s.role,
				content:
					s.role === 'assistant' && s.response
						? to_completion_response_text(s.response) || ''
						: s.content,
			});
		}

		const user_strip = this.add_user_strip(content);

		// Create a properly typed completion request
		const completion_request = Completion_Request.parse({
			created: user_strip.created,
			request_id: user_strip.id,
			provider_name: this.model.provider_name,
			model: this.model.name,
			prompt: content,
			tape_history,
		});

		// Update the user strip with the request
		user_strip.request = completion_request;

		// TODO better abstraction
		// Create assistant strip immediately with empty content to show pending state
		const assistant_strip = this.add_assistant_strip('', undefined);

		// Send the prompt with tape history
		const response = await this.zzz.send_prompt(
			content,
			this.model.provider_name,
			this.model.name,
			tape_history,
		);

		// Get the response text
		const response_text = to_completion_response_text(response.completion_response) || '';

		// Update the assistant strip with the response content and metadata
		assistant_strip.content = response_text;
		assistant_strip.response = response.completion_response;

		return assistant_strip;
	}
}
