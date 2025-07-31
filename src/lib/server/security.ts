import {escape_regexp} from '@ryanatkn/belt/regexp.js';
import type {Handler} from 'hono';

// Pattern aliases for common configurations
const PATTERN_ALIASES: Record<string, ReadonlyArray<string> | undefined> = {
	'@localhost': [
		'http://localhost:*',
		'https://localhost:*',
		'http://127.0.0.1:*',
		'https://127.0.0.1:*',
		'http://[::1]:*',
		'https://[::1]:*',
		'http://[::ffff:127.0.0.1]:*',
		'https://[::ffff:127.0.0.1]:*',
	],
	'@localhost_http': [
		'http://localhost:*',
		'http://127.0.0.1:*',
		'http://[::1]:*',
		'http://[::ffff:127.0.0.1]:*',
	],
	'@localhost_https': [
		'https://localhost:*',
		'https://127.0.0.1:*',
		'https://[::1]:*',
		'https://[::ffff:127.0.0.1]:*',
	],
} as const;

/**
 * Parses ALLOWED_ORIGINS env var into regex matchers.
 * Accepts comma-separated patterns with limited wildcards and pattern aliases.
 *
 * Pattern aliases:
 * - @localhost: All localhost variants (HTTP + HTTPS)
 * - @localhost_http: HTTP localhost variants only
 * - @localhost_https: HTTPS localhost variants only
 *
 * Examples:
 * - "@localhost,https://api.example.com"
 * - "@localhost_https,https://*.example.com:*"
 * - "http://localhost:3000,@localhost_http,https://prod.example.com"
 */
export const parse_allowed_origins = (env_value: string | undefined): Array<RegExp> =>
	env_value
		? env_value
				.split(',')
				.map((s) => s.trim())
				.filter(Boolean)
				.flatMap((pattern) => {
					// Expand aliases
					if (pattern.startsWith('@')) {
						const alias = PATTERN_ALIASES[pattern];
						if (!alias) {
							throw new Error(
								`Unknown pattern alias: ${pattern}. Available aliases: ${Object.keys(
									PATTERN_ALIASES,
								).join(', ')}`,
							);
						}
						return [...alias]; // Return a copy of the array
					}
					return pattern;
				})
				.map(origin_pattern_to_regexp)
		: [];

/**
 * Tests if origin matches any of the allowed patterns
 */
export const should_allow_origin = (origin: string, allowed_patterns: Array<RegExp>): boolean =>
	allowed_patterns.some((pattern) => pattern.test(origin));

/**
 * Middleware that checks if the request's origin is allowed.
 * Blocks all requests (including GET) that don't match allowed origins.
 */
export const verify_origin =
	(allowed_patterns: Array<RegExp>): Handler =>
	(c, next) => {
		const origin = c.req.header('origin');
		const referer = c.req.header('referer');
		const sec_fetch_site = c.req.header('sec-fetch-site');

		// Block cross-site requests immediately (modern browsers)
		if (sec_fetch_site === 'cross-site') {
			return c.text('forbidden cross-site request', 403);
		}

		// For requests with origin header
		if (origin) {
			if (!should_allow_origin(origin, allowed_patterns)) {
				return c.text('forbidden origin', 403);
			}
			return next();
		}

		// For requests with referer but no origin (some GET requests)
		if (referer) {
			try {
				const url = new URL(referer);
				const referer_origin = `${url.protocol}//${url.host}`;
				if (!should_allow_origin(referer_origin, allowed_patterns)) {
					return c.text('forbidden referer', 403);
				}
				return next();
			} catch {
				return c.text('invalid referer', 403);
			}
		}

		// No origin or referer or `sec-fetch-site` header - likely direct access (curl, etc).
		// For convenience we'll allow this for now but some users may want additional security,
		// so we may restrict it later or add more options.
		return next();
	};

/**
 * Converts origin patterns with wildcards to regex patterns.
 * Supports:
 * - Wildcard subdomains: *.example.com
 * - Wildcard ports: http://localhost:*
 * - Both: https://*.example.com:*
 * - IPv6 addresses: http://[::1]:3000, https://[2001:db8::1]
 * Does NOT support arbitrary wildcards elsewhere.
 */
const origin_pattern_to_regexp = (pattern: string): RegExp => {
	// Updated regex to support IPv6 addresses in brackets
	// IPv6 pattern matches [xxxx:xxxx:...] format
	const parts = /^(https?:\/\/)(\[[^\]]+\]|[^:/]+)(:\*|:\d+)?(\/.*)?$/.exec(pattern);
	if (!parts) {
		throw new Error(`Invalid origin pattern: ${pattern}`);
	}

	const [, protocol, hostname, port = '', path = ''] = parts;

	// Check wildcards only in allowed positions
	if (hostname.startsWith('[') && hostname.includes('*')) {
		throw new Error(`Wildcards not allowed in IPv6 addresses: ${pattern}`);
	}
	if (!hostname.startsWith('[') && hostname.includes('*') && !hostname.startsWith('*.')) {
		throw new Error(`Wildcard only allowed at start of hostname: ${pattern}`);
	}
	if (port.includes('*') && port !== ':*') {
		throw new Error(`Invalid port wildcard: ${pattern}`);
	}
	if (path.includes('*')) {
		throw new Error(`Wildcards not allowed in path: ${pattern}`);
	}

	// Build regex pattern
	let regex_pattern = '^';
	regex_pattern += escape_regexp(protocol);

	// Handle hostname wildcard or IPv6
	if (hostname.startsWith('[')) {
		// IPv6 address - escape the brackets
		regex_pattern += escape_regexp(hostname);
	} else if (hostname.startsWith('*.')) {
		// *.example.com matches example.com and any.subdomain.example.com
		const domain = escape_regexp(hostname.slice(2));
		regex_pattern += `([^:/]+\\.)?${domain}`;
	} else {
		regex_pattern += escape_regexp(hostname);
	}

	// Handle port wildcard
	if (port === ':*') {
		regex_pattern += '(:\\d+)?'; // Optional port
	} else {
		regex_pattern += escape_regexp(port);
	}

	regex_pattern += escape_regexp(path);
	regex_pattern += '$';

	return new RegExp(regex_pattern);
};
