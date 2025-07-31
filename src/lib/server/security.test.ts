import {describe, test, expect, vi} from 'vitest';
import type {Handler} from 'hono';

import {parse_allowed_origins, should_allow_origin, verify_origin} from './security.js';

// Test helpers
const create_mock_context = (headers: Record<string, string> = {}) => {
	const next = vi.fn();
	const text = vi.fn((content: string, status: number) => ({content, status}));

	// Convert all header keys to lowercase for case-insensitive lookup
	const normalized_headers: Record<string, string> = {};
	for (const [key, value] of Object.entries(headers)) {
		normalized_headers[key.toLowerCase()] = value;
	}

	const c = {
		req: {
			header: (name: string) => normalized_headers[name.toLowerCase()],
		},
		text,
	};

	return {c, next, text};
};

const test_pattern = (
	pattern: string,
	valid_origins: Array<string>,
	invalid_origins: Array<string>,
) => {
	const regexps = parse_allowed_origins(pattern);

	for (const origin of valid_origins) {
		expect(should_allow_origin(origin, regexps), `${origin} should match ${pattern}`).toBe(true);
	}

	for (const origin of invalid_origins) {
		expect(should_allow_origin(origin, regexps), `${origin} should not match ${pattern}`).toBe(
			false,
		);
	}
};

const test_middleware_allows = async (handler: Handler, headers: Record<string, string>) => {
	const {c, next} = create_mock_context(headers);
	await handler(c as any, next);
	expect(next).toHaveBeenCalled();
};

const test_middleware_blocks = async (
	handler: Handler,
	headers: Record<string, string>,
	expected_message: string,
	expected_status = 403,
) => {
	const {c, next, text} = create_mock_context(headers);
	const result = await handler(c as any, next);
	expect(next).not.toHaveBeenCalled();
	expect(text).toHaveBeenCalledWith(expected_message, expected_status);
	expect(result).toEqual({content: expected_message, status: expected_status});
};

describe('parse_allowed_origins', () => {
	test('returns empty array for undefined', () => {
		expect(parse_allowed_origins(undefined)).toEqual([]);
	});

	test('returns empty array for empty string', () => {
		expect(parse_allowed_origins('')).toEqual([]);
	});

	test('parses single origin', () => {
		const patterns = parse_allowed_origins('http://localhost:3000');
		expect(patterns).toHaveLength(1);
		expect(patterns[0]).toBeInstanceOf(RegExp);
	});

	test('parses multiple comma-separated origins', () => {
		const patterns = parse_allowed_origins('http://localhost:3000,https://example.com');
		expect(patterns).toHaveLength(2);
	});

	test('trims whitespace from origins', () => {
		const patterns = parse_allowed_origins('  http://localhost:3000  ,  https://example.com  ');
		expect(patterns).toHaveLength(2);
	});

	test('filters out empty entries', () => {
		const patterns = parse_allowed_origins('http://localhost:3000,,https://example.com,');
		expect(patterns).toHaveLength(2);
	});

	test('handles complex patterns', () => {
		const patterns = parse_allowed_origins(
			'https://*.example.com,http://localhost:*,https://*.test.com:*',
		);
		expect(patterns).toHaveLength(3);
	});
});

describe('should_allow_origin', () => {
	test('returns false for empty patterns', () => {
		expect(should_allow_origin('http://example.com', [])).toBe(false);
	});

	test('matches exact origins', () => {
		const patterns = parse_allowed_origins('http://example.com');
		expect(should_allow_origin('http://example.com', patterns)).toBe(true);
		expect(should_allow_origin('https://example.com', patterns)).toBe(false);
	});

	test('matches any of multiple patterns', () => {
		const patterns = parse_allowed_origins('http://localhost:3000,https://example.com');
		expect(should_allow_origin('http://localhost:3000', patterns)).toBe(true);
		expect(should_allow_origin('https://example.com', patterns)).toBe(true);
		expect(should_allow_origin('http://other.com', patterns)).toBe(false);
	});
});

describe('pattern_to_regexp', () => {
	describe('exact patterns', () => {
		test('matches exact http origins', () => {
			test_pattern(
				'http://example.com',
				['http://example.com'],
				['https://example.com', 'http://example.org', 'http://sub.example.com'],
			);
		});

		test('matches exact https origins', () => {
			test_pattern(
				'https://example.com',
				['https://example.com'],
				['http://example.com', 'https://example.org', 'https://sub.example.com'],
			);
		});

		test('matches origins with ports', () => {
			test_pattern(
				'http://localhost:3000',
				['http://localhost:3000'],
				['http://localhost', 'http://localhost:3001', 'https://localhost:3000'],
			);
		});

		test('matches origins with paths', () => {
			test_pattern(
				'http://example.com/api',
				['http://example.com/api'],
				['http://example.com', 'http://example.com/api2', 'http://example.com/api/v1'],
			);
		});

		test('matches IPv6 localhost', () => {
			test_pattern(
				'http://[::1]:3000',
				['http://[::1]:3000'],
				['http://[::1]', 'http://[::1]:3001', 'https://[::1]:3000', 'http://::1:3000'],
			);
		});

		test('matches full IPv6 addresses', () => {
			test_pattern(
				'https://[2001:db8:85a3::8a2e:370:7334]:8443',
				['https://[2001:db8:85a3::8a2e:370:7334]:8443'],
				[
					'https://[2001:db8:85a3::8a2e:370:7334]',
					'https://[2001:db8:85a3::8a2e:370:7334]:8444',
					'http://[2001:db8:85a3::8a2e:370:7334]:8443',
				],
			);
		});

		test('matches IPv6 addresses without port', () => {
			test_pattern(
				'http://[2001:db8::1]',
				['http://[2001:db8::1]'],
				['http://[2001:db8::1]:80', 'https://[2001:db8::1]', 'http://2001:db8::1'],
			);
		});

		test('matches IPv6 with paths', () => {
			test_pattern(
				'https://[::1]/api/v1',
				['https://[::1]/api/v1'],
				['https://[::1]', 'https://[::1]/api', 'https://[::1]/api/v1/users'],
			);
		});

		test('matches IPv4-mapped IPv6 addresses', () => {
			test_pattern(
				'http://[::ffff:127.0.0.1]:3000',
				['http://[::ffff:127.0.0.1]:3000'],
				[
					'http://[::ffff:127.0.0.1]',
					'http://[::ffff:127.0.0.1]:3001',
					'http://127.0.0.1:3000', // Regular IPv4 should not match
				],
			);
		});

		test('matches IPv4-mapped IPv6 without port', () => {
			test_pattern(
				'https://[::ffff:192.168.1.1]',
				['https://[::ffff:192.168.1.1]'],
				['https://[::ffff:192.168.1.1]:443', 'https://192.168.1.1', 'http://[::ffff:192.168.1.1]'],
			);
		});
	});

	describe('wildcard subdomains', () => {
		test('matches wildcard at beginning of hostname', () => {
			test_pattern(
				'https://*.example.com',
				['https://sub.example.com', 'https://deep.sub.example.com', 'https://example.com'],
				['http://sub.example.com', 'https://example.org', 'https://examplexcom'],
			);
		});

		test('wildcard subdomain with port', () => {
			test_pattern(
				'https://*.example.com:443',
				['https://sub.example.com:443', 'https://example.com:443'],
				['https://sub.example.com', 'https://sub.example.com:444'],
			);
		});
	});

	describe('wildcard ports', () => {
		test('matches any port or no port', () => {
			test_pattern(
				'http://localhost:*',
				['http://localhost', 'http://localhost:3000', 'http://localhost:8080'],
				['https://localhost', 'http://127.0.0.1:3000'],
			);
		});

		test('wildcard port with exact hostname', () => {
			test_pattern(
				'https://api.example.com:*',
				['https://api.example.com', 'https://api.example.com:443', 'https://api.example.com:8443'],
				['http://api.example.com:443', 'https://example.com:443'],
			);
		});

		test('wildcard port with IPv6 localhost', () => {
			test_pattern(
				'http://[::1]:*',
				['http://[::1]', 'http://[::1]:3000', 'http://[::1]:8080', 'http://[::1]:65535'],
				['https://[::1]', 'http://[::1:3000', 'http://::1:3000'],
			);
		});

		test('wildcard port with full IPv6 address', () => {
			test_pattern(
				'https://[2001:db8::8a2e:370:7334]:*',
				[
					'https://[2001:db8::8a2e:370:7334]',
					'https://[2001:db8::8a2e:370:7334]:443',
					'https://[2001:db8::8a2e:370:7334]:8443',
				],
				['http://[2001:db8::8a2e:370:7334]:443', 'https://[2001:db8::8a2e:370:7335]:443'],
			);
		});
	});

	describe('combined wildcards', () => {
		test('wildcard subdomain and port', () => {
			test_pattern(
				'https://*.example.com:*',
				[
					'https://example.com',
					'https://sub.example.com',
					'https://sub.example.com:443',
					'https://deep.sub.example.com:8443',
				],
				['http://sub.example.com', 'https://example.org:443'],
			);
		});
	});

	describe('error handling', () => {
		test('throws on invalid pattern format', () => {
			expect(() => parse_allowed_origins('not-a-url')).toThrow('Invalid origin pattern');
			expect(() => parse_allowed_origins('ftp://example.com')).toThrow('Invalid origin pattern');
			expect(() => parse_allowed_origins('//example.com')).toThrow('Invalid origin pattern');
			expect(() => parse_allowed_origins('*.example.com')).toThrow('Invalid origin pattern');
			expect(() => parse_allowed_origins('example.com')).toThrow('Invalid origin pattern');
			expect(() => parse_allowed_origins('localhost:3000')).toThrow('Invalid origin pattern');
		});

		test('throws on wildcards in wrong positions', () => {
			expect(() => parse_allowed_origins('http://ex*ample.com')).toThrow(
				'Wildcard only allowed at start of hostname',
			);
			expect(() => parse_allowed_origins('http://example.*.com')).toThrow(
				'Wildcard only allowed at start of hostname',
			);
		});

		test('throws on invalid port wildcards', () => {
			expect(() => parse_allowed_origins('http://example.com:*000')).toThrow(
				'Invalid origin pattern',
			);
			expect(() => parse_allowed_origins('http://example.com:3*')).toThrow(
				'Invalid origin pattern',
			);
		});

		test('throws on wildcards in path', () => {
			expect(() => parse_allowed_origins('http://example.com/*')).toThrow(
				'Wildcards not allowed in path',
			);
			expect(() => parse_allowed_origins('http://example.com/api/*')).toThrow(
				'Wildcards not allowed in path',
			);
		});

		test('throws on wildcards in IPv6 addresses', () => {
			expect(() => parse_allowed_origins('http://[*::1]:3000')).toThrow(
				'Wildcards not allowed in IPv6 addresses',
			);
			expect(() => parse_allowed_origins('https://[2001:db8:*::1]')).toThrow(
				'Wildcards not allowed in IPv6 addresses',
			);
			expect(() => parse_allowed_origins('http://[::ffff:*.0.0.1]:8080')).toThrow(
				'Wildcards not allowed in IPv6 addresses',
			);
		});
	});

	describe('special cases', () => {
		test('handles special characters in domain names', () => {
			test_pattern(
				'https://ex-ample.com',
				['https://ex-ample.com'],
				['https://example.com', 'https://ex_ample.com'],
			);
		});

		test('handles numeric ports', () => {
			test_pattern(
				'http://localhost:8080',
				['http://localhost:8080'],
				['http://localhost:80', 'http://localhost:08080'],
			);
		});

		test('handles deep paths', () => {
			test_pattern(
				'https://api.example.com/v1/auth',
				['https://api.example.com/v1/auth'],
				['https://api.example.com/v1', 'https://api.example.com/v1/auth/login'],
			);
		});
	});
});

describe('verify_origin middleware', () => {
	const allowed_patterns = parse_allowed_origins(
		'http://localhost:3000,https://*.example.com,http://[::1]:3000,https://[2001:db8::1]:*',
	);
	const middleware = verify_origin(allowed_patterns);

	describe('sec-fetch-site header', () => {
		test('blocks cross-site requests immediately', async () => {
			await test_middleware_blocks(
				middleware,
				{
					'sec-fetch-site': 'cross-site',
					origin: 'http://localhost:3000',
				},
				'cross-site requests forbidden',
			);
		});

		test('allows same-origin requests', async () => {
			await test_middleware_allows(middleware, {
				'sec-fetch-site': 'same-origin',
				origin: 'http://localhost:3000',
			});
		});

		test('allows same-site requests', async () => {
			await test_middleware_allows(middleware, {
				'sec-fetch-site': 'same-site',
				origin: 'http://localhost:3000',
			});
		});
	});

	describe('origin header', () => {
		test('allows matching origins', async () => {
			await test_middleware_allows(middleware, {
				origin: 'http://localhost:3000',
			});
			await test_middleware_allows(middleware, {
				origin: 'https://sub.example.com',
			});
		});

		test('blocks non-matching origins', async () => {
			await test_middleware_blocks(
				middleware,
				{
					origin: 'http://evil.com',
				},
				'forbidden origin',
			);
		});

		test('allows IPv6 origins', async () => {
			await test_middleware_allows(middleware, {
				origin: 'http://[::1]:3000',
			});
			await test_middleware_allows(middleware, {
				origin: 'https://[2001:db8::1]',
			});
			await test_middleware_allows(middleware, {
				origin: 'https://[2001:db8::1]:8443',
			});
		});

		test('blocks non-matching IPv6 origins', async () => {
			await test_middleware_blocks(
				middleware,
				{
					origin: 'http://[::1]:8080',
				},
				'forbidden origin',
			);
			await test_middleware_blocks(
				middleware,
				{
					origin: 'https://[2001:db8::2]:443',
				},
				'forbidden origin',
			);
		});

		test('prioritizes origin over referer', async () => {
			await test_middleware_allows(middleware, {
				origin: 'http://localhost:3000',
				referer: 'http://evil.com/page',
			});
		});
	});

	describe('referer header', () => {
		test('allows matching referers when no origin', async () => {
			await test_middleware_allows(middleware, {
				referer: 'http://localhost:3000/some/page',
			});
		});

		test('blocks non-matching referers', async () => {
			await test_middleware_blocks(
				middleware,
				{
					referer: 'http://evil.com/page',
				},
				'forbidden referer',
			);
		});

		test('extracts origin from referer URL', async () => {
			await test_middleware_allows(middleware, {
				referer: 'https://api.example.com/deep/path?query=value#hash',
			});
		});

		test('allows IPv6 referers', async () => {
			await test_middleware_allows(middleware, {
				referer: 'http://[::1]:3000/some/page',
			});
			await test_middleware_allows(middleware, {
				referer: 'https://[2001:db8::1]:8443/api/endpoint',
			});
		});

		test('blocks non-matching IPv6 referers', async () => {
			await test_middleware_blocks(
				middleware,
				{
					referer: 'http://[::2]:3000/page',
				},
				'forbidden referer',
			);
		});

		test('blocks invalid referer URLs', async () => {
			await test_middleware_blocks(
				middleware,
				{
					referer: 'not-a-valid-url',
				},
				'invalid referer',
			);
		});
	});

	describe('direct access', () => {
		test('allows requests with no origin or referer', async () => {
			await test_middleware_allows(middleware, {});
		});

		test('allows requests with other headers but no origin/referer', async () => {
			await test_middleware_allows(middleware, {
				'user-agent': 'curl/7.64.1',
				accept: '*/*',
			});
		});
	});

	describe('empty allowed patterns', () => {
		const strict_middleware = verify_origin([]);

		test('blocks all origin requests', async () => {
			await test_middleware_blocks(
				strict_middleware,
				{
					origin: 'http://localhost:3000',
				},
				'forbidden origin',
			);
		});

		test('blocks all referer requests', async () => {
			await test_middleware_blocks(
				strict_middleware,
				{
					referer: 'http://localhost:3000/page',
				},
				'forbidden referer',
			);
		});

		test('still allows direct access', async () => {
			await test_middleware_allows(strict_middleware, {});
		});
	});

	describe('case sensitivity', () => {
		test('headers are case-insensitive', async () => {
			await test_middleware_allows(middleware, {
				Origin: 'http://localhost:3000',
			});
			await test_middleware_allows(middleware, {
				ORIGIN: 'http://localhost:3000',
			});
			await test_middleware_blocks(
				middleware,
				{
					'Sec-Fetch-Site': 'cross-site',
				},
				'cross-site requests forbidden',
			);
		});

		test('origin values are case-sensitive', async () => {
			await test_middleware_blocks(
				middleware,
				{
					origin: 'HTTP://LOCALHOST:3000',
				},
				'forbidden origin',
			);
		});
	});
});

describe('integration scenarios', () => {
	test('typical development setup', () => {
		const dev_patterns = parse_allowed_origins(
			'http://localhost:3000,http://localhost:5173,http://127.0.0.1:*,http://[::1]:*',
		);
		// Common dev server origins including IPv6
		const dev_origins = [
			'http://localhost:3000',
			'http://localhost:5173',
			'http://127.0.0.1:3000',
			'http://127.0.0.1:8080',
			'http://[::1]:3000',
			'http://[::1]:5173',
			'http://[::1]:8080',
		];

		for (const origin of dev_origins) {
			expect(should_allow_origin(origin, dev_patterns)).toBe(true);
		}
	});

	test('production multi-domain setup', () => {
		const prod_patterns = parse_allowed_origins(
			'https://app.example.com,https://*.example.com,https://partner.com',
		);

		const allowed = [
			'https://app.example.com',
			'https://api.example.com',
			'https://staging.example.com',
			'https://example.com',
			'https://partner.com',
		];

		const blocked = [
			'http://app.example.com', // Wrong protocol
			'https://example.org', // Wrong domain
			'https://sub.partner.com', // No wildcard for partner
		];

		for (const origin of allowed) {
			expect(should_allow_origin(origin, prod_patterns)).toBe(true);
		}

		for (const origin of blocked) {
			expect(should_allow_origin(origin, prod_patterns)).toBe(false);
		}
	});

	test('complex enterprise setup', () => {
		test_pattern(
			'https://*.corp.example.com:*,https://app.example.com,https://localhost:*',
			[
				'https://dev.corp.example.com',
				'https://staging.corp.example.com:8443',
				'https://app.example.com',
				'https://localhost:3000',
				'https://localhost',
			],
			[
				'http://dev.corp.example.com',
				'https://corp.example.org',
				'https://app.example.com:443',
				'http://localhost:3000',
			],
		);
	});
});

describe('edge cases', () => {
	test('handles IPv6 addresses', () => {
		// IPv6 addresses in brackets are now supported
		const patterns = parse_allowed_origins(
			'http://[::1]:3000,https://[2001:db8::1],http://[fe80::1%lo0]:8080',
		);
		expect(patterns).toHaveLength(3);

		// Test various IPv6 formats
		expect(should_allow_origin('http://[::1]:3000', patterns)).toBe(true);
		expect(should_allow_origin('https://[2001:db8::1]', patterns)).toBe(true);
		expect(should_allow_origin('http://[fe80::1%lo0]:8080', patterns)).toBe(true);

		// Should not match without brackets
		expect(should_allow_origin('http://::1:3000', patterns)).toBe(false);
	});

	test('handles various IPv6 formats', () => {
		// Test compressed zeros
		test_pattern(
			'https://[2001:db8::8a2e:370:7334]',
			['https://[2001:db8::8a2e:370:7334]'],
			['https://[2001:db8:0:0:8a2e:370:7334]'], // Different representation should not match
		);

		// Test zone identifiers
		test_pattern(
			'http://[fe80::1%eth0]:8080',
			['http://[fe80::1%eth0]:8080'],
			['http://[fe80::1]:8080', 'http://[fe80::1%eth1]:8080'],
		);

		// Test mixed case (IPv6 is case-insensitive but our exact match might not be)
		const mixedCasePatterns = parse_allowed_origins('http://[2001:DB8::1]:3000');
		expect(should_allow_origin('http://[2001:db8::1]:3000', mixedCasePatterns)).toBe(false); // Case sensitive match
		expect(should_allow_origin('http://[2001:DB8::1]:3000', mixedCasePatterns)).toBe(true);
	});

	test('handles IPv6 edge cases', () => {
		// Loopback variations
		test_pattern(
			'http://[::1]',
			['http://[::1]'],
			['http://[0:0:0:0:0:0:0:1]', 'http://[::0:1]'], // Different representations
		);

		// IPv4-mapped with wildcard port
		test_pattern(
			'http://[::ffff:127.0.0.1]:*',
			[
				'http://[::ffff:127.0.0.1]',
				'http://[::ffff:127.0.0.1]:3000',
				'http://[::ffff:127.0.0.1]:8080',
			],
			['http://[::ffff:127.0.0.2]:3000', 'https://[::ffff:127.0.0.1]:3000'],
		);

		// Very long valid IPv6 address
		test_pattern(
			'https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:443',
			['https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]:443'],
			['https://[2001:0db8:85a3:0000:0000:8a2e:0370:7334]'],
		);
	});

	test('handles unusual but valid ports', () => {
		test_pattern(
			'http://example.com:65535',
			['http://example.com:65535'],
			['http://example.com:65536', 'http://example.com'],
		);
	});

	test('handles empty path correctly', () => {
		const patterns = parse_allowed_origins('http://example.com');
		expect(should_allow_origin('http://example.com', patterns)).toBe(true);
		expect(should_allow_origin('http://example.com/', patterns)).toBe(false);
	});

	test('handles trailing slashes in patterns', () => {
		test_pattern(
			'http://example.com/',
			['http://example.com/'],
			['http://example.com', 'http://example.com/path'],
		);
	});

	test('handles very long origin strings', () => {
		const long_subdomain = 'a'.repeat(63) + '.example.com';
		const patterns = parse_allowed_origins(`https://*.example.com`);
		expect(should_allow_origin(`https://${long_subdomain}`, patterns)).toBe(true);
	});

	test('handles special regex characters in fixed parts', () => {
		test_pattern(
			'https://example.com/path(with)special[chars]',
			['https://example.com/path(with)special[chars]'],
			['https://example.com/pathwithspecialchars'],
		);
	});
});

/**
 * Common localhost patterns including IPv4 and IPv6
 */
const LOCALHOST_PATTERNS = [
	'http://localhost:*',
	'https://localhost:*',
	'http://127.0.0.1:*',
	'https://127.0.0.1:*',
	'http://[::1]:*',
	'https://[::1]:*',
	'http://[::ffff:127.0.0.1]:*', // IPv4-mapped IPv6
	'https://[::ffff:127.0.0.1]:*',
];

describe('LOCALHOST_PATTERNS', () => {
	test('includes all common localhost variants', () => {
		expect(LOCALHOST_PATTERNS).toEqual([
			'http://localhost:*',
			'https://localhost:*',
			'http://127.0.0.1:*',
			'https://127.0.0.1:*',
			'http://[::1]:*',
			'https://[::1]:*',
			'http://[::ffff:127.0.0.1]:*',
			'https://[::ffff:127.0.0.1]:*',
		]);
	});

	test('LOCALHOST_PATTERNS work correctly when parsed', () => {
		const patterns = parse_allowed_origins(LOCALHOST_PATTERNS.join(','));

		// Test various localhost origins
		const localhostOrigins = [
			'http://localhost:3000',
			'https://localhost:443',
			'http://127.0.0.1:8080',
			'https://127.0.0.1:8443',
			'http://[::1]:3000',
			'https://[::1]:443',
			'http://[::ffff:127.0.0.1]:3000',
			'https://[::ffff:127.0.0.1]:8443',
		];

		for (const origin of localhostOrigins) {
			expect(should_allow_origin(origin, patterns)).toBe(true);
		}

		// Test non-localhost origins should not match
		const nonLocalhostOrigins = [
			'http://example.com:3000',
			'https://192.168.1.1:8080',
			'http://[2001:db8::1]:3000',
		];

		for (const origin of nonLocalhostOrigins) {
			expect(should_allow_origin(origin, patterns)).toBe(false);
		}
	});
});
