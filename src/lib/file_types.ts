import {z} from 'zod';
import type {Watcher_Change_Type} from '@ryanatkn/gro/watch_dir.js';

// TODO BLOCK @many would this ideally be merged with `*.svelte.ts`? this was designed because of a temporary server build problem. circular deps are weird though, maybe `*.schema.ts` instead?

// Define file change types
export const File_Change_Type = z.enum(['add', 'change', 'unlink']);
export type File_Change_Type = z.infer<typeof File_Change_Type>;

// TODO ideally this shouldn't exist, right?
export const map_watcher_change_to_file_change = (type: Watcher_Change_Type): File_Change_Type => {
	if (type === 'update') return 'change';
	return type as File_Change_Type;
};
