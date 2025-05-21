import type {Task} from '@ryanatkn/gro';
import {spawn_cli} from '@ryanatkn/gro/cli.js';
import {z} from 'zod';

export const Args = z.object({_: z.array(z.string()).optional()}).strict(); // TODO add watch/no-watch
export type Args = z.infer<typeof Args>;

export const task: Task<Args> = {
	Args,
	summary: 'quick and unfeatureful wrapper around vitest',
	run: async ({args: {_: rest_args = []}}) => {
		const spawned = await spawn_cli('vitest', ['run', ...rest_args, '--dir', 'src']); // TODO proper forwarding
		if (!spawned?.ok) {
			throw new Error(`vitest failed with exit code ${spawned?.code}`);
		}
	},
};
