import {spawn_out} from '@ryanatkn/belt/process.js';
import type {Task} from '@ryanatkn/gro';
import {z} from 'zod';

export const Args = z.object({}).strict();
export type Args = z.infer<typeof Args>;

export const task: Task<Args> = {
	Args,
	summary: 'quick and dirty wrapper around vitest',
	run: async () => {
		// TODO BLOCK do with helpers to find cli
		const spawned = await spawn_out('npx', ['vitest', '--no-watch']);
		if (spawned.stdout) console.log(`spawned.stdout`, spawned.stdout);
		if (spawned.stderr) console.error(`spawned.stderr`, spawned.stderr);
		if (!spawned.result.ok) {
			throw Error(`vitest failed:\n\n${spawned.stdout}\n\n${spawned.stderr}`);
		}
	},
};
