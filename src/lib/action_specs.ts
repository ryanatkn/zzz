import {z} from 'zod';

import type {Action_Spec, Service_Action_Spec, Client_Action_Spec} from '$lib/schemas.js';
import {
  Ping_Action_Params,
  Ping_Action_Response,
  Pong_Action_Params,
  Pong_Action_Response,
  Load_Session_Action_Params,
  Load_Session_Action_Response,
  Loaded_Session_Action_Params,
  Loaded_Session_Action_Response,
  Filer_Change_Action_Params,
  Filer_Change_Action_Response,
  Update_Diskfile_Action_Params,
  Delete_Diskfile_Action_Params,
  Create_Directory_Action_Params,
  Send_Prompt_Action_Params,
  Completion_Response_Action_Params,
  Completion_Response_Action_Response,
} from '$lib/schemas.js';
import {Action_Registry} from '$lib/action_registry.js';

/**
 * Centralized definitions for all action specifications.
 * This file serves as the single source of truth for action specifications.
 */

// Define all action specifications with proper typing
export const ping_action_spec = {
  method: 'ping',
  direction: 'client',
  type: 'Service_Action',
  http_method: 'GET',
  auth: null,
  params: Ping_Action_Params,
  response: Ping_Action_Response,
  returns: 'Api_Result<Ping_Action_Response>',
} satisfies Service_Action_Spec;

export const pong_action_spec = {
  method: 'pong',
  direction: 'server',
  type: 'Service_Action',
  http_method: null,
  auth: null,
  params: Pong_Action_Params,
  response: Pong_Action_Response,
  returns: 'Api_Result<Pong_Action_Response>',
} satisfies Service_Action_Spec;

export const load_session_action_spec = {
  method: 'load_session',
  direction: 'client',
  type: 'Service_Action',
  http_method: 'GET',
  auth: null,
  params: Load_Session_Action_Params,
  response: Load_Session_Action_Response,
  returns: 'Api_Result<Load_Session_Action_Response>',
} satisfies Service_Action_Spec;

export const loaded_session_action_spec = {
  method: 'loaded_session',
  direction: 'server',
  type: 'Service_Action',
  http_method: null,
  auth: null,
  params: Loaded_Session_Action_Params,
  response: Loaded_Session_Action_Response,
  returns: 'Api_Result<Loaded_Session_Action_Response>',
} satisfies Service_Action_Spec;

export const filer_change_action_spec = {
  method: 'filer_change',
  direction: 'server',
  type: 'Service_Action',
  http_method: null,
  auth: null,
  params: Filer_Change_Action_Params,
  response: Filer_Change_Action_Response,
  returns: 'Api_Result<Filer_Change_Action_Response>',
} satisfies Service_Action_Spec;

export const update_diskfile_action_spec = {
  method: 'update_diskfile',
  direction: 'client',
  type: 'Client_Action',
  params: Update_Diskfile_Action_Params,
  returns: 'string',
} satisfies Client_Action_Spec;

export const delete_diskfile_action_spec = {
  method: 'delete_diskfile',
  direction: 'client',
  type: 'Client_Action',
  params: Delete_Diskfile_Action_Params,
  returns: 'string',
} satisfies Client_Action_Spec;

export const create_directory_action_spec = {
  method: 'create_directory',
  direction: 'client',
  type: 'Client_Action',
  params: Create_Directory_Action_Params,
  returns: 'string',
} satisfies Client_Action_Spec;

export const send_prompt_action_spec = {
  method: 'send_prompt',
  direction: 'client',
  type: 'Client_Action',
  params: Send_Prompt_Action_Params,
  returns: 'string',
} satisfies Client_Action_Spec;

export const completion_response_action_spec = {
  method: 'completion_response',
  direction: 'server',
  type: 'Service_Action',
  http_method: 'GET',
  auth: null,
  params: Completion_Response_Action_Params,
  response: Completion_Response_Action_Response,
  returns: 'Api_Result<Completion_Response_Action_Response>',
} satisfies Service_Action_Spec;

// Collect all action specs in an array for registry population
export const action_specs: Array<Action_Spec> = [
  ping_action_spec,
  pong_action_spec,
  load_session_action_spec,
  loaded_session_action_spec,
  filer_change_action_spec,
  update_diskfile_action_spec,
  delete_diskfile_action_spec,
  create_directory_action_spec,
  send_prompt_action_spec,
  completion_response_action_spec,
];

/**
 * Create and populate a registry with all defined actions.
 */
export const create_action_registry = (): Action_Registry => {
  const registry = new Action_Registry();
  registry.register_many(action_specs);
  return registry;
};

/**
 * Global singleton registry for convenience in imports.
 * For code that has access to Zzz or Zzz_Server instances, prefer using
 * their .action_registry property instead.
 */
export const global_action_registry = create_action_registry();