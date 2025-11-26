import type {Library} from '@ryanatkn/fuz/library.svelte.js';
import {create_context} from '@ryanatkn/fuz/context_helpers.js';

export const library_context = create_context<Library>();
