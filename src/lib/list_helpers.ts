export const reorder_list = (from_index: number, to_index: number, fragments: Array<any>): void => {
	if (from_index === to_index) return;
	if (
		from_index < 0 ||
		to_index < 0 ||
		from_index >= fragments.length ||
		to_index >= fragments.length
	) {
		throw Error('index out of bounds');
	}
	const [moved] = fragments.splice(from_index, 1);
	fragments.splice(to_index, 0, moved);
};
