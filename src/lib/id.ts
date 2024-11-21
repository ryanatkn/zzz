import type {Flavored} from '@ryanatkn/belt/types.js';

export type Id = Flavored<number, 'Id'>;

// TODO quick and dirty
export const random_id = (): Id => {
	let v = parseInt(Math.random().toString().substring(2), 10);
	while (!Number.isSafeInteger(v)) {
		v = Math.floor(v / 2);
	}
	return v;
};
