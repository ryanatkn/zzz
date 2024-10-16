import type {Flavored} from '@ryanatkn/belt/types.js';

export type Id = Flavored<number, 'Id'>;

// TODO faster? use crypto for randomization?
export const random_id = (): Id => {
	let v = parseInt(Math.random().toString().substring(2), 10);
	while (v > Number.MAX_SAFE_INTEGER) {
		v = Math.floor(v / 2);
	}
	return v;
};
