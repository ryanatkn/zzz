import {PUBLIC_ZZZ_DIRS} from '$env/static/public';
import {resolve} from 'node:path';
import {to_array} from '@ryanatkn/belt/array.js';

import {Zzz_Dir} from '$lib/diskfile_types.js';

export const ZZZ_DIR_DEFAULT = './.zzz';

/**
 * Parse directories from input, which can be either:
 * - A string using colon as separator (e.g. from the `PUBLIC_ZZZ_DIRS` environment variable)
 * - An array of directory strings
 *
 * Defaults to `./.zzz` in the current working directory if no valid directories are provided.
 *
 * This uses the filesystem which is why it's not on the `Zzz_Dir` schema.
 */
export const parse_zzz_dirs = (
	value: string | Array<string> = PUBLIC_ZZZ_DIRS,
): ReadonlyArray<Zzz_Dir> => {
	// Convert to array and process each entry
	const dirs = to_array(value);

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
	const parsed_dirs = processed_dirs.length ? processed_dirs : [ZZZ_DIR_DEFAULT];

	// Map to Zzz_Dir and freeze the array
	return Object.freeze(parsed_dirs.map((d) => Zzz_Dir.parse(resolve(d))));
};
