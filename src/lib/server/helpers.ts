import {dirname, join} from 'node:path';
import {format_file} from '@ryanatkn/gro/format_file.js';

import {Scoped_Fs} from '$lib/server/scoped_fs.js';
import {Action_Inputs, type Action_Outputs} from '$lib/action_collections.js';

// TODO @db refactor
export const save_completion_response_to_disk = async (
	input: Action_Inputs['create_completion'],
	output: Action_Outputs['create_completion'],
	dir: string,
	scoped_fs: Scoped_Fs,
): Promise<void> => {
	// includes `Date.now()` for sorting purposes
	const filename = `${input.completion_request.provider_name}__${Date.now()}__${input.completion_request.model}.json`; // TODO include model data in these

	const path = join(dir, filename);

	const json = {input, output};

	await write_json(path, json, scoped_fs);
};
// TODO @db refactor
const write_json = async (path: string, json: unknown, scoped_fs: Scoped_Fs): Promise<void> => {
	// Check if directory exists and create it if needed
	if (!(await scoped_fs.exists(path))) {
		await scoped_fs.mkdir(dirname(path), {recursive: true});
	}

	const formatted = await format_file(JSON.stringify(json), {parser: 'json'});

	// Use Scoped_Fs for writing the file
	console.log('writing json', path, formatted.length);
	await scoped_fs.write_file(path, formatted);
};
