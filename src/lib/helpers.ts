import {CONTENT_PREVIEW_LENGTH} from '$lib/constants.js';

export const get_unique_name = (
	name: string,
	// TODO BLOCK change to a callback fn, `is_valid`?
	existing_names: Array<string> | Set<string> | Map<string, any>,
): string => {
	const t = 'has' in existing_names ? 'has' : 'includes';
	let result = name;
	let i = 2;
	while ((existing_names as any)[t](result)) {
		result = `${name} ${i++}`;
	}
	return result;
};

export const defined = <T>(value: T | undefined): T => {
	if (value === undefined) {
		throw new Error('Value must be defined');
	}
	return value;
};

export const to_preview = (
	content: string | null | undefined,
	max_length: number = CONTENT_PREVIEW_LENGTH,
): string =>
	content ? (content.length > max_length ? content.substring(0, max_length) + '...' : content) : '';
