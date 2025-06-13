import {test, expect, describe} from 'vitest';

import {
	Import_Builder,
	get_executor_phases,
	get_action_event_type,
	get_handler_return_type,
	generate_phase_handlers,
	create_banner,
} from '$lib/codegen.js';
import type {Action_Spec} from '$lib/action_spec.js';

describe('Import_Builder', () => {
	describe('type-only imports', () => {
		test('single module with type imports becomes import type', () => {
			const imports = new Import_Builder();

			imports.add_type('$lib/types.js', 'Foo');
			imports.add_type('$lib/types.js', 'Bar');

			expect(imports.build()).toBe(`import type {Bar, Foo} from '$lib/types.js';`);
		});

		test('add_types helper adds multiple types at once', () => {
			const imports = new Import_Builder();

			imports.add_types('$lib/types.js', 'Type_A', 'Type_B', 'Type_C');

			expect(imports.build()).toBe(`import type {Type_A, Type_B, Type_C} from '$lib/types.js';`);
		});

		test('empty imports returns empty string', () => {
			const imports = new Import_Builder();

			expect(imports.build()).toBe('');
			expect(imports.has_imports()).toBe(false);
			expect(imports.import_count).toBe(0);
		});
	});

	describe('mixed imports', () => {
		test('mixed types and values use individual type annotations', () => {
			const imports = new Import_Builder();

			imports.add('$lib/utils.js', 'helper');
			imports.add_type('$lib/utils.js', 'Helper_Type');
			imports.add('$lib/utils.js', 'another_helper');

			expect(imports.build()).toBe(
				`import {another_helper, helper, type Helper_Type} from '$lib/utils.js';`,
			);
		});

		test('value import prevents module from being type-only', () => {
			const imports = new Import_Builder();

			imports.add_type('$lib/mixed.js', 'Type_A');
			imports.add_type('$lib/mixed.js', 'Type_B');
			imports.add('$lib/mixed.js', 'value'); // This makes it mixed
			imports.add_type('$lib/mixed.js', 'Type_C');

			expect(imports.build()).toBe(
				`import {value, type Type_A, type Type_B, type Type_C} from '$lib/mixed.js';`,
			);
		});

		test('multiple values and types are sorted correctly', () => {
			const imports = new Import_Builder();

			// Add in random order
			imports.add_type('$lib/mixed.js', 'Z_Type');
			imports.add('$lib/mixed.js', 'z_value');
			imports.add_type('$lib/mixed.js', 'A_Type');
			imports.add('$lib/mixed.js', 'a_value');
			imports.add_type('$lib/mixed.js', 'M_Type');
			imports.add('$lib/mixed.js', 'm_value');

			// Should sort values first (alphabetically), then types (alphabetically)
			expect(imports.build()).toBe(
				`import {a_value, m_value, z_value, type A_Type, type M_Type, type Z_Type} from '$lib/mixed.js';`,
			);
		});
	});

	describe('import precedence', () => {
		test('value import takes precedence over type import', () => {
			const imports = new Import_Builder();

			imports.add_type('$lib/utils.js', 'Item');
			imports.add('$lib/utils.js', 'Item'); // Upgrades to value

			expect(imports.build()).toBe(`import {Item} from '$lib/utils.js';`);
		});

		test('type import does not downgrade existing value import', () => {
			const imports = new Import_Builder();

			imports.add('$lib/utils.js', 'Item');
			imports.add_type('$lib/utils.js', 'Item'); // Should not downgrade

			expect(imports.build()).toBe(`import {Item} from '$lib/utils.js';`);
		});

		test('duplicate imports are deduplicated', () => {
			const imports = new Import_Builder();

			imports.add_type('$lib/types.js', 'Foo');
			imports.add_type('$lib/types.js', 'Foo');
			imports.add_type('$lib/types.js', 'Foo');

			expect(imports.build()).toBe(`import type {Foo} from '$lib/types.js';`);
		});
	});

	describe('multiple modules', () => {
		test('generates separate import statements per module', () => {
			const imports = new Import_Builder();

			imports.add_types('$lib/types.js', 'Type_A', 'Type_B');
			imports.add('$lib/utils.js', 'util');
			imports.add_types('$lib/schemas.js', 'Schema_A', 'Schema_B');

			const result = imports.build();
			const lines = result.split('\n');

			expect(lines).toHaveLength(3);
			expect(lines).toContain(`import type {Type_A, Type_B} from '$lib/types.js';`);
			expect(lines).toContain(`import {util} from '$lib/utils.js';`);
			expect(lines).toContain(`import type {Schema_A, Schema_B} from '$lib/schemas.js';`);
		});

		test('imports are sorted alphabetically within modules', () => {
			const imports = new Import_Builder();

			imports.add_type('$lib/types.js', 'Zebra');
			imports.add_type('$lib/types.js', 'Apple');
			imports.add_type('$lib/types.js', 'Middle');

			expect(imports.build()).toBe(`import type {Apple, Middle, Zebra} from '$lib/types.js';`);
		});

		test('handles imports with underscores and numbers correctly', () => {
			const imports = new Import_Builder();

			imports.add_type('$lib/types.js', '_Private_Type');
			imports.add_type('$lib/types.js', 'Type_1');
			imports.add_type('$lib/types.js', 'Type_2');
			imports.add_type('$lib/types.js', 'PUBLIC_TYPE');

			// Underscores sort before letters in most locales
			expect(imports.build()).toBe(
				`import type {PUBLIC_TYPE, Type_1, Type_2, _Private_Type} from '$lib/types.js';`,
			);
		});

		test('maintains module order based on first addition', () => {
			const imports = new Import_Builder();

			// Add in specific order
			imports.add_type('$lib/third.js', 'Type3');
			imports.add_type('$lib/first.js', 'Type1');
			imports.add_type('$lib/second.js', 'Type2');

			// Then add more to existing modules
			imports.add_type('$lib/first.js', 'Type1b');
			imports.add_type('$lib/third.js', 'Type3b');

			const lines = imports.preview();

			// Module order should be based on insertion order
			expect(lines[0]).toContain('$lib/third.js');
			expect(lines[1]).toContain('$lib/first.js');
			expect(lines[2]).toContain('$lib/second.js');

			// But items within modules are sorted
			expect(lines[0]).toBe(`import type {Type3, Type3b} from '$lib/third.js';`);
			expect(lines[1]).toBe(`import type {Type1, Type1b} from '$lib/first.js';`);
		});
	});

	describe('utility methods', () => {
		test('has_imports returns correct state', () => {
			const imports = new Import_Builder();

			expect(imports.has_imports()).toBe(false);

			imports.add_type('$lib/types.js', 'Foo');

			expect(imports.has_imports()).toBe(true);
		});

		test('import_count returns correct count', () => {
			const imports = new Import_Builder();

			expect(imports.import_count).toBe(0);

			imports.add_type('$lib/types.js', 'Foo');
			expect(imports.import_count).toBe(1);

			imports.add('$lib/utils.js', 'bar');
			expect(imports.import_count).toBe(2);

			// Adding to existing module doesn't increase count
			imports.add_type('$lib/types.js', 'Bar');
			expect(imports.import_count).toBe(2);
		});

		test('preview returns array of import statements', () => {
			const imports = new Import_Builder();

			imports.add_types('$lib/types.js', 'Foo', 'Bar');
			imports.add('$lib/utils.js', 'helper');

			const preview = imports.preview();

			expect(preview).toHaveLength(2);
			expect(preview[0]).toBe(`import type {Bar, Foo} from '$lib/types.js';`);
			expect(preview[1]).toBe(`import {helper} from '$lib/utils.js';`);
		});

		test('clear removes all imports', () => {
			const imports = new Import_Builder();

			imports.add_types('$lib/types.js', 'Foo', 'Bar');
			imports.add('$lib/utils.js', 'helper');

			expect(imports.import_count).toBe(2);

			imports.clear();

			expect(imports.import_count).toBe(0);
			expect(imports.build()).toBe('');
		});

		test('chaining works correctly', () => {
			const imports = new Import_Builder();

			const result = imports
				.add_type('$lib/types.js', 'Foo')
				.add('$lib/utils.js', 'helper')
				.add_types('$lib/types.js', 'Bar', 'Baz')
				.clear()
				.add_type('$lib/final.js', 'Final');

			expect(result).toBe(imports); // Chainable
			expect(imports.build()).toBe(`import type {Final} from '$lib/final.js';`);
		});
	});

	describe('add_many helper', () => {
		test('adds multiple value imports', () => {
			const imports = new Import_Builder();

			imports.add_many('$lib/utils.js', 'util_a', 'util_b', 'util_c');

			expect(imports.build()).toBe(`import {util_a, util_b, util_c} from '$lib/utils.js';`);
		});
	});
});

describe('get_executor_phases', () => {
	describe('request_response actions', () => {
		test('frontend initiator', () => {
			const spec = {
				kind: 'request_response',
				initiator: 'frontend',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual(['send_request', 'receive_response']);
			expect(get_executor_phases(spec, 'backend')).toEqual(['receive_request', 'send_response']);
		});

		test('backend initiator', () => {
			const spec = {
				kind: 'request_response',
				initiator: 'backend',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual(['receive_request', 'send_response']);
			expect(get_executor_phases(spec, 'backend')).toEqual(['send_request', 'receive_response']);
		});

		test('both initiator', () => {
			const spec = {
				kind: 'request_response',
				initiator: 'both',
			} as Action_Spec;

			const expected_all = ['send_request', 'receive_response', 'receive_request', 'send_response'];
			expect(get_executor_phases(spec, 'frontend')).toEqual(expected_all);
			expect(get_executor_phases(spec, 'backend')).toEqual(expected_all);
		});
	});

	describe('remote_notification actions', () => {
		test('frontend initiator', () => {
			const spec = {
				kind: 'remote_notification',
				initiator: 'frontend',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual(['send']);
			expect(get_executor_phases(spec, 'backend')).toEqual(['receive']);
		});

		test('backend initiator', () => {
			const spec = {
				kind: 'remote_notification',
				initiator: 'backend',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual(['receive']);
			expect(get_executor_phases(spec, 'backend')).toEqual(['send']);
		});

		test('both initiator', () => {
			const spec = {
				kind: 'remote_notification',
				initiator: 'both',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual(['send', 'receive']);
			expect(get_executor_phases(spec, 'backend')).toEqual(['send', 'receive']);
		});
	});

	describe('local_call actions', () => {
		test('frontend initiator', () => {
			const spec = {
				kind: 'local_call',
				initiator: 'frontend',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual(['execute']);
			expect(get_executor_phases(spec, 'backend')).toEqual([]);
		});

		test('backend initiator', () => {
			const spec = {
				kind: 'local_call',
				initiator: 'backend',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual([]);
			expect(get_executor_phases(spec, 'backend')).toEqual(['execute']);
		});

		test('both initiator', () => {
			const spec = {
				kind: 'local_call',
				initiator: 'both',
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual(['execute']);
			expect(get_executor_phases(spec, 'backend')).toEqual(['execute']);
		});
	});

	describe('edge cases', () => {
		test('returns empty array for invalid combinations', () => {
			const spec = {
				kind: 'request_response',
				initiator: 'invalid' as any,
			} as Action_Spec;

			expect(get_executor_phases(spec, 'frontend')).toEqual([]);
			expect(get_executor_phases(spec, 'backend')).toEqual([]);
		});

		test('phases are returned in correct order', () => {
			const spec = {
				kind: 'request_response',
				initiator: 'both',
			} as Action_Spec;

			const frontend_phases = get_executor_phases(spec, 'frontend');
			// Send phases should come before receive phases
			expect(frontend_phases.indexOf('send_request')).toBeLessThan(
				frontend_phases.indexOf('receive_request'),
			);
		});
	});
});

describe('get_action_event_type', () => {
	test('frontend event types', () => {
		expect(get_action_event_type('request_response', 'frontend')).toBe(
			'Frontend_Request_Response_Action_Event',
		);

		expect(get_action_event_type('remote_notification', 'frontend')).toBe(
			'Frontend_Remote_Notification_Action_Event',
		);

		expect(get_action_event_type('local_call', 'frontend')).toBe(
			'Frontend_Local_Call_Action_Event',
		);
	});

	test('backend event types', () => {
		expect(get_action_event_type('request_response', 'backend')).toBe(
			'Backend_Request_Response_Action_Event',
		);

		expect(get_action_event_type('remote_notification', 'backend')).toBe(
			'Backend_Remote_Notification_Action_Event',
		);

		expect(get_action_event_type('local_call', 'backend')).toBe('Backend_Local_Call_Action_Event');
	});
});

describe('get_handler_return_type', () => {
	describe('request_response actions', () => {
		test('receive_request phase returns output with Promise', () => {
			const spec = {
				kind: 'request_response',
				method: 'test_method',
				async: true,
			} as Action_Spec;

			// Request/response actions are always async
			expect(get_handler_return_type(spec, 'receive_request')).toBe(
				`Action_Outputs['test_method'] | Promise<Action_Outputs['test_method']>`,
			);
		});

		test('other phases return void', () => {
			const spec = {
				kind: 'request_response',
				method: 'test_method',
				async: true,
			} as Action_Spec;

			expect(get_handler_return_type(spec, 'send_request')).toBe('void | Promise<void>');
			expect(get_handler_return_type(spec, 'send_response')).toBe('void | Promise<void>');
			expect(get_handler_return_type(spec, 'receive_response')).toBe('void | Promise<void>');
		});
	});

	describe('local_call actions', () => {
		test('execute phase returns output', () => {
			const async_spec = {
				kind: 'local_call',
				method: 'test_method',
				async: true,
			} as Action_Spec;

			expect(get_handler_return_type(async_spec, 'execute')).toBe(
				`Action_Outputs['test_method'] | Promise<Action_Outputs['test_method']>`,
			);

			const sync_spec = {
				kind: 'local_call',
				method: 'test_method',
				async: false,
			} as Action_Spec;

			expect(get_handler_return_type(sync_spec, 'execute')).toBe(`Action_Outputs['test_method']`);
		});
	});

	describe('remote_notification actions', () => {
		test('all phases return void', () => {
			const spec = {
				kind: 'remote_notification',
				method: 'test_method',
				async: true,
			} as Action_Spec;

			expect(get_handler_return_type(spec, 'send')).toBe('void | Promise<void>');
			expect(get_handler_return_type(spec, 'receive')).toBe('void | Promise<void>');
		});

		test('sync notifications still return void', () => {
			const spec = {
				kind: 'remote_notification',
				method: 'test_method',
				async: false,
			} as Action_Spec;

			expect(get_handler_return_type(spec, 'send')).toBe('void');
			expect(get_handler_return_type(spec, 'receive')).toBe('void');
		});
	});
});

describe('generate_phase_handlers', () => {
	test('generates never for actions with no valid phases', () => {
		const spec = {
			method: 'test_action',
			kind: 'local_call',
			initiator: 'backend',
		} as Action_Spec;

		const imports = new Import_Builder();
		const result = generate_phase_handlers(spec, 'frontend', imports);

		expect(result).toBe('test_action?: never');
		expect(imports.has_imports()).toBe(false);
	});

	test('generates handlers for request_response action', () => {
		const spec = {
			method: 'save_file',
			kind: 'request_response',
			initiator: 'frontend',
			async: true,
		} as Action_Spec;

		const imports = new Import_Builder();
		const result = generate_phase_handlers(spec, 'frontend', imports);

		expect(result).toContain('save_file?: {');
		expect(result).toContain('send_request?:');
		expect(result).toContain('receive_response?:');
		expect(result).not.toContain('receive_request');

		// Check imports were added
		expect(imports.has_imports()).toBe(true);
		const import_str = imports.build();
		expect(import_str).toContain('Frontend_Request_Response_Action_Event');
		expect(import_str).toContain('Action_Inputs');
		expect(import_str).toContain('Action_Outputs');
	});

	test('generates handlers for notification action', () => {
		const spec = {
			method: 'file_changed',
			kind: 'remote_notification',
			initiator: 'backend',
			async: true,
		} as Action_Spec;

		const imports = new Import_Builder();
		const result = generate_phase_handlers(spec, 'backend', imports);

		expect(result).toContain('file_changed?: {');
		expect(result).toContain('send?:');
		expect(result).not.toContain('receive?:');

		const import_str = imports.build();
		expect(import_str).toContain('Backend_Remote_Notification_Action_Event');
	});

	test('generates handlers for local_call action', () => {
		const spec = {
			method: 'toggle_menu',
			kind: 'local_call',
			initiator: 'both',
			async: false,
		} as Action_Spec;

		const imports = new Import_Builder();
		const result = generate_phase_handlers(spec, 'frontend', imports);

		expect(result).toContain('toggle_menu?: {');
		expect(result).toContain('execute?:');
		expect(result).toContain(`Action_Outputs['toggle_menu']`);
		expect(result).not.toContain('Promise');

		const import_str = imports.build();
		expect(import_str).toContain('Frontend_Local_Call_Action_Event');
	});

	test('uses type-only imports when appropriate', () => {
		const spec = {
			method: 'test',
			kind: 'request_response',
			initiator: 'frontend',
			async: true,
		} as Action_Spec;

		const imports = new Import_Builder();
		generate_phase_handlers(spec, 'backend', imports);

		const import_str = imports.build();
		// All imports should be type-only
		expect(import_str).toMatch(/^import type/);
	});

	test('handles methods with special characters in names', () => {
		const spec = {
			method: 'test-action_2',
			kind: 'request_response',
			initiator: 'both',
			async: true,
		} as Action_Spec;

		const imports = new Import_Builder();
		const result = generate_phase_handlers(spec, 'frontend', imports);

		expect(result).toContain('test-action_2?: {');
		expect(result).toContain(`Action_Inputs['test-action_2']`);
		expect(result).toContain(`Action_Outputs['test-action_2']`);
	});

	test('generates all phases for both initiator', () => {
		const spec = {
			method: 'bidirectional',
			kind: 'request_response',
			initiator: 'both',
			async: true,
		} as Action_Spec;

		const imports = new Import_Builder();
		const result = generate_phase_handlers(spec, 'frontend', imports);

		expect(result).toContain('send_request?:');
		expect(result).toContain('receive_response?:');
		expect(result).toContain('receive_request?:');
		expect(result).toContain('send_response?:');
	});
});

describe('create_banner', () => {
	test('creates banner with origin path', () => {
		const banner = create_banner('src/lib/test.gen.ts');
		expect(banner).toBe('generated by src/lib/test.gen.ts - DO NOT EDIT OR RISK LOST DATA');
	});

	test('handles different path formats', () => {
		expect(create_banner('/absolute/path.ts')).toBe(
			'generated by /absolute/path.ts - DO NOT EDIT OR RISK LOST DATA',
		);

		expect(create_banner('./relative/path.ts')).toBe(
			'generated by ./relative/path.ts - DO NOT EDIT OR RISK LOST DATA',
		);

		expect(create_banner('simple.ts')).toBe(
			'generated by simple.ts - DO NOT EDIT OR RISK LOST DATA',
		);
	});
});
