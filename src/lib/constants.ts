import {
	PUBLIC_SERVER_HOSTNAME,
	PUBLIC_SERVER_PORT,
	PUBLIC_SERVER_PROTOCOL,
	PUBLIC_SERVER_PROXIED_PORT,
} from '$env/static/public';

export const SERVER_PROXIED_PORT = parseInt(PUBLIC_SERVER_PROXIED_PORT, 10) || 8999;

export const SERVER_URL = `${PUBLIC_SERVER_PROTOCOL}://${PUBLIC_SERVER_HOSTNAME}:${PUBLIC_SERVER_PORT}`;

export const ZZZ_DIRNAME = '.zzz';

/** Milliseconds before considering an http request failed */
export const REQUEST_TIMEOUT = 10_000;

export const CONTENT_PREVIEW_LENGTH = 100;
