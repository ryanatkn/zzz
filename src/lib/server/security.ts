import {SERVER_URL} from '$lib/constants.js';

export const should_allow_origin = (origin: string | null | undefined): boolean => {
	console.log(`[should_allow_origin] origin`, origin);
	if (!origin) return false;
	if (origin === SERVER_URL) {
		return true; // TODO needs better config
	}
	return false;
};
