import {SERVER_URL} from '$lib/constants.js';

// TODO add thorough tests

export const should_allow_origin = (
	origin: string | null | undefined,
	// TODO needs better config, maybe matchers, maybe accept an iterator of strings/regexps/callbacks
	allowed_origins:
		| string
		| {has: (v: string) => boolean}
		| {includes: (v: string) => boolean} = SERVER_URL,
): boolean => {
	if (!origin) return false;
	if (typeof allowed_origins === 'string') {
		return origin === SERVER_URL;
	} else if ('has' in allowed_origins) {
		return allowed_origins.has(origin);
	} else if ('includes' in allowed_origins) {
		return allowed_origins.includes(origin);
	}
	return false;
};
