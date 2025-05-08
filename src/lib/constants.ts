import {
	PUBLIC_SERVER_HOSTNAME,
	PUBLIC_SERVER_PORT,
	PUBLIC_SERVER_PROTOCOL,
	PUBLIC_SERVER_PROXIED_PORT,
	PUBLIC_SERVER_API_PATH,
} from '$env/static/public';
import {ensure_start} from '@ryanatkn/belt/string.js';

// TODO a lot of these need to be moved to env or config etc

export const SERVER_PROXIED_PORT = parseInt(PUBLIC_SERVER_PROXIED_PORT, 10) || 8999;

export const SERVER_URL = `${PUBLIC_SERVER_PROTOCOL}://${PUBLIC_SERVER_HOSTNAME}:${PUBLIC_SERVER_PORT}`;

export const ZZZ_DIRNAME = '.zzz';

/** Milliseconds before considering an http request failed */
export const REQUEST_TIMEOUT = 10_000;

export const CONTENT_PREVIEW_LENGTH = 100;

/** @leading_slash */
export const API_ROUTE =
	(PUBLIC_SERVER_API_PATH && ensure_start(PUBLIC_SERVER_API_PATH, '/')) || '/api';
