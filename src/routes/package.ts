// generated by src/routes/package.gen.ts

import type {Package_Json} from '@ryanatkn/gro/package_json.js';
import type {Src_Json} from '@ryanatkn/gro/src_json.js';

export const package_json = {
	name: '@ryanatkn/zzz',
	version: '0.0.1',
	description: 'bot and web toolkit',
	motto: 'bot control web',
	glyph: '💤',
	logo: 'logo.svg',
	logo_alt: "three sleepy z's",
	public: true,
	license: 'MIT',
	homepage: 'https://www.zzzbot.dev/',
	repository: 'https://github.com/ryanatkn/zzz',
	author: {name: 'Ryan Atkinson', email: 'mail@ryanatkn.com', url: 'https://www.ryanatkn.com/'},
	bugs: 'https://github.com/ryanatkn/zzz/issues',
	funding: 'https://www.ryanatkn.com/funding',
	scripts: {
		start: 'gro dev',
		dev: 'gro dev',
		build: 'gro build',
		check: 'gro check',
		test: 'gro test',
		preview: 'vite preview',
		deploy: 'gro deploy',
		serve: 'gro build && npm run preview & node ',
	},
	type: 'module',
	engines: {node: '>=20.17'},
	peerDependencies: {'@sveltejs/kit': '^2', svelte: '^5'},
	devDependencies: {
		'@changesets/changelog-git': '^0.2.1',
		'@ryanatkn/eslint-config': '^0.7.0',
		'@ryanatkn/fuz': '^0.133.1',
		'@ryanatkn/gro': '^0.148.0',
		'@ryanatkn/moss': '^0.23.0',
		'@sveltejs/adapter-static': '^3.0.8',
		'@sveltejs/kit': '^2.17.2',
		'@sveltejs/package': '^2.3.10',
		'@sveltejs/vite-plugin-svelte': '^4.0.0',
		eslint: '^9.21.0',
		'eslint-plugin-svelte': '^2.46.1',
		jsdom: '^26.0.0',
		ollama: '^0.5.14',
		prettier: '^3.5.2',
		'prettier-plugin-svelte': '^3.3.3',
		svelte: '5.20.2',
		'svelte-check': '^4.1.4',
		tslib: '^2.8.1',
		typescript: '^5.7.3',
		'typescript-eslint': '^8.25.0',
		vitest: '^3.0.7',
		zod: '^3.24.2',
	},
	dependencies: {
		'@anthropic-ai/sdk': '^0.37.0',
		'@google/generative-ai': '^0.22.0',
		'@hono/node-server': '^1.13.8',
		'@hono/node-ws': '^1.1.0',
		'@ryanatkn/belt': '^0.29.1',
		'date-fns': '^4.1.0',
		devalue: '^5.1.1',
		'esm-env': '^1.2.2',
		'gpt-tokenizer': '^2.8.1',
		hono: '^4.7.2',
		openai: '^4.85.4',
	},
	prettier: {
		plugins: ['prettier-plugin-svelte'],
		useTabs: true,
		printWidth: 100,
		singleQuote: true,
		bracketSpacing: false,
		overrides: [{files: 'package.json', options: {useTabs: false}}],
	},
	sideEffects: ['**/*.css'],
	files: ['dist'],
	exports: {
		'./package.json': './package.json',
		'./Bit_List.svelte': {
			types: './dist/Bit_List.svelte.d.ts',
			svelte: './dist/Bit_List.svelte',
			default: './dist/Bit_List.svelte',
		},
		'./Bit_Stats.svelte': {
			types: './dist/Bit_Stats.svelte.d.ts',
			svelte: './dist/Bit_Stats.svelte',
			default: './dist/Bit_Stats.svelte',
		},
		'./Bit_Summary.svelte': {
			types: './dist/Bit_Summary.svelte.d.ts',
			svelte: './dist/Bit_Summary.svelte',
			default: './dist/Bit_Summary.svelte',
		},
		'./Bit_View.svelte': {
			types: './dist/Bit_View.svelte.d.ts',
			svelte: './dist/Bit_View.svelte',
			default: './dist/Bit_View.svelte',
		},
		'./bit.svelte.js': {types: './dist/bit.svelte.d.ts', default: './dist/bit.svelte.js'},
		'./cell_helpers.js': {types: './dist/cell_helpers.d.ts', default: './dist/cell_helpers.js'},
		'./cell_registry.js': {types: './dist/cell_registry.d.ts', default: './dist/cell_registry.js'},
		'./cell_types.js': {types: './dist/cell_types.d.ts', default: './dist/cell_types.js'},
		'./cell.svelte.js': {types: './dist/cell.svelte.d.ts', default: './dist/cell.svelte.js'},
		'./Chat_Message_Item.svelte': {
			types: './dist/Chat_Message_Item.svelte.d.ts',
			svelte: './dist/Chat_Message_Item.svelte',
			default: './dist/Chat_Message_Item.svelte',
		},
		'./chat_message.svelte.js': {
			types: './dist/chat_message.svelte.d.ts',
			default: './dist/chat_message.svelte.js',
		},
		'./Chat_Tape.svelte': {
			types: './dist/Chat_Tape.svelte.d.ts',
			svelte: './dist/Chat_Tape.svelte',
			default: './dist/Chat_Tape.svelte',
		},
		'./Chat_View.svelte': {
			types: './dist/Chat_View.svelte.d.ts',
			svelte: './dist/Chat_View.svelte',
			default: './dist/Chat_View.svelte',
		},
		'./chat.svelte.js': {types: './dist/chat.svelte.d.ts', default: './dist/chat.svelte.js'},
		'./chats.svelte.js': {types: './dist/chats.svelte.d.ts', default: './dist/chats.svelte.js'},
		'./Clear_Restore_Button.svelte': {
			types: './dist/Clear_Restore_Button.svelte.d.ts',
			svelte: './dist/Clear_Restore_Button.svelte',
			default: './dist/Clear_Restore_Button.svelte',
		},
		'./config_helpers.js': {
			types: './dist/config_helpers.d.ts',
			default: './dist/config_helpers.js',
		},
		'./config.js': {types: './dist/config.d.ts', default: './dist/config.js'},
		'./Confirm_Button.svelte': {
			types: './dist/Confirm_Button.svelte.d.ts',
			svelte: './dist/Confirm_Button.svelte',
			default: './dist/Confirm_Button.svelte',
		},
		'./constants.js': {types: './dist/constants.d.ts', default: './dist/constants.js'},
		'./Control_Panel.svelte': {
			types: './dist/Control_Panel.svelte.d.ts',
			svelte: './dist/Control_Panel.svelte',
			default: './dist/Control_Panel.svelte',
		},
		'./Dashboard_Capabilities.svelte': {
			types: './dist/Dashboard_Capabilities.svelte.d.ts',
			svelte: './dist/Dashboard_Capabilities.svelte',
			default: './dist/Dashboard_Capabilities.svelte',
		},
		'./Dashboard_Chats.svelte': {
			types: './dist/Dashboard_Chats.svelte.d.ts',
			svelte: './dist/Dashboard_Chats.svelte',
			default: './dist/Dashboard_Chats.svelte',
		},
		'./Dashboard_Files.svelte': {
			types: './dist/Dashboard_Files.svelte.d.ts',
			svelte: './dist/Dashboard_Files.svelte',
			default: './dist/Dashboard_Files.svelte',
		},
		'./Dashboard_Home.svelte': {
			types: './dist/Dashboard_Home.svelte.d.ts',
			svelte: './dist/Dashboard_Home.svelte',
			default: './dist/Dashboard_Home.svelte',
		},
		'./Dashboard_Messages.svelte': {
			types: './dist/Dashboard_Messages.svelte.d.ts',
			svelte: './dist/Dashboard_Messages.svelte',
			default: './dist/Dashboard_Messages.svelte',
		},
		'./Dashboard_Models.svelte': {
			types: './dist/Dashboard_Models.svelte.d.ts',
			svelte: './dist/Dashboard_Models.svelte',
			default: './dist/Dashboard_Models.svelte',
		},
		'./Dashboard_Prompts.svelte': {
			types: './dist/Dashboard_Prompts.svelte.d.ts',
			svelte: './dist/Dashboard_Prompts.svelte',
			default: './dist/Dashboard_Prompts.svelte',
		},
		'./Dashboard_Providers.svelte': {
			types: './dist/Dashboard_Providers.svelte.d.ts',
			svelte: './dist/Dashboard_Providers.svelte',
			default: './dist/Dashboard_Providers.svelte',
		},
		'./Dashboard_Settings.svelte': {
			types: './dist/Dashboard_Settings.svelte.d.ts',
			svelte: './dist/Dashboard_Settings.svelte',
			default: './dist/Dashboard_Settings.svelte',
		},
		'./Dashboard.svelte': {
			types: './dist/Dashboard.svelte.d.ts',
			svelte: './dist/Dashboard.svelte',
			default: './dist/Dashboard.svelte',
		},
		'./Diskfile_Editor.svelte': {
			types: './dist/Diskfile_Editor.svelte.d.ts',
			svelte: './dist/Diskfile_Editor.svelte',
			default: './dist/Diskfile_Editor.svelte',
		},
		'./Diskfile_Explorer.svelte': {
			types: './dist/Diskfile_Explorer.svelte.d.ts',
			svelte: './dist/Diskfile_Explorer.svelte',
			default: './dist/Diskfile_Explorer.svelte',
		},
		'./diskfile_helpers.js': {
			types: './dist/diskfile_helpers.d.ts',
			default: './dist/diskfile_helpers.js',
		},
		'./Diskfile_List_Item.svelte': {
			types: './dist/Diskfile_List_Item.svelte.d.ts',
			svelte: './dist/Diskfile_List_Item.svelte',
			default: './dist/Diskfile_List_Item.svelte',
		},
		'./diskfile_types.js': {
			types: './dist/diskfile_types.d.ts',
			default: './dist/diskfile_types.js',
		},
		'./diskfile.svelte.js': {
			types: './dist/diskfile.svelte.d.ts',
			default: './dist/diskfile.svelte.js',
		},
		'./diskfiles.svelte.js': {
			types: './dist/diskfiles.svelte.d.ts',
			default: './dist/diskfiles.svelte.js',
		},
		'./Error_Message.svelte': {
			types: './dist/Error_Message.svelte.d.ts',
			svelte: './dist/Error_Message.svelte',
			default: './dist/Error_Message.svelte',
		},
		'./External_Link_Symbol.svelte': {
			types: './dist/External_Link_Symbol.svelte.d.ts',
			svelte: './dist/External_Link_Symbol.svelte',
			default: './dist/External_Link_Symbol.svelte',
		},
		'./External_Link.svelte': {
			types: './dist/External_Link.svelte.d.ts',
			svelte: './dist/External_Link.svelte',
			default: './dist/External_Link.svelte',
		},
		'./glyphs.js': {types: './dist/glyphs.d.ts', default: './dist/glyphs.js'},
		'./helpers.js': {types: './dist/helpers.d.ts', default: './dist/helpers.js'},
		'./list_helpers.js': {types: './dist/list_helpers.d.ts', default: './dist/list_helpers.js'},
		'./Main_Dialog.svelte': {
			types: './dist/Main_Dialog.svelte.d.ts',
			svelte: './dist/Main_Dialog.svelte',
			default: './dist/Main_Dialog.svelte',
		},
		'./Message_Detail.svelte': {
			types: './dist/Message_Detail.svelte.d.ts',
			svelte: './dist/Message_Detail.svelte',
			default: './dist/Message_Detail.svelte',
		},
		'./Message_Info.svelte': {
			types: './dist/Message_Info.svelte.d.ts',
			svelte: './dist/Message_Info.svelte',
			default: './dist/Message_Info.svelte',
		},
		'./Message_Summary.svelte': {
			types: './dist/Message_Summary.svelte.d.ts',
			svelte: './dist/Message_Summary.svelte',
			default: './dist/Message_Summary.svelte',
		},
		'./message_types.js': {types: './dist/message_types.d.ts', default: './dist/message_types.js'},
		'./Message_View.svelte': {
			types: './dist/Message_View.svelte.d.ts',
			svelte: './dist/Message_View.svelte',
			default: './dist/Message_View.svelte',
		},
		'./message.svelte.js': {
			types: './dist/message.svelte.d.ts',
			default: './dist/message.svelte.js',
		},
		'./Messages_List.svelte': {
			types: './dist/Messages_List.svelte.d.ts',
			svelte: './dist/Messages_List.svelte',
			default: './dist/Messages_List.svelte',
		},
		'./messages.svelte.js': {
			types: './dist/messages.svelte.d.ts',
			default: './dist/messages.svelte.js',
		},
		'./Model_Detail.svelte': {
			types: './dist/Model_Detail.svelte.d.ts',
			svelte: './dist/Model_Detail.svelte',
			default: './dist/Model_Detail.svelte',
		},
		'./Model_Link.svelte': {
			types: './dist/Model_Link.svelte.d.ts',
			svelte: './dist/Model_Link.svelte',
			default: './dist/Model_Link.svelte',
		},
		'./Model_Select.svelte': {
			types: './dist/Model_Select.svelte.d.ts',
			svelte: './dist/Model_Select.svelte',
			default: './dist/Model_Select.svelte',
		},
		'./Model_Selector.svelte': {
			types: './dist/Model_Selector.svelte.d.ts',
			svelte: './dist/Model_Selector.svelte',
			default: './dist/Model_Selector.svelte',
		},
		'./Model_Summary.svelte': {
			types: './dist/Model_Summary.svelte.d.ts',
			svelte: './dist/Model_Summary.svelte',
			default: './dist/Model_Summary.svelte',
		},
		'./model.svelte.js': {types: './dist/model.svelte.d.ts', default: './dist/model.svelte.js'},
		'./models.svelte.js': {types: './dist/models.svelte.d.ts', default: './dist/models.svelte.js'},
		'./Nav_Link.svelte': {
			types: './dist/Nav_Link.svelte.d.ts',
			svelte: './dist/Nav_Link.svelte',
			default: './dist/Nav_Link.svelte',
		},
		'./ollama.js': {types: './dist/ollama.d.ts', default: './dist/ollama.js'},
		'./path.js': {types: './dist/path.d.ts', default: './dist/path.js'},
		'./Ping_Form.svelte': {
			types: './dist/Ping_Form.svelte.d.ts',
			svelte: './dist/Ping_Form.svelte',
			default: './dist/Ping_Form.svelte',
		},
		'./Prompt_List.svelte': {
			types: './dist/Prompt_List.svelte.d.ts',
			svelte: './dist/Prompt_List.svelte',
			default: './dist/Prompt_List.svelte',
		},
		'./Prompt_Stats.svelte': {
			types: './dist/Prompt_Stats.svelte.d.ts',
			svelte: './dist/Prompt_Stats.svelte',
			default: './dist/Prompt_Stats.svelte',
		},
		'./Prompt_Summary.svelte': {
			types: './dist/Prompt_Summary.svelte.d.ts',
			svelte: './dist/Prompt_Summary.svelte',
			default: './dist/Prompt_Summary.svelte',
		},
		'./prompt.svelte.js': {types: './dist/prompt.svelte.d.ts', default: './dist/prompt.svelte.js'},
		'./prompts.svelte.js': {
			types: './dist/prompts.svelte.d.ts',
			default: './dist/prompts.svelte.js',
		},
		'./Provider_Detail.svelte': {
			types: './dist/Provider_Detail.svelte.d.ts',
			svelte: './dist/Provider_Detail.svelte',
			default: './dist/Provider_Detail.svelte',
		},
		'./Provider_Link.svelte': {
			types: './dist/Provider_Link.svelte.d.ts',
			svelte: './dist/Provider_Link.svelte',
			default: './dist/Provider_Link.svelte',
		},
		'./Provider_Logo.svelte': {
			types: './dist/Provider_Logo.svelte.d.ts',
			svelte: './dist/Provider_Logo.svelte',
			default: './dist/Provider_Logo.svelte',
		},
		'./Provider_Select.svelte': {
			types: './dist/Provider_Select.svelte.d.ts',
			svelte: './dist/Provider_Select.svelte',
			default: './dist/Provider_Select.svelte',
		},
		'./Provider_Summary.svelte': {
			types: './dist/Provider_Summary.svelte.d.ts',
			svelte: './dist/Provider_Summary.svelte',
			default: './dist/Provider_Summary.svelte',
		},
		'./provider_types.js': {
			types: './dist/provider_types.d.ts',
			default: './dist/provider_types.js',
		},
		'./provider.svelte.js': {
			types: './dist/provider.svelte.d.ts',
			default: './dist/provider.svelte.js',
		},
		'./providers.svelte.js': {
			types: './dist/providers.svelte.d.ts',
			default: './dist/providers.svelte.js',
		},
		'./reorderable_helpers.js': {
			types: './dist/reorderable_helpers.d.ts',
			default: './dist/reorderable_helpers.js',
		},
		'./reorderable.svelte.js': {
			types: './dist/reorderable.svelte.d.ts',
			default: './dist/reorderable.svelte.js',
		},
		'./response_helpers.js': {
			types: './dist/response_helpers.d.ts',
			default: './dist/response_helpers.js',
		},
		'./scrollable.svelte.js': {
			types: './dist/scrollable.svelte.d.ts',
			default: './dist/scrollable.svelte.js',
		},
		'./server/.env.example': {default: './dist/server/.env.example'},
		'./server/ai_provider_utils.js': {
			types: './dist/server/ai_provider_utils.d.ts',
			default: './dist/server/ai_provider_utils.js',
		},
		'./server/helpers.js': {
			types: './dist/server/helpers.d.ts',
			default: './dist/server/helpers.js',
		},
		'./server/server.js': {types: './dist/server/server.d.ts', default: './dist/server/server.js'},
		'./server/zzz_server.js': {
			types: './dist/server/zzz_server.d.ts',
			default: './dist/server/zzz_server.js',
		},
		'./Settings.svelte': {
			types: './dist/Settings.svelte.d.ts',
			svelte: './dist/Settings.svelte',
			default: './dist/Settings.svelte',
		},
		'./Tape_List.svelte': {
			types: './dist/Tape_List.svelte.d.ts',
			svelte: './dist/Tape_List.svelte',
			default: './dist/Tape_List.svelte',
		},
		'./Tape_Summary.svelte': {
			types: './dist/Tape_Summary.svelte.d.ts',
			svelte: './dist/Tape_Summary.svelte',
			default: './dist/Tape_Summary.svelte',
		},
		'./tape.svelte.js': {types: './dist/tape.svelte.d.ts', default: './dist/tape.svelte.js'},
		'./test.task.js': {types: './dist/test.task.d.ts', default: './dist/test.task.js'},
		'./Text_Icon.svelte': {
			types: './dist/Text_Icon.svelte.d.ts',
			svelte: './dist/Text_Icon.svelte',
			default: './dist/Text_Icon.svelte',
		},
		'./ui.svelte.js': {types: './dist/ui.svelte.d.ts', default: './dist/ui.svelte.js'},
		'./Xml_Attribute_Input.svelte': {
			types: './dist/Xml_Attribute_Input.svelte.d.ts',
			svelte: './dist/Xml_Attribute_Input.svelte',
			default: './dist/Xml_Attribute_Input.svelte',
		},
		'./Xml_Tag_Controls.svelte': {
			types: './dist/Xml_Tag_Controls.svelte.d.ts',
			svelte: './dist/Xml_Tag_Controls.svelte',
			default: './dist/Xml_Tag_Controls.svelte',
		},
		'./xml.js': {types: './dist/xml.d.ts', default: './dist/xml.js'},
		'./zod_helpers.js': {types: './dist/zod_helpers.d.ts', default: './dist/zod_helpers.js'},
		'./zzz_config.js': {types: './dist/zzz_config.d.ts', default: './dist/zzz_config.js'},
		'./Zzz_Root.svelte': {
			types: './dist/Zzz_Root.svelte.d.ts',
			svelte: './dist/Zzz_Root.svelte',
			default: './dist/Zzz_Root.svelte',
		},
		'./zzz.svelte.js': {types: './dist/zzz.svelte.d.ts', default: './dist/zzz.svelte.js'},
	},
} satisfies Package_Json;

export const src_json = {
	name: '@ryanatkn/zzz',
	version: '0.0.1',
	modules: {
		'./package.json': {path: 'package.json', declarations: []},
		'./Bit_List.svelte': {path: 'Bit_List.svelte', declarations: []},
		'./Bit_Stats.svelte': {path: 'Bit_Stats.svelte', declarations: []},
		'./Bit_Summary.svelte': {path: 'Bit_Summary.svelte', declarations: []},
		'./Bit_View.svelte': {path: 'Bit_View.svelte', declarations: []},
		'./bit.svelte.js': {
			path: 'bit.svelte.ts',
			declarations: [
				{name: 'Bit_Json', kind: 'variable'},
				{name: 'Bit_Options', kind: 'type'},
				{name: 'Bit', kind: 'class'},
			],
		},
		'./cell_helpers.js': {
			path: 'cell_helpers.ts',
			declarations: [
				{name: 'ZOD_CELL_CLASS_NAME', kind: 'variable'},
				{name: 'ZOD_ELEMENT_CLASS_NAME', kind: 'variable'},
				{name: 'Schema_Class_Info', kind: 'type'},
				{name: 'cell_class', kind: 'function'},
				{name: 'cell_array', kind: 'function'},
				{name: 'Value_Parser', kind: 'type'},
				{name: 'Cell_Value_Parser', kind: 'type'},
				{name: 'get_schema_class_info', kind: 'function'},
			],
		},
		'./cell_registry.js': {
			path: 'cell_registry.ts',
			declarations: [{name: 'Cell_Registry', kind: 'class'}],
		},
		'./cell_types.js': {
			path: 'cell_types.ts',
			declarations: [
				{name: 'Schema_Keys', kind: 'type'},
				{name: 'Schema_Value', kind: 'type'},
				{name: 'Cell_Json', kind: 'variable'},
			],
		},
		'./cell.svelte.js': {
			path: 'cell.svelte.ts',
			declarations: [
				{name: 'Cell_Options', kind: 'type'},
				{name: 'Cell', kind: 'class'},
			],
		},
		'./Chat_Message_Item.svelte': {path: 'Chat_Message_Item.svelte', declarations: []},
		'./chat_message.svelte.js': {
			path: 'chat_message.svelte.ts',
			declarations: [
				{name: 'Chat_Message_Role', kind: 'variable'},
				{name: 'Chat_Message_Json', kind: 'variable'},
				{name: 'Chat_Message_Options', kind: 'type'},
				{name: 'Chat_Message', kind: 'class'},
				{name: 'create_chat_message', kind: 'function'},
			],
		},
		'./Chat_Tape.svelte': {path: 'Chat_Tape.svelte', declarations: []},
		'./Chat_View.svelte': {path: 'Chat_View.svelte', declarations: []},
		'./chat.svelte.js': {
			path: 'chat.svelte.ts',
			declarations: [
				{name: 'Chat_Json', kind: 'variable'},
				{name: 'Chat_Options', kind: 'type'},
				{name: 'Chat', kind: 'class'},
			],
		},
		'./chats.svelte.js': {
			path: 'chats.svelte.ts',
			declarations: [
				{name: 'Chats_Json', kind: 'variable'},
				{name: 'Chats_Options', kind: 'type'},
				{name: 'Chats', kind: 'class'},
			],
		},
		'./Clear_Restore_Button.svelte': {path: 'Clear_Restore_Button.svelte', declarations: []},
		'./config_helpers.js': {
			path: 'config_helpers.ts',
			declarations: [
				{name: 'Zzz_Config_Creator', kind: 'type'},
				{name: 'Zzz_Config', kind: 'type'},
			],
		},
		'./config.js': {
			path: 'config.ts',
			declarations: [
				{name: 'providers_default', kind: 'variable'},
				{name: 'models_default', kind: 'variable'},
				{name: 'SYSTEM_MESSAGE_DEFAULT', kind: 'variable'},
				{name: 'default', kind: 'variable'},
			],
		},
		'./Confirm_Button.svelte': {path: 'Confirm_Button.svelte', declarations: []},
		'./constants.js': {
			path: 'constants.ts',
			declarations: [{name: 'XML_TAG_NAME_DEFAULT', kind: 'variable'}],
		},
		'./Control_Panel.svelte': {path: 'Control_Panel.svelte', declarations: []},
		'./Dashboard_Capabilities.svelte': {path: 'Dashboard_Capabilities.svelte', declarations: []},
		'./Dashboard_Chats.svelte': {path: 'Dashboard_Chats.svelte', declarations: []},
		'./Dashboard_Files.svelte': {path: 'Dashboard_Files.svelte', declarations: []},
		'./Dashboard_Home.svelte': {path: 'Dashboard_Home.svelte', declarations: []},
		'./Dashboard_Messages.svelte': {path: 'Dashboard_Messages.svelte', declarations: []},
		'./Dashboard_Models.svelte': {path: 'Dashboard_Models.svelte', declarations: []},
		'./Dashboard_Prompts.svelte': {path: 'Dashboard_Prompts.svelte', declarations: []},
		'./Dashboard_Providers.svelte': {path: 'Dashboard_Providers.svelte', declarations: []},
		'./Dashboard_Settings.svelte': {path: 'Dashboard_Settings.svelte', declarations: []},
		'./Dashboard.svelte': {path: 'Dashboard.svelte', declarations: []},
		'./Diskfile_Editor.svelte': {path: 'Diskfile_Editor.svelte', declarations: []},
		'./Diskfile_Explorer.svelte': {path: 'Diskfile_Explorer.svelte', declarations: []},
		'./diskfile_helpers.js': {
			path: 'diskfile_helpers.ts',
			declarations: [
				{name: 'map_watcher_change_to_diskfile_change', kind: 'function'},
				{name: 'source_file_to_diskfile_json', kind: 'function'},
			],
		},
		'./Diskfile_List_Item.svelte': {path: 'Diskfile_List_Item.svelte', declarations: []},
		'./diskfile_types.js': {
			path: 'diskfile_types.ts',
			declarations: [
				{name: 'Diskfile_Change_Type', kind: 'variable'},
				{name: 'Diskfile_Path', kind: 'variable'},
				{name: 'Source_File', kind: 'variable'},
				{name: 'Diskfile_Json', kind: 'variable'},
			],
		},
		'./diskfile.svelte.js': {
			path: 'diskfile.svelte.ts',
			declarations: [
				{name: 'FILE_DATE_FORMAT', kind: 'variable'},
				{name: 'FILE_TIME_FORMAT', kind: 'variable'},
				{name: 'Diskfile_Options', kind: 'type'},
				{name: 'Diskfile', kind: 'class'},
			],
		},
		'./diskfiles.svelte.js': {
			path: 'diskfiles.svelte.ts',
			declarations: [
				{name: 'Diskfiles_Json', kind: 'variable'},
				{name: 'Diskfiles_Options', kind: 'type'},
				{name: 'Diskfiles', kind: 'class'},
			],
		},
		'./Error_Message.svelte': {path: 'Error_Message.svelte', declarations: []},
		'./External_Link_Symbol.svelte': {path: 'External_Link_Symbol.svelte', declarations: []},
		'./External_Link.svelte': {path: 'External_Link.svelte', declarations: []},
		'./glyphs.js': {
			path: 'glyphs.ts',
			declarations: [
				{name: 'GLYPH_REMOVE', kind: 'variable'},
				{name: 'GLYPH_DRAG', kind: 'variable'},
				{name: 'GLYPH_COPY', kind: 'variable'},
				{name: 'GLYPH_PASTE', kind: 'variable'},
				{name: 'GLYPH_CHAT', kind: 'variable'},
				{name: 'GLYPH_TAPE', kind: 'variable'},
				{name: 'GLYPH_FILE', kind: 'variable'},
				{name: 'GLYPH_PROMPT', kind: 'variable'},
				{name: 'GLYPH_BIT', kind: 'variable'},
				{name: 'GLYPH_PROVIDER', kind: 'variable'},
				{name: 'GLYPH_MODEL', kind: 'variable'},
				{name: 'GLYPH_MESSAGE', kind: 'variable'},
				{name: 'GLYPH_CAPABILITY', kind: 'variable'},
				{name: 'GLYPH_SETTINGS', kind: 'variable'},
				{name: 'GLYPH_ECHO', kind: 'variable'},
				{name: 'GLYPH_RESPONSE', kind: 'variable'},
				{name: 'GLYPH_SESSION', kind: 'variable'},
				{name: 'GLYPH_DIRECTION_CLIENT', kind: 'variable'},
				{name: 'GLYPH_DIRECTION_SERVER', kind: 'variable'},
				{name: 'GLYPH_DIRECTION_BOTH', kind: 'variable'},
				{name: 'get_icon_for_message_type', kind: 'function'},
				{name: 'get_direction_icon', kind: 'function'},
			],
		},
		'./helpers.js': {
			path: 'helpers.ts',
			declarations: [{name: 'get_unique_name', kind: 'function'}],
		},
		'./list_helpers.js': {
			path: 'list_helpers.ts',
			declarations: [{name: 'reorder_list', kind: 'function'}],
		},
		'./Main_Dialog.svelte': {path: 'Main_Dialog.svelte', declarations: []},
		'./Message_Detail.svelte': {path: 'Message_Detail.svelte', declarations: []},
		'./Message_Info.svelte': {path: 'Message_Info.svelte', declarations: []},
		'./Message_Summary.svelte': {path: 'Message_Summary.svelte', declarations: []},
		'./message_types.js': {
			path: 'message_types.ts',
			declarations: [
				{name: 'Message_Direction', kind: 'variable'},
				{name: 'Message_Type', kind: 'variable'},
				{name: 'Tape_History_Message', kind: 'variable'},
				{name: 'Ollama_Provider_Data', kind: 'type'},
				{name: 'Claude_Provider_Data', kind: 'type'},
				{name: 'Chatgpt_Provider_Data', kind: 'type'},
				{name: 'Gemini_Provider_Data', kind: 'type'},
				{name: 'Provider_Data', kind: 'type'},
				{name: 'Provider_Data_Schema', kind: 'variable'},
				{name: 'Completion_Request', kind: 'variable'},
				{name: 'Completion_Response', kind: 'variable'},
				{name: 'Message_Base', kind: 'variable'},
				{name: 'Message_Ping', kind: 'variable'},
				{name: 'Message_Pong', kind: 'variable'},
				{name: 'Message_Load_Session', kind: 'variable'},
				{name: 'Message_Loaded_Session', kind: 'variable'},
				{name: 'Message_Filer_Change', kind: 'variable'},
				{name: 'Message_Update_Diskfile', kind: 'variable'},
				{name: 'Message_Delete_Diskfile', kind: 'variable'},
				{name: 'Message_Send_Prompt', kind: 'variable'},
				{name: 'Message_Completion_Response', kind: 'variable'},
				{name: 'Message_Client', kind: 'variable'},
				{name: 'Message_Server', kind: 'variable'},
				{name: 'Message', kind: 'variable'},
				{name: 'Message_Json', kind: 'variable'},
				{name: 'create_message_json', kind: 'function'},
			],
		},
		'./Message_View.svelte': {path: 'Message_View.svelte', declarations: []},
		'./message.svelte.js': {
			path: 'message.svelte.ts',
			declarations: [
				{name: 'MESSAGE_PREVIEW_MAX_LENGTH', kind: 'variable'},
				{name: 'MESSAGE_DATE_FORMAT', kind: 'variable'},
				{name: 'MESSAGE_TIME_FORMAT', kind: 'variable'},
				{name: 'Message_Options', kind: 'type'},
				{name: 'Message', kind: 'class'},
			],
		},
		'./Messages_List.svelte': {path: 'Messages_List.svelte', declarations: []},
		'./messages.svelte.js': {
			path: 'messages.svelte.ts',
			declarations: [
				{name: 'HISTORY_LIMIT_DEFAULT', kind: 'variable'},
				{name: 'Messages_Json', kind: 'variable'},
				{name: 'Messages_Options', kind: 'type'},
				{name: 'Messages', kind: 'class'},
			],
		},
		'./Model_Detail.svelte': {path: 'Model_Detail.svelte', declarations: []},
		'./Model_Link.svelte': {path: 'Model_Link.svelte', declarations: []},
		'./Model_Select.svelte': {path: 'Model_Select.svelte', declarations: []},
		'./Model_Selector.svelte': {path: 'Model_Selector.svelte', declarations: []},
		'./Model_Summary.svelte': {path: 'Model_Summary.svelte', declarations: []},
		'./model.svelte.js': {
			path: 'model.svelte.ts',
			declarations: [
				{name: 'Model_Name', kind: 'variable'},
				{name: 'Model_Json', kind: 'variable'},
				{name: 'Model_Options', kind: 'type'},
				{name: 'Model', kind: 'class'},
			],
		},
		'./models.svelte.js': {
			path: 'models.svelte.ts',
			declarations: [
				{name: 'Models_Json', kind: 'variable'},
				{name: 'Models_Options', kind: 'type'},
				{name: 'Models', kind: 'class'},
			],
		},
		'./Nav_Link.svelte': {path: 'Nav_Link.svelte', declarations: []},
		'./ollama.js': {
			path: 'ollama.ts',
			declarations: [
				{name: 'Ollama_Model_Info', kind: 'type'},
				{name: 'Ollama_Models_Response', kind: 'type'},
				{name: 'ollama_list', kind: 'function'},
				{name: 'ollama_list_with_metadata', kind: 'function'},
				{name: 'merge_ollama_models', kind: 'function'},
			],
		},
		'./path.js': {path: 'path.ts', declarations: [{name: 'to_root_path', kind: 'function'}]},
		'./Ping_Form.svelte': {path: 'Ping_Form.svelte', declarations: []},
		'./Prompt_List.svelte': {path: 'Prompt_List.svelte', declarations: []},
		'./Prompt_Stats.svelte': {path: 'Prompt_Stats.svelte', declarations: []},
		'./Prompt_Summary.svelte': {path: 'Prompt_Summary.svelte', declarations: []},
		'./prompt.svelte.js': {
			path: 'prompt.svelte.ts',
			declarations: [
				{name: 'PROMPT_CONTENT_TRUNCATED_LENGTH', kind: 'variable'},
				{name: 'Prompt_Message', kind: 'type'},
				{name: 'Prompt_Message_Content', kind: 'type'},
				{name: 'Prompt_Json', kind: 'variable'},
				{name: 'Prompt_Options', kind: 'type'},
				{name: 'Prompt', kind: 'class'},
				{name: 'join_prompt_bits', kind: 'function'},
			],
		},
		'./prompts.svelte.js': {
			path: 'prompts.svelte.ts',
			declarations: [
				{name: 'Prompts_Json', kind: 'variable'},
				{name: 'Prompts_Options', kind: 'type'},
				{name: 'Prompts', kind: 'class'},
			],
		},
		'./Provider_Detail.svelte': {path: 'Provider_Detail.svelte', declarations: []},
		'./Provider_Link.svelte': {path: 'Provider_Link.svelte', declarations: []},
		'./Provider_Logo.svelte': {path: 'Provider_Logo.svelte', declarations: []},
		'./Provider_Select.svelte': {path: 'Provider_Select.svelte', declarations: []},
		'./Provider_Summary.svelte': {path: 'Provider_Summary.svelte', declarations: []},
		'./provider_types.js': {
			path: 'provider_types.ts',
			declarations: [{name: 'Provider_Name', kind: 'variable'}],
		},
		'./provider.svelte.js': {
			path: 'provider.svelte.ts',
			declarations: [
				{name: 'Provider_Json', kind: 'variable'},
				{name: 'Provider_Options', kind: 'type'},
				{name: 'Provider', kind: 'class'},
			],
		},
		'./providers.svelte.js': {
			path: 'providers.svelte.ts',
			declarations: [
				{name: 'Providers_Json', kind: 'variable'},
				{name: 'Providers_Options', kind: 'type'},
				{name: 'Providers', kind: 'class'},
			],
		},
		'./reorderable_helpers.js': {
			path: 'reorderable_helpers.ts',
			declarations: [
				{name: 'detect_reorderable_direction', kind: 'function'},
				{name: 'get_reorderable_drop_position', kind: 'function'},
				{name: 'calculate_reorderable_target_index', kind: 'function'},
				{name: 'is_reorder_allowed', kind: 'function'},
				{name: 'validate_reorderable_target_index', kind: 'function'},
				{name: 'set_reorderable_drag_data_transfer', kind: 'function'},
			],
		},
		'./reorderable.svelte.js': {
			path: 'reorderable.svelte.ts',
			declarations: [
				{name: 'Reorderable_Id', kind: 'type'},
				{name: 'Reorderable_Item_Id', kind: 'type'},
				{name: 'Reorderable_Direction', kind: 'type'},
				{name: 'Reorderable_Drop_Position', kind: 'type'},
				{name: 'Reorderable_Valid_Drop_Position', kind: 'type'},
				{name: 'Reorderable_Style_Config', kind: 'type'},
				{name: 'Reorderable_Style_Config_Partial', kind: 'type'},
				{name: 'Reorderable_List_Params', kind: 'type'},
				{name: 'Reorderable_Item_Params', kind: 'type'},
				{name: 'Reorderable_Options', kind: 'type'},
				{name: 'LIST_CLASS_DEFAULT', kind: 'variable'},
				{name: 'ITEM_CLASS_DEFAULT', kind: 'variable'},
				{name: 'DRAGGING_CLASS_DEFAULT', kind: 'variable'},
				{name: 'DRAG_OVER_CLASS_DEFAULT', kind: 'variable'},
				{name: 'DRAG_OVER_TOP_CLASS_DEFAULT', kind: 'variable'},
				{name: 'DRAG_OVER_BOTTOM_CLASS_DEFAULT', kind: 'variable'},
				{name: 'DRAG_OVER_LEFT_CLASS_DEFAULT', kind: 'variable'},
				{name: 'DRAG_OVER_RIGHT_CLASS_DEFAULT', kind: 'variable'},
				{name: 'INVALID_DROP_CLASS_DEFAULT', kind: 'variable'},
				{name: 'Reorderable', kind: 'class'},
			],
		},
		'./response_helpers.js': {
			path: 'response_helpers.ts',
			declarations: [
				{name: 'Unified_Completion_Response', kind: 'type'},
				{name: 'as_unified_response', kind: 'function'},
				{name: 'create_completion_response', kind: 'function'},
				{name: 'to_completion_response_text', kind: 'function'},
			],
		},
		'./scrollable.svelte.js': {
			path: 'scrollable.svelte.ts',
			declarations: [
				{name: 'Scrollable_Parameters', kind: 'type'},
				{name: 'Scrollable', kind: 'class'},
			],
		},
		'./server/.env.example': {path: 'server/.env.example', declarations: []},
		'./server/ai_provider_utils.js': {
			path: 'server/ai_provider_utils.ts',
			declarations: [
				{name: 'format_ollama_messages', kind: 'function'},
				{name: 'format_claude_messages', kind: 'function'},
				{name: 'format_openai_messages', kind: 'function'},
				{name: 'format_gemini_messages', kind: 'function'},
			],
		},
		'./server/helpers.js': {
			path: 'server/helpers.ts',
			declarations: [
				{name: 'write_file_in_scope', kind: 'function'},
				{name: 'delete_diskfile_in_scope', kind: 'function'},
			],
		},
		'./server/server.js': {path: 'server/server.ts', declarations: []},
		'./server/zzz_server.js': {
			path: 'server/zzz_server.ts',
			declarations: [
				{name: 'Zzz_Server_Options', kind: 'type'},
				{name: 'Zzz_Server', kind: 'class'},
			],
		},
		'./Settings.svelte': {path: 'Settings.svelte', declarations: []},
		'./Tape_List.svelte': {path: 'Tape_List.svelte', declarations: []},
		'./Tape_Summary.svelte': {path: 'Tape_Summary.svelte', declarations: []},
		'./tape.svelte.js': {
			path: 'tape.svelte.ts',
			declarations: [
				{name: 'Tape_Json', kind: 'variable'},
				{name: 'Tape_Options', kind: 'type'},
				{name: 'Tape', kind: 'class'},
			],
		},
		'./test.task.js': {
			path: 'test.task.ts',
			declarations: [
				{name: 'Args', kind: 'variable'},
				{name: 'task', kind: 'variable'},
			],
		},
		'./Text_Icon.svelte': {path: 'Text_Icon.svelte', declarations: []},
		'./ui.svelte.js': {
			path: 'ui.svelte.ts',
			declarations: [
				{name: 'Ui_Json', kind: 'variable'},
				{name: 'Ui_Options', kind: 'type'},
				{name: 'Ui', kind: 'class'},
			],
		},
		'./Xml_Attribute_Input.svelte': {path: 'Xml_Attribute_Input.svelte', declarations: []},
		'./Xml_Tag_Controls.svelte': {path: 'Xml_Tag_Controls.svelte', declarations: []},
		'./xml.js': {
			path: 'xml.ts',
			declarations: [
				{name: 'Xml_Attribute_Key_Base', kind: 'variable'},
				{name: 'Xml_Attribute_Key', kind: 'variable'},
				{name: 'Xml_Attribute_Value_Base', kind: 'variable'},
				{name: 'Xml_Attribute_Value', kind: 'variable'},
				{name: 'Xml_Attribute_Base', kind: 'variable'},
				{name: 'Xml_Attribute', kind: 'variable'},
			],
		},
		'./zod_helpers.js': {
			path: 'zod_helpers.ts',
			declarations: [
				{name: 'Datetime', kind: 'variable'},
				{name: 'Datetime_Now', kind: 'variable'},
				{name: 'Uuid_Base', kind: 'variable'},
				{name: 'Uuid', kind: 'variable'},
				{name: 'zod_get_schema_keys', kind: 'function'},
				{name: 'get_field_schema', kind: 'function'},
				{name: 'maybe_get_field_schema', kind: 'function'},
			],
		},
		'./zzz_config.js': {
			path: 'zzz_config.ts',
			declarations: [{name: 'zzz_config', kind: 'variable'}],
		},
		'./Zzz_Root.svelte': {path: 'Zzz_Root.svelte', declarations: []},
		'./zzz.svelte.js': {
			path: 'zzz.svelte.ts',
			declarations: [
				{name: 'cell_classes', kind: 'variable'},
				{name: 'Cell_Registry_Map', kind: 'type'},
				{name: 'zzz_context', kind: 'variable'},
				{name: 'Zzz_Json', kind: 'variable'},
				{name: 'Zzz_Options', kind: 'type'},
				{name: 'Message_With_History', kind: 'type'},
				{name: 'Zzz', kind: 'class'},
			],
		},
	},
} satisfies Src_Json;

// generated by src/routes/package.gen.ts
