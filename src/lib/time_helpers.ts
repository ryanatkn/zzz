import {format} from 'date-fns';

import {FILE_DATETIME_FORMAT, FILE_SHORT_DATE_FORMAT, FILE_TIME_FORMAT} from '$lib/cell_helpers.js';

export type Time_Value = string | number | Date;

// TODO rethink these names and the design

export const format_timestamp = (value: Time_Value | null | undefined, fallback = ''): string =>
	!value ? fallback : format(value, 'h:mm a');

export const format_short_date = (value: Time_Value | null | undefined, fallback = ''): string =>
	!value ? fallback : format(value, FILE_SHORT_DATE_FORMAT);

export const format_datetime = (value: Time_Value | null | undefined, fallback = ''): string =>
	!value ? fallback : format(value, FILE_DATETIME_FORMAT);

export const format_time = (value: Time_Value | null | undefined, fallback = ''): string =>
	!value ? fallback : format(value, FILE_TIME_FORMAT);

// TODO replace with `date-fns`?
export const format_ms_to_readable = (ms: number, decimals = 0): string => {
	if (ms < 1000) return `${ms}ms`;
	return `${(ms / 1000).toFixed(decimals)} seconds`;
};
