import {
	PUBLIC_SERVER_HOSTNAME,
	PUBLIC_SERVER_PORT,
	PUBLIC_SERVER_PROTOCOL,
	PUBLIC_SERVER_PROXIED_PORT,
	PUBLIC_SERVER_API_PATH,
	PUBLIC_WEBSOCKET_URL,
} from '$env/static/public';

import {Path_With_Leading_Slash, Path_Without_Trailing_Slash} from '$lib/zod_helpers.js';

// TODO a lot of these need to be moved to env or config etc

// TODO better validation

export const SERVER_PROXIED_PORT = parseInt(PUBLIC_SERVER_PROXIED_PORT, 10) || 8999;

/**
 * @with_protocol
 * @no_trailing_slash
 */
export const SERVER_URL = `${PUBLIC_SERVER_PROTOCOL}://${PUBLIC_SERVER_HOSTNAME}:${PUBLIC_SERVER_PORT}`;

export const ZZZ_DIRNAME = '.zzz';

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

/**
 * @with_protocol
 * @no_trailing_slash
 * */
export const WEBSOCKET_URL =
	PUBLIC_WEBSOCKET_URL && Path_Without_Trailing_Slash.parse(PUBLIC_WEBSOCKET_URL); // 'ws://localhost:8999/ws'

export const WEBSOCKET_URL_OBJECT = WEBSOCKET_URL ? new URL(WEBSOCKET_URL) : undefined;

/**
 * @leading_slash
 * @no_trailing_slash
 */
export const WEBSOCKET_PATH = WEBSOCKET_URL_OBJECT?.pathname;
