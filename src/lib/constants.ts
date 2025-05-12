import {
	PUBLIC_SERVER_HOSTNAME,
	PUBLIC_SERVER_PORT,
	PUBLIC_SERVER_PROTOCOL,
	PUBLIC_SERVER_PROXIED_PORT,
	PUBLIC_SERVER_API_PATH,
	PUBLIC_WEBSOCKET_URL,
} from '$env/static/public';
import {ensure_start, strip_end} from '@ryanatkn/belt/string.js';

// TODO a lot of these need to be moved to env or config etc

export const SERVER_PROXIED_PORT = parseInt(PUBLIC_SERVER_PROXIED_PORT, 10) || 8999;

/**
 * @absolute
 * @no_trailing_slash
 */
export const SERVER_URL = `${PUBLIC_SERVER_PROTOCOL}://${PUBLIC_SERVER_HOSTNAME}:${PUBLIC_SERVER_PORT}`;

export const ZZZ_DIRNAME = '.zzz';

export const CONTENT_PREVIEW_LENGTH = 100;

/** @leading_slash */
export const API_PATH =
	(PUBLIC_SERVER_API_PATH && ensure_start(PUBLIC_SERVER_API_PATH, '/')) || '/api';

/**
 * @absolute
 * @no_trailing_slash
 */
export const API_URL = SERVER_URL + API_PATH;

/**
 * @absolute
 * @no_trailing_slash
 * */
export const WEBSOCKET_URL = PUBLIC_WEBSOCKET_URL && strip_end(PUBLIC_WEBSOCKET_URL, '/'); // 'ws://localhost:8999/ws'
