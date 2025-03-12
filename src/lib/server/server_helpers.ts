import {PUBLIC_ZZZ_DIRS} from '$env/static/public';
import {resolve} from 'node:path';
import {to_array} from '@ryanatkn/belt/array.js';
import {cwd} from 'node:process';

import {Zzz_Dir} from '$lib/diskfile_types.js';
import {ZZZ_DIRNAME} from '$lib/constants.js';

export const ZZZ_DIR = './' + ZZZ_DIRNAME;

/**
 * Parse directories from input, which can be either:
 * - A string using colon as separator (e.g. from the `PUBLIC_ZZZ_DIRS` environment variable)
 * - An array of directory strings
 *
 * All paths are converted to absolute paths.
 * Defaults to an absolute path to `./.zzz` if no valid directories are provided.
 */
export const parse_zzz_dirs = (
	value: string | Array<string> = PUBLIC_ZZZ_DIRS,
	base_dir: string = cwd(),
): ReadonlyArray<Zzz_Dir> => {
	// Convert to array and process each entry
	const zzz_dir = resolve(base_dir, ZZZ_DIR);
	const dirs = to_array(value || zzz_dir);

	// Process entries, splitting strings by colon and filtering out non-strings
	const processed_dirs = dirs.flatMap((d) =>
		typeof d === 'string'
			? d
					.split(':')
					.map((part) => part.trim())
					.filter((part) => !!part)
			: [],
	);

	// Use default if no valid directories were provided
	const parsed_dirs = processed_dirs.length ? processed_dirs : [zzz_dir];

	// Map to Zzz_Dir and freeze the array
	return Object.freeze(parsed_dirs.map((d) => Zzz_Dir.parse(resolve(base_dir, d))));
};
