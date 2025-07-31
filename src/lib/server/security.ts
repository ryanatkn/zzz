import {escape_regexp} from '@ryanatkn/belt/regexp.js';
import type {Handler} from 'hono';

/**
 * Parses ALLOWED_ORIGINS env var into regex matchers.
 * Accepts comma-separated patterns with limited wildcards.
 *
 * Examples:
 * - "https://api.example.com"
 * - "https://*.example.com:*"
 * - "http://localhost:3000,https://prod.example.com"
 * - "https://*.staging.*.example.com" (multiple wildcards for deep subdomains)
 */
export const parse_allowed_origins = (env_value: string | undefined): Array<RegExp> =>
	env_value
		? env_value
				.split(',')
				.map((s) => s.trim())
				.filter(Boolean)
				.map(origin_pattern_to_regexp)
		: [];

/**
 * Tests if origin matches any of the allowed patterns
 */
export const should_allow_origin = (origin: string, allowed_patterns: Array<RegExp>): boolean =>
	allowed_patterns.some((pattern) => pattern.test(origin));

/**
 * Middleware that checks if the request's origin is allowed.
 * Blocks cross-site requests that don't match allowed origins.
 * Allows requests without origin/referer headers (e.g., direct access).
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
		// Allow these requests as per requirements (will add token auth later).
		return next();
	};

/**
 * Converts origin patterns with wildcards to regex patterns.
 * Supports:
 * - Wildcard subdomains: *.example.com (matches one level)
 * - Multiple wildcards: *.staging.*.example.com
 * - Wildcard ports: http://localhost:*
 * - IPv6 addresses: http://[::1]:3000, https://[2001:db8::1]
 * Does NOT support:
 * - Paths (origins don't have paths)
 * - Wildcards in other positions
 */
const origin_pattern_to_regexp = (pattern: string): RegExp => {
	// Parse the pattern into components
	// Updated regex to support IPv6 addresses in brackets
	const parts = /^(https?:\/\/)(\[[^\]]+\]|[^:/]+)(:\*|:\d+)?(\/.*)?$/.exec(pattern);
	if (!parts) {
		throw new Error(`Invalid origin pattern: ${pattern}`);
	}

	const [, protocol, hostname, port = '', path = ''] = parts;

	// Check for paths (not allowed)
	if (path) {
		throw new Error(`Paths not allowed in origin patterns: ${pattern}`);
	}

	// Check wildcards only in allowed positions
	if (hostname.startsWith('[') && hostname.includes('*')) {
		throw new Error(`Wildcards not allowed in IPv6 addresses: ${pattern}`);
	}

	// For non-IPv6 hostnames, check that wildcards only appear as complete labels
	if (!hostname.startsWith('[')) {
		const labels = hostname.split('.');
		for (const label of labels) {
			if (label.includes('*') && label !== '*') {
				throw new Error(
					`Wildcards must be complete labels (e.g., *.example.com, not *example.com): ${pattern}`,
				);
			}
		}
	}

	if (port.includes('*') && port !== ':*') {
		throw new Error(`Invalid port wildcard: ${pattern}`);
	}

	// Build regex pattern
	let regex_pattern = '^';
	regex_pattern += escape_regexp(protocol);

	// Handle hostname - IPv6 or regular hostname with potential wildcards
	if (hostname.startsWith('[')) {
		// IPv6 address - escape the brackets
		regex_pattern += escape_regexp(hostname);
	} else {
		// Regular hostname - handle wildcards
		const labels = hostname.split('.');
		const regex_labels = labels.map((label) => {
			if (label === '*') {
				// Match exactly one label (no dots allowed)
				return '[^./:]+';
			} else {
				return escape_regexp(label);
			}
		});
		regex_pattern += regex_labels.join('\\.');
	}

	// Handle port wildcard
	if (port === ':*') {
		regex_pattern += '(:\\d+)?'; // Optional port
	} else {
		regex_pattern += escape_regexp(port);
	}

	regex_pattern += '$';

	// Create case-insensitive regex (domains are case-insensitive)
	return new RegExp(regex_pattern, 'i');
};
