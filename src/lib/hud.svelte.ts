import {create_context} from '@ryanatkn/fuz/context_helpers.js';
import type {Snippet} from 'svelte';

export const hud_context = create_context<Snippet | undefined>();
