import {DEV} from 'esm-env';

import type {Filer_Change_Handler, Backend} from '$lib/server/backend.js';
import type {Action_Inputs} from '$lib/action_collections.js';
import {create_action_event} from '$lib/action_event.js';
import {filer_change_action_spec} from '$lib/action_specs.js';
import {
	map_watcher_change_to_diskfile_change,
	to_serializable_source_file,
} from '$lib/diskfile_helpers.js';
import {Diskfile_Path, Serializable_Source_File} from '$lib/diskfile_types.js';

// TODO @api think about unification between frontend|backend_actions_api.ts
// this is all a hacky WIP,
// thinking about a symmetric API for the frontend/backend
// without blowing the budgets for complexity and performance,
// think about unification with frontend_actions_api.ts and see it for better patterns

export interface Backend_Actions_Api {
	filer_change: (input: Action_Inputs['filer_change']) => Promise<void>;
}

export const create_backend_actions_api = (backend: Backend): Backend_Actions_Api => {
	return {
		filer_change: async (input: Action_Inputs['filer_change']) => {
			// TODO @api think about symmetry and generic handling, see how the frontend actions does it
			try {
				const event = create_action_event(backend, filer_change_action_spec, input, 'send');

				await event.parse().handle_async();

				if (event.data.step === 'handled' && event.data.notification) {
					// Send notification to all clients via the WebSocket transport
					await backend.peer.send(event.data.notification);
				} else if (event.data.step === 'failed') {
					console.error('Failed to create filer_change notification:', event.data.error);
				}
			} catch (error) {
				// TODO implement proper error handling strategy (don't throw - notifications are fire-and-forget)
				console.error('Unexpected error in filer_change:', error);
			}
		},
	};
};

// TODO where does this belong? it calls into the `Backend_Actions_Api`
/**
 * Handle file system changes and notify clients.
 */
export const handle_filer_change: Filer_Change_Handler = (
	change,
	source_file,
	backend,
	dir,
): void => {
	const api_change = {
		type: map_watcher_change_to_diskfile_change(change.type),
		path: Diskfile_Path.parse(change.path),
	};
	const serializable_source_file = to_serializable_source_file(source_file, dir);

	// In development mode, validate strictly and fail loudly.
	// This is less of a need in production because we control both sides,
	// but maybe it should be optional or even required.
	if (DEV) {
		Serializable_Source_File.parse(serializable_source_file);

		// TODO can this be moved to the schema?
		if (!serializable_source_file.id.startsWith(serializable_source_file.source_dir)) {
			throw new Error(
				`Source file ${serializable_source_file.id} does not start with source dir ${serializable_source_file.source_dir}`,
			);
		}
	}

	console.log(`change, source_file.id`, change, source_file.id);

	void backend.api.filer_change({
		change: api_change,
		source_file: serializable_source_file,
	});
};
