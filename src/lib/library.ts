import type {Library} from '@fuzdev/fuz_ui/library.svelte.js';
import {create_context} from '@fuzdev/fuz_ui/context_helpers.js';

export const library_context = create_context<Library>();
