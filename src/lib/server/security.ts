import {escape_regexp} from '@ryanatkn/belt/regexp.js';
import type {Handler} from 'hono';

/**
 * Parses ALLOWED_ORIGINS env var into regex matchers for request source verification.
 * This is NOT a CSRF protection mechanism - it's a simple origin/referer allowlist
 * that verifies requests are coming from expected sources.
 *
 * Accepts comma-separated patterns with limited wildcards:
 * - Exact origins: "https://api.example.com"
 * - Wildcard subdomains: "https://*.example.com" (matches exactly one subdomain level)
 * - Multiple wildcards: "https://*.staging.*.example.com" (for deep subdomains)
 * - Wildcard ports: "http://localhost:*" (matches any port or no port)
 * - IPv6 addresses: "http://[::1]:3000", "https://[2001:db8::1]"
 * - Combined: "https://*.example.com:*"
 *
 * Examples:
 * - "http://localhost:3000,https://prod.example.com"
 * - "https://*.api.example.com,http://127.0.0.1:*"
 * - "http://[::1]:*,https://*.*.corp.example.com:*"
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
 * Tests if a request source (origin or referer) matches any of the allowed patterns.
 * Pattern matching is case-insensitive for domains (as per web standards).
 */
export const should_allow_origin = (origin: string, allowed_patterns: Array<RegExp>): boolean =>
	allowed_patterns.some((p) => p.test(origin));

/**
 * Middleware that verifies the request source against an allowlist.
 *
 * NOT a CSRF protection - this is a simple origin/referer check that:
 * - Checks the Origin header first (if present)
 * - Falls back to Referer header (if no Origin)
 * - Allows requests without Origin/Referer headers (direct access, curl, etc.)
 *
 * This is useful for:
 * - Protecting locally-running services from being called by
 *   untrusted websites as the user browses the web
 * - Restricting which domains can make requests to your API
 * - Preventing embedding of your service in unexpected sites
 * - Basic source verification (but NOT security-critical CSRF protection)
 *
 * @param allowed_patterns - Array of compiled regex patterns from parse_allowed_origins
 */
export const verify_request_source =
	(allowed_patterns: Array<RegExp>): Handler =>
	(c, next) => {
		// Check origin header (preferred, sent by browsers for CORS requests)
		const origin = c.req.header('origin');
		if (origin) {
			if (!should_allow_origin(origin, allowed_patterns)) {
				return c.text('forbidden origin', 403);
			}
			return next();
		}

		// Check referer header (fallback for some requests like gets and navigation)
		const referer = c.req.header('referer');
		if (referer) {
			const referer_origin = extract_origin_from_referer(referer);
			if (!should_allow_origin(referer_origin, allowed_patterns)) {
				return c.text('forbidden referer', 403);
			}
			return next();
		}

		// TODO revisit when we add auth and CSRF protection
		// No origin or referer - usually direct access like curl.
		// Allow because the request is coming from a non-browser source
		// that could be spoofing headers anyway,
		// so we'll assume the user is running trusted code.
		return next();
	};

/**
 * Converts origin patterns with wildcards to regex patterns.
 *
 * Pattern format: protocol://hostname[:port]
 *
 * Wildcard support:
 * - Subdomain wildcards: *.example.com matches sub.example.com (NOT example.com)
 * - Multiple wildcards: *.*.example.com matches api.staging.example.com
 * - Port wildcards: example.com:* matches any port or no port
 * - IPv6 support: [::1], [2001:db8::1] (no wildcards in IPv6)
 *
 * Restrictions:
 * - No paths allowed (origins don't include paths)
 * - Wildcards must be complete labels (*.example.com, not ex*ample.com)
 * - No wildcards in IPv6 addresses
 * - Port wildcards must be :* exactly
 *
 * @throws {Error} If pattern format is invalid
 */
const origin_pattern_to_regexp = (pattern: string): RegExp => {
	// Parse pattern with support for IPv6 addresses in brackets
	const parts = /^(https?:\/\/)(\[[^\]]+\]|[^:/]+)(:\*|:\d+)?(\/.*)?$/.exec(pattern);
	if (!parts) {
		throw new Error(`Invalid origin pattern: ${pattern}`);
	}

	const protocol = parts[1];
	const hostname = parts[2];
	const port = parts[3] ?? '';
	const path = parts[4] ?? '';

	// These should always exist if the regex matched, but check defensively
	if (!protocol || !hostname) {
		throw new Error(`Failed to parse origin pattern: ${pattern}`);
	}

	// Origins cannot have paths
	if (path) {
		throw new Error(`Paths not allowed in origin patterns: ${pattern}`);
	}

	// IPv6 addresses cannot contain wildcards
	if (hostname.startsWith('[') && hostname.includes('*')) {
		throw new Error(`Wildcards not allowed in IPv6 addresses: ${pattern}`);
	}

	// For regular hostnames, wildcards must be complete labels
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

	// Port wildcards must be exactly :*
	if (port.includes('*') && port !== ':*') {
		throw new Error(`Invalid port wildcard: ${pattern}`);
	}

	// Build regex pattern
	let regex_pattern = '^';
	regex_pattern += escape_regexp(protocol);

	// Handle hostname
	if (hostname.startsWith('[')) {
		// IPv6 address - escape brackets and contents
		regex_pattern += escape_regexp(hostname);
	} else {
		// Regular hostname - process wildcards
		const labels = hostname.split('.');
		const regex_labels = labels.map((label) => {
			if (label === '*') {
				// Match exactly one label (no dots, colons, or slashes)
				return '[^./:]+';
			} else {
				return escape_regexp(label);
			}
		});
		regex_pattern += regex_labels.join('\\.');
	}

	// Handle port
	if (port === ':*') {
		// Optional port (matches both with and without port)
		regex_pattern += '(:\\d+)?';
	} else {
		regex_pattern += escape_regexp(port);
	}

	regex_pattern += '$';

	// Case-insensitive matching (web standards specify domains are case-insensitive)
	return new RegExp(regex_pattern, 'i');
};

/**
 * Efficiently extracts the origin from a referer URL, removing the path.
 *
 * @param referer - The referer URL (e.g., "https://example.com/path/to/page")
 * @returns The origin part (e.g., "https://example.com")
 */
const extract_origin_from_referer = (referer: string): string => {
	// Extract origin from referer by finding the third slash
	// Format: protocol://host[:port]/path...
	let slash_count = 0;
	let origin_end = -1;

	for (let i = 0; i < referer.length; i++) {
		if (referer[i] === '/') {
			slash_count++;
			if (slash_count === 3) {
				origin_end = i;
				break;
			}
		}
	}

	// If we found the third slash, extract origin; otherwise use the whole referer
	return origin_end !== -1 ? referer.substring(0, origin_end) : referer;
};
