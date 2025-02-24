export const get_unique_name = (name: string, existing_names: Array<string>): string => {
	let result = name;
	let i = 2;
	while (existing_names.includes(result)) {
		result = `${name} ${i++}`;
	}
	return result;
};
