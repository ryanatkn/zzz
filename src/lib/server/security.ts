import type {Handler} from 'hono';

// TODO need to probably change these from exact matches to support wildcards, is there an RFC for this?

// TODO add thorough tests after the API stabilizes more

/**
 * Accepts strings or array-like or set-like objects.
 */
export type Allowed_Origins =
	| string
	| {has: (v: string) => boolean}
	| {includes: (v: string) => boolean};

/**
 * Middleware that checks if the request's origin is allowed.
 * Uses `should_allow_origin` which validates on exact matches only.
 */
export const verify_origin =
	(allowed_origins: Allowed_Origins): Handler =>
	(c, next) => {
		const origin = c.req.header('origin');
		if (!should_allow_origin(origin, allowed_origins)) {
			return c.text('invalid origin', 403);
		}
		return next();
	};

/**
 * Compares `origin` against `allowed_origins` by exact match.
 * Unexpected types return `false`.
 */
export const should_allow_origin = (
	origin: string | null | undefined,
	// TODO needs better config, maybe matchers, maybe accept an iterator of strings/regexps/callbacks
	allowed_origins: Allowed_Origins,
): boolean => {
	if (!origin || !allowed_origins) {
		return false;
	}
	if (typeof allowed_origins === 'string') {
		return origin === allowed_origins;
	} else if ('has' in allowed_origins) {
		return allowed_origins.has(origin);
	} else if ('includes' in allowed_origins) {
		return allowed_origins.includes(origin);
	}
	return false;
};
