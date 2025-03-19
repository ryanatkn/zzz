import type {Task} from '@ryanatkn/gro';
import {spawn_cli} from '@ryanatkn/gro/cli.js';
import {z} from 'zod';

export const Args = z.object({}).strict(); // TODO add watch/no-watch
export type Args = z.infer<typeof Args>;

export const task: Task<Args> = {
	Args,
	summary: 'quick and unfeatureful wrapper around vitest',
	run: async () => {
		const spawned = await spawn_cli('vitest', [
			'--no-watch',
			// 'cell_basic.svelte.test.ts',
			// 'cell_advanced.svelte.test.ts',
			// 'bit.svelte.test.ts',
			// 'bit_text.svelte.test.ts',
			// 'bit_diskfile.svelte.test.ts',
			// 'bit_sequence.svelte.test.ts',
		]);
		if (!spawned?.ok) {
			throw Error(`vitest failed with exit code ${spawned?.code}`);
		}
	},
};
