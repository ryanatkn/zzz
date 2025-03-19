export const get_unique_name = (
	name: string,
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
