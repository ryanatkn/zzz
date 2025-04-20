import {Bits} from '$lib/bits.svelte.js';
import {Text_Bit, Diskfile_Bit, Sequence_Bit} from '$lib/bit.svelte.js';
import {Capabilities} from '$lib/capabilities.svelte.js';
import {Chat} from '$lib/chat.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {Diskfile_Tab} from '$lib/diskfile_tab.svelte.js';
import {Diskfile_Tabs} from '$lib/diskfile_tabs.svelte.js';
import {Diskfile_History} from '$lib/diskfile_history.svelte.js';
import {Diskfiles} from '$lib/diskfiles.svelte.js';
import {Diskfiles_Editor} from '$lib/diskfiles_editor.svelte.js';
import {Model} from '$lib/model.svelte.js';
import {Models} from '$lib/models.svelte.js';
import {Action} from '$lib/action.svelte.js';
import {Actions} from '$lib/actions.svelte.js';
import {Prompt} from '$lib/prompt.svelte.js';
import {Prompts} from '$lib/prompts.svelte.js';
import {Provider} from '$lib/provider.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Socket} from '$lib/socket.svelte.js';
import {Strip} from '$lib/strip.svelte.js';
import {Tape} from '$lib/tape.svelte.js';
import {Tapes} from '$lib/tapes.svelte.js';
import {Time} from '$lib/time.svelte.js';
import {Ui} from '$lib/ui.svelte.js';
import {Url_Params} from '$lib/url_params.svelte.js';
import type {Cell} from '$lib/cell.svelte.js';

// TODO lazy loading, bundling everything at the root is not ideal

/**
 * Flat mapping of all cell classes by name.
 */
export const cell_classes = {
	Bits,
	Capabilities,
	Chat,
	Chats,
	Diskfile,
	Diskfile_Tab,
	Diskfile_Tabs,
	Diskfile_Bit,
	Diskfile_History,
	Diskfiles,
	Diskfiles_Editor,
	Model,
	Models,
	Action,
	Actions,
	Prompt,
	Prompts,
	Provider,
	Providers,
	Sequence_Bit,
	Socket,
	Strip,
	Tape,
	Tapes,
	Time,
	Text_Bit,
	Ui,
	Url_Params,
} satisfies Record<string, typeof Cell<any>>;

export type Cell_Classes = typeof cell_classes;

export type Cell_Class_Names = keyof Cell_Classes;

export type Cell_Registry_Map = {
	[K in Cell_Class_Names]: InstanceType<Cell_Classes[K]>;
};

/**
 * Type guard to check if a cell is an instance of a specific cell class.
 */
export const is_cell_type = <K extends Cell_Class_Names>(
	cell: Cell | null | undefined,
	class_name: K,
): cell is Cell_Registry_Map[K] => cell?.constructor.name === class_name;

/**
 * Get a list of all registered cell class names.
 */
export const get_cell_class_names = (): Array<Cell_Class_Names> =>
	Object.keys(cell_classes) as Array<Cell_Class_Names>;
