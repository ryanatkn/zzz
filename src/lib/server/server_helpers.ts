import type {Handler} from 'hono';

export const noop_middleware: Handler = (_, next) => next();
