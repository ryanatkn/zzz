export const reorder_list = (bits: Array<any>, from_index: number, to_index: number): void => {
	if (from_index === to_index) return;
	if (from_index < 0 || to_index < 0 || from_index >= bits.length || to_index >= bits.length) {
		throw Error('index out of bounds');
	}
	const [moved] = bits.splice(from_index, 1);
	bits.splice(to_index, 0, moved);
};
