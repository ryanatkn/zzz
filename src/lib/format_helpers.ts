/**
 * Format bytes to human readable string.
 */
export const format_bytes = (bytes: number, decimals = 1): string => {
	if (bytes === 0) return '0 Bytes';

	const k = 1024;
	const dm = decimals < 0 ? 0 : decimals;
	const sizes = ['bytes', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];

	const i = Math.floor(Math.log(bytes) / Math.log(k));

	return parseFloat((bytes / k ** i).toFixed(dm)) + ' ' + sizes[i];
};

// TODO should this value be fixed upstream to always be bytes? are we transforming values?
export const format_gigabytes = (gb: number): string =>
	gb < 1 ? `${Math.round(gb * 1024)} MB` : `${gb.toFixed(1)} GB`;

/**
 * Format a number as a percentage.
 */
export const format_percentage = (value: number, total: number, decimals = 1): string => {
	if (total === 0) return '0%';
	return ((value / total) * 100).toFixed(decimals) + '%';
};

/**
 * Format duration in milliseconds to human readable string.
 */
export const format_duration = (ms: number): string => {
	if (ms < 1000) return `${ms}ms`;
	if (ms < 60000) return `${(ms / 1000).toFixed(1)}s`;
	if (ms < 3600000) return `${(ms / 60000).toFixed(1)}m`;
	return `${(ms / 3600000).toFixed(1)}h`;
};
