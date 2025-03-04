import {z} from 'zod';
import type {Watcher_Change_Type} from '@ryanatkn/gro/watch_dir.js';

// Define file change types
export const Diskfile_Change_Type = z.enum(['add', 'change', 'unlink']);
export type Diskfile_Change_Type = z.infer<typeof Diskfile_Change_Type>;

// TODO ideally this shouldn't exist, right?
export const map_watcher_change_to_diskfile_change = (
	type: Watcher_Change_Type,
): Diskfile_Change_Type => {
	if (type === 'update') return 'change';
	return type as Diskfile_Change_Type;
};
