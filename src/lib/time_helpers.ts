import {format} from 'date-fns';

export const format_timestamp = (timestamp: number | null): string =>
	timestamp ? format(timestamp, 'h:mm a') : '-';

// TODO replace with `date-fns`?
export const format_ms_to_readable = (ms: number, decimals = 0): string => {
	if (ms < 1000) return `${ms}ms`;
	return `${(ms / 1000).toFixed(decimals)} seconds`;
};
