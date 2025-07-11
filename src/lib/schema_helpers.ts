// TODO not used any more, delete if not needed (is hacky but maybe useful)

/**
 * Convert a string from camelCase to snake_case.
 */
export const camel_to_snake_case = (str: string): string => {
	return str
		.replace(/([a-z0-9])([A-Z])/g, '$1_$2') // Replace camelCase boundaries with underscores
		.toLowerCase();
};

/**
 * Convert each segment of a snake_case identifier to Pascalsnake case,
 * e.g., "create_directory" -> "Create_Directory".
 */
export const to_pascalsnake_case = (str: string, from_camel = false): string => {
	let result = str;
	if (from_camel) {
		result = camel_to_snake_case(str);
	}
	return result
		.split('_')
		.map((s) => s.charAt(0).toUpperCase() + s.slice(1))
		.join('_');
};
