import {
	PUBLIC_SERVER_HOST,
	PUBLIC_SERVER_PORT,
	PUBLIC_SERVER_PROTOCOL,
	PUBLIC_SERVER_PROXIED_PORT,
	PUBLIC_SERVER_API_PATH,
	PUBLIC_WEBSOCKET_URL,
	PUBLIC_ZZZ_DIR,
} from '$env/static/public';

import {
	Path_With_Leading_Slash,
	Path_With_Trailing_Slash,
	Path_Without_Trailing_Slash,
} from '$lib/zod_helpers.js';

// This module re-exports public environment variables with parsed values.
// It should generally be preferred to using the variables directly.

// TODO a lot of these need to be moved to env or config etc
// and maybe some need to be derived (in some/all cases)

// TODO better validation

export const SERVER_PROXIED_PORT = parseInt(PUBLIC_SERVER_PROXIED_PORT, 10) || 8999;

export const SERVER_PROTOCOL = PUBLIC_SERVER_PROTOCOL || 'http';

export const SERVER_HOST = PUBLIC_SERVER_HOST || 'localhost';

/**
 * @with_protocol
 * @no_trailing_slash
 */
export const SERVER_URL = `${SERVER_PROTOCOL}://${SERVER_HOST}:${PUBLIC_SERVER_PORT}`;

/**
 * @relative
 * @no_trailing_slash
 */
export const ZZZ_CACHE_DIRNAME = '.zzz';

/**
 * @leading_slash
 * @trailing_slash
 */
export const ZZZ_DIR = Path_With_Trailing_Slash.parse(PUBLIC_ZZZ_DIR);

export const CONTENT_PREVIEW_LENGTH = 100;

/**
 * @leading_slash
 * @no_trailing_slash
 */
export const API_PATH =
	(PUBLIC_SERVER_API_PATH &&
		Path_Without_Trailing_Slash.parse(Path_With_Leading_Slash.parse(PUBLIC_SERVER_API_PATH))) ||
	'/api';

/**
 * @with_protocol
 * @no_trailing_slash
 */
export const API_URL = SERVER_URL + API_PATH;

/**
 * @leading_slash
 * @no_trailing_slash
 */
export const API_PATH_FOR_HTTP_RPC = API_PATH + '/rpc';

/**
 * @with_protocol
 * @no_trailing_slash
 */
export const API_URL_FOR_HTTP_RPC = SERVER_URL + API_PATH_FOR_HTTP_RPC;

// TODO for production does this need to use the host? compute from the other env variables?
/**
 * @with_protocol
 * @no_trailing_slash
 * */
export const WEBSOCKET_URL = PUBLIC_WEBSOCKET_URL
	? Path_Without_Trailing_Slash.parse(PUBLIC_WEBSOCKET_URL)
	: 'ws://localhost:8999/ws';

export const WEBSOCKET_URL_OBJECT: URL | null = WEBSOCKET_URL ? new URL(WEBSOCKET_URL) : null;

/**
 * @leading_slash
 * @no_trailing_slash
 */
export const WEBSOCKET_PATH = WEBSOCKET_URL_OBJECT?.pathname;

export const UNKNOWN_ERROR_MESSAGE = 'unknown error'; // TODO move
