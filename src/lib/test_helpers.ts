import type {Frontend} from '$lib/frontend.svelte.js';
import type {Diskfile_Path} from '$lib/diskfile_types.js';

// TODO these aren't used, should they be for improved type safety?

/**
 * Vitest's `expects` does not narrow types, this does for falsy values.
 *
 * @see https://github.com/vitest-dev/vitest/issues/2883
 */

export const expect_ok: <T>(value: T, message?: string) => asserts value = (value, message) => {
	if (!value) {
		throw new Error(message ?? 'Expected value to be truthy');
	}
};

/**
 * Vitest's `expects` does not narrow types, this does for undefined values.
 *
 * @see https://github.com/vitest-dev/vitest/issues/2883
 */
export const expect_defined: <T>(value: T | undefined, message?: string) => asserts value is T = (
	value,
	message,
) => {
	if (value === undefined) {
		throw new Error(message ?? 'Expected value to be defined');
	}
};

/**
 * Vitest's `expects` does not narrow types, this does for nullish values.
 *
 * @see https://github.com/vitest-dev/vitest/issues/2883
 */
export const expect_nonnullish: <T>(
	value: T | undefined | null,
	message?: string,
) => asserts value is T = (value, message) => {
	if (value == null) {
		throw new Error(message ?? 'Expected value to be non-nullish');
	}
};

/**
 * Applies testing-specific modifications to a Zzz instance.
 */
export const monkeypatch_zzz_for_tests = <T extends Frontend>(app: T): T => {
	// Override diskfiles.update to be synchronous.
	// In the real implementation, this would make a server request.
	// Probably want to mock differently than this but it's fine for now.
	app.diskfiles.update = (path: Diskfile_Path, content: string) => {
		const diskfile = app.diskfiles.get_by_path(path);
		if (diskfile) {
			diskfile.content = content;
		}
		return Promise.resolve();
	};

	return app;
};
