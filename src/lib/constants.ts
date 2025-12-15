import {
	PUBLIC_SERVER_HOST,
	PUBLIC_SERVER_PORT,
	PUBLIC_SERVER_PROTOCOL,
	PUBLIC_SERVER_PROXIED_PORT,
	PUBLIC_BACKEND_ARTIFICIAL_RESPONSE_DELAY,
	PUBLIC_SERVER_API_PATH,
	PUBLIC_WEBSOCKET_URL,
	PUBLIC_ZZZ_DIR,
} from '$env/static/public';

import {
	PathWithLeadingSlash,
	PathWithTrailingSlash,
	PathWithoutTrailingSlash,
} from './zod_helpers.js';

// This module re-exports public environment variables with parsed values.
// It should generally be preferred to using the variables directly.

// TODO a lot of these need to be moved to env or config etc
// and maybe some need to be derived (in some/all cases)

// TODO better validation

// TODO maybe remove the SERVER_ prefixes

export const SERVER_PROTOCOL: string = PUBLIC_SERVER_PROTOCOL || 'http';

export const SERVER_HOST: string = PUBLIC_SERVER_HOST || 'localhost';

/**
 * @with_protocol
 * @no_trailing_slash
 */
export const SERVER_URL: string = `${SERVER_PROTOCOL}://${SERVER_HOST}:${PUBLIC_SERVER_PORT}`;

export const SERVER_PROXIED_PORT: number = parseInt(PUBLIC_SERVER_PROXIED_PORT, 10) || 8999;

export const BACKEND_ARTIFICIAL_RESPONSE_DELAY =
	parseInt(PUBLIC_BACKEND_ARTIFICIAL_RESPONSE_DELAY, 10) || 0;

/**
 * @trailing_slash
 */
export const ZZZ_DIR = PathWithTrailingSlash.parse(PUBLIC_ZZZ_DIR || '.zzz');

export const CONTENT_PREVIEW_LENGTH = 100;

/**
 * @leading_slash
 * @no_trailing_slash
 */
export const API_PATH: string =
	(PUBLIC_SERVER_API_PATH &&
		PathWithoutTrailingSlash.parse(PathWithLeadingSlash.parse(PUBLIC_SERVER_API_PATH))) ||
	'/api';

/**
 * @with_protocol
 * @no_trailing_slash
 */
export const API_URL: string = SERVER_URL + API_PATH;

/**
 * @leading_slash
 * @no_trailing_slash
 */
export const API_PATH_FOR_HTTP_RPC: string = API_PATH + '/rpc';

/**
 * @with_protocol
 * @no_trailing_slash
 */
export const API_URL_FOR_HTTP_RPC: string = SERVER_URL + API_PATH_FOR_HTTP_RPC;

// TODO for production does this need to use the host? compute from the other env variables?
/**
 * @with_protocol
 * @no_trailing_slash
 * */
export const WEBSOCKET_URL: string = PUBLIC_WEBSOCKET_URL
	? PathWithoutTrailingSlash.parse(PUBLIC_WEBSOCKET_URL)
	: 'ws://localhost:8999/ws';

export const WEBSOCKET_URL_OBJECT: URL | null = WEBSOCKET_URL ? new URL(WEBSOCKET_URL) : null;

/**
 * @leading_slash
 * @no_trailing_slash
 */
export const WEBSOCKET_PATH: string | undefined = WEBSOCKET_URL_OBJECT?.pathname;

export const UNKNOWN_ERROR_MESSAGE: string = 'unknown error'; // TODO move/configure
