import {Parts} from '$lib/parts.svelte.js';
import {TextPart, DiskfilePart} from '$lib/part.svelte.js';
import {Capabilities} from '$lib/capabilities.svelte.js';
import {Chat} from '$lib/chat.svelte.js';
import {Chats} from '$lib/chats.svelte.js';
import {Diskfile} from '$lib/diskfile.svelte.js';
import {DiskfileTab} from '$lib/diskfile_tab.svelte.js';
import {DiskfileTabs} from '$lib/diskfile_tabs.svelte.js';
import {DiskfileHistory} from '$lib/diskfile_history.svelte.js';
import {Diskfiles} from '$lib/diskfiles.svelte.js';
import {DiskfilesEditor} from '$lib/diskfiles_editor.svelte.js';
import {Model} from '$lib/model.svelte.js';
import {Models} from '$lib/models.svelte.js';
import {Action} from '$lib/action.svelte.js';
import {Actions} from '$lib/actions.svelte.js';
import {Prompt} from '$lib/prompt.svelte.js';
import {Prompts} from '$lib/prompts.svelte.js';
import {Provider} from '$lib/provider.svelte.js';
import {Providers} from '$lib/providers.svelte.js';
import {Socket} from '$lib/socket.svelte.js';
import {Turn} from '$lib/turn.svelte.js';
import {Thread} from '$lib/thread.svelte.js';
import {Threads} from '$lib/threads.svelte.js';
import {Time} from '$lib/time.svelte.js';
import {Ui} from '$lib/ui.svelte.js';
import type {Cell} from '$lib/cell.svelte.js';

export const cell_classes = {
	Parts,
	Capabilities,
	Chat,
	Chats,
	Diskfile,
	DiskfileTab,
	DiskfileTabs,
	DiskfilePart,
	DiskfileHistory,
	Diskfiles,
	DiskfilesEditor,
	Model,
	Models,
	Action,
	Actions,
	Prompt,
	Prompts,
	Provider,
	Providers,
	Socket,
	Turn,
	Thread,
	Threads,
	Time,
	TextPart,
	Ui,
} satisfies Record<string, typeof Cell<any>>;

export type CellClasses = typeof cell_classes;

export type CellClassNames = keyof CellClasses;

export type CellRegistryMap = {
	[K in CellClassNames]: InstanceType<CellClasses[K]>;
};

/**
 * Type guard to check if a cell is an instance of a specific cell class.
 */
export const is_cell_type = <K extends CellClassNames>(
	cell: Cell<any> | null | undefined,
	class_name: K,
): cell is CellRegistryMap[K] => cell?.constructor.name === class_name;

/**
 * Get a list of all registered cell class names.
 */
export const get_cell_class_names = (): Array<CellClassNames> =>
	Object.keys(cell_classes) as Array<CellClassNames>;
