import type {Task} from '@ryanatkn/gro';
import {spawn_cli} from '@ryanatkn/gro/cli.js';
import {z} from 'zod';

export const Args = z.object({}).strict(); // TODO add watch/no-watch
export type Args = z.infer<typeof Args>;

export const task: Task<Args> = {
	Args,
	summary: 'quick and unfeatureful wrapper around vitest',
	run: async () => {
		const spawned = await spawn_cli('vitest', ['--no-watch']);
		if (!spawned?.ok) {
			throw Error(`vitest failed with exit code ${spawned?.code}`);
		}
	},
};
