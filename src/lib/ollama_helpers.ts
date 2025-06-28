import {z} from 'zod';

export const OLLAMA_URL = 'http://127.0.0.1:11434'; // TODO config

// Defining these Ollama schemas gives us better error messages and checks,
// and there are currently some mistakes in its types.
// They use `passthrough` to allow additional properties and
// are generally used for DEV-only parsing checks, with the parsed result discarded.

// TODO @many assert type: StatusResponse
export const Ollama_Status_Response = z
	.object({
		status: z.string(),
	})
	.passthrough();
export type Ollama_Status_Response = z.infer<typeof Ollama_Status_Response>;

// TODO @many assert type: ProgressResponse
export const Ollama_Progress_Response = z
	.object({
		status: z.string(),
		digest: z.string().optional(),
		total: z.number().optional(),
		completed: z.number().optional(),
	})
	.passthrough();
export type Ollama_Progress_Response = z.infer<typeof Ollama_Progress_Response>;

// TODO @many assert type: ModelDetails
export const Ollama_Model_Details = z
	.object({
		families: z.array(z.string()),
		family: z.string(),
		format: z.string(),
		parameter_size: z.string(),
		parent_model: z.string(),
		quantization_level: z.string(),
	})
	.passthrough();
export type Ollama_Model_Details = z.infer<typeof Ollama_Model_Details>;

// TODO BLOCK fix this with `ps`, it probably shouldn't return `ListResponse` in Ollama
// TODO @many assert type: ModelResponse
export const Ollama_List_Response_Item = z
	.object({
		details: Ollama_Model_Details.optional(),
		digest: z.string(),
		// TODO @many Ollama bug - is this ever returned? marked as required in the types but not showing up - and is the type a string like elsewhere?
		// expires_at: Date;
		model: z.string(),
		modified_at: z.string(), // TODO @many Ollama bug - says Date but is a string
		name: z.string(),
		size: z.number(),
		// TODO @many Ollama bug - is this ever returned? marked as required in the types but not showing up
		// size_vram: number;
	})
	.passthrough();
export type Ollama_List_Response_Item = z.infer<typeof Ollama_List_Response_Item>;

// TODO @many assert type: ListResponse
export const Ollama_List_Response = z
	.object({
		models: z.array(Ollama_List_Response_Item),
	})
	.passthrough();
export type Ollama_List_Response = z.infer<typeof Ollama_List_Response>;

// TODO @many assert type: ShowResponse
export const Ollama_Show_Response = z
	.object({
		capabilities: z.array(z.string()).optional(),
		details: Ollama_Model_Details.optional(),
		license: z.string().optional(),
		model_info: z.any().optional(), // Map<string, any> in the API
		modelfile: z.string().optional(),
		modified_at: z.string().optional(), // TODO @many Ollama bug - says Date but is a string
		template: z.string().optional(),
		tensors: z.array(z.any()).optional(), // TODO maybe strip? is removed atm in `ollama.svelte.ts`
	})
	.passthrough();
export type Ollama_Show_Response = z.infer<typeof Ollama_Show_Response>;

// TODO @many assert type: ModelResponse -- Ollama is bugged, PS response item has additional fields compared to list
export const Ollama_Ps_Response_Item = z
	.object({
		details: Ollama_Model_Details.optional(),
		digest: z.string(),
		expires_at: z.string(), // ISO date string for when the model will be unloaded
		model: z.string(),
		name: z.string(),
		size: z.number(),
		size_vram: z.number(), // Amount of VRAM used by the model
	})
	.passthrough();
export type Ollama_Ps_Response_Item = z.infer<typeof Ollama_Ps_Response_Item>;

// TODO @many assert type: ListResponse (bugged in Ollama, is different for list vs ps)
export const Ollama_Ps_Response = z
	.object({
		models: z.array(Ollama_Ps_Response_Item),
	})
	.passthrough();
export type Ollama_Ps_Response = z.infer<typeof Ollama_Ps_Response>;

// TODO BLOCK Ollama `ps`
// export const format_ollama_process_info = (models: Array<any>, args?: Array<string>) => {
// 	const data: Array<Array<string>> = [];

// 	for (const m of models) {
// 		if (args?.length === 0 || !args || m.Name.startsWith(args[0] || '')) {
// 			let proc_str: string;

// 			if (m.SizeVRAM === 0) {
// 				proc_str = '100% CPU';
// 			} else if (m.SizeVRAM === m.Size) {
// 				proc_str = '100% GPU';
// 			} else if (m.SizeVRAM > m.Size || m.Size === 0) {
// 				proc_str = 'Unknown';
// 			} else {
// 				const size_cpu = m.Size - m.SizeVRAM;
// 				const cpu_percent = Math.round((size_cpu / m.Size) * 100);
// 				proc_str = `${cpu_percent}%/${100 - cpu_percent}% CPU/GPU`;
// 			}

// 			let until: string;
// 			const delta = Date.now() - new Date(m.ExpiresAt).getTime();
// 			if (delta > 0) {
// 				until = 'Stopping...';
// 			} else {
// 				until = format_human_time(new Date(m.ExpiresAt), 'Never');
// 			}

// 			data.push([m.Name, m.Digest.slice(0, 12), format_human_bytes(m.Size), proc_str, until]);
// 		}
// 	}

// 	return data;
// };

// export const format_human_bytes = (bytes: number): string => {
// 	const units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
// 	let size = bytes;
// 	let unit_index = 0;

// 	while (size >= 1024 && unit_index < units.length - 1) {
// 		size /= 1024;
// 		unit_index++;
// 	}

// 	return `${size.toFixed(1)} ${units[unit_index]}`;
// };

// export const format_human_time = (date: Date, never_text: string = 'Never'): string => {
// 	if (!date || date.getTime() === 0) {
// 		return never_text;
// 	}

// 	const now = Date.now();
// 	const target = date.getTime();
// 	const delta = target - now;

// 	if (delta < 0) {
// 		return 'Expired';
// 	}

// 	const seconds = Math.floor(delta / 1000);
// 	const minutes = Math.floor(seconds / 60);
// 	const hours = Math.floor(minutes / 60);
// 	const days = Math.floor(hours / 24);

// 	if (days > 0) {
// 		return `${days}d ${hours % 24}h`;
// 	} else if (hours > 0) {
// 		return `${hours}h ${minutes % 60}m`;
// 	} else if (minutes > 0) {
// 		return `${minutes}m ${seconds % 60}s`;
// 	} else {
// 		return `${seconds}s`;
// 	}
// };
