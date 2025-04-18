import {create_context} from '@ryanatkn/fuz/context_helpers.js';

import {Zzz} from '$lib/zzz.svelte.js';

// TODO use this instead of `zzz_context` in non-core usages
export const app_context = create_context<App>();

export class App extends Zzz {
	// TODO extensibility - `App` is a user-implemented class,
	// a lot of currently-hardcoded behaviors should be configurable
}
