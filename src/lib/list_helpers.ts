export const reorder_list = (items: Array<any>, from_index: number, to_index: number): void => {
	if (from_index === to_index) return;

	// Validate indices
	if (from_index < 0 || to_index < 0 || from_index >= items.length || to_index > items.length) {
		console.error(
			`Invalid indices: from ${from_index} to ${to_index} in array of length ${items.length}`,
		);
		return; // Better to return than throw here
	}

	// Perform the reorder
	const [moved] = items.splice(from_index, 1);
	items.splice(to_index, 0, moved);
};
