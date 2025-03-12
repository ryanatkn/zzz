import {PUBLIC_ZZZ_DIRS} from '$env/static/public';
import {resolve} from 'node:path';

import {Zzz_Dir} from '$lib/diskfile_types.js';

export const ZZZ_DIR_DEFAULT = './.zzz';

/**
 * Parse directories from the `PUBLIC_ZZZ_DIRS` environment variable,
 * using colon as separator.
 * Defaults to `./.zzz` in the current working directory.
 */
export const parse_zzz_dirs = (value: string = PUBLIC_ZZZ_DIRS): ReadonlyArray<Zzz_Dir> =>
	Object.freeze(
		(value
			? value
					.split(':')
					.map((d) => d.trim())
					.filter((d) => !!d)
			: [ZZZ_DIR_DEFAULT]
		).map((d) => Zzz_Dir.parse(resolve(d))),
	);
