/**
 * Server info file utilities (server.json)
 *
 * server.json lives at `{zzz_dir}/run/server.json` and tracks the running server.
 * Written on startup, removed on clean shutdown.
 * Following the private_fuz daemon.rs pattern.
 */
import * as fs from 'node:fs/promises';
import {join, dirname} from 'node:path';
import {z} from 'zod';
import {process_is_pid_running} from '@fuzdev/fuz_util/process.js';

import {ZZZ_DIR_RUN} from '../constants.js';

/** Current server.json schema version */
const SERVER_INFO_VERSION = 1;

/** File name for server info */
const SERVER_INFO_FILE = 'server.json';

/**
 * Information about the running server, stored in server.json
 */
export const Server_Info = z.strictObject({
	/** Schema version (must be 1) */
	version: z.number(),
	/** Server process ID */
	pid: z.number(),
	/** Port the server is listening on */
	port: z.number(),
	/** ISO timestamp when server started */
	started: z.string(),
	/** Package version of zzz */
	zzz_version: z.string(),
});
export type Server_Info = z.infer<typeof Server_Info>;

/**
 * Get path to server.json
 */
export const server_info_get_path = (zzz_dir: string): string => {
	return join(zzz_dir, ZZZ_DIR_RUN, SERVER_INFO_FILE);
};

/**
 * Read server info from server.json
 *
 * Returns `null` if the file doesn't exist or is invalid.
 * Deletes the file if it's corrupt or has wrong version.
 */
export const server_info_read = async (zzz_dir: string): Promise<Server_Info | null> => {
	const path = server_info_get_path(zzz_dir);

	try {
		const content = await fs.readFile(path, 'utf8');
		const json = JSON.parse(content);
		const result = Server_Info.safeParse(json);

		if (!result.success) {
			console.warn('[server_info] corrupt server.json, deleting:', result.error.message);
			await fs.rm(path, {force: true});
			return null;
		}

		if (result.data.version !== SERVER_INFO_VERSION) {
			console.warn(
				`[server_info] version mismatch (expected ${SERVER_INFO_VERSION}, got ${result.data.version}), deleting`,
			);
			await fs.rm(path, {force: true});
			return null;
		}

		return result.data;
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code === 'ENOENT') {
			return null;
		}
		throw error;
	}
};

/**
 * Check if there's a stale server.json (process no longer running)
 */
export const server_info_check_stale = async (zzz_dir: string): Promise<Server_Info | null> => {
	const info = await server_info_read(zzz_dir);
	if (!info) return null;

	if (!process_is_pid_running(info.pid)) {
		console.warn(`[server_info] stale server.json (pid ${info.pid} not running), deleting`);
		await fs.rm(server_info_get_path(zzz_dir), {force: true});
		return null;
	}

	return info;
};

export interface Server_Info_Write_Options {
	zzz_dir: string;
	port: number;
	zzz_version: string;
}

/**
 * Write server info to server.json atomically
 *
 * Uses write-to-temp + fsync + rename for atomicity.
 */
export const server_info_write = async (options: Server_Info_Write_Options): Promise<string> => {
	const {zzz_dir, port, zzz_version} = options;
	const path = server_info_get_path(zzz_dir);
	const temp_path = path + '.tmp';
	const dir = dirname(path);

	// Ensure run directory exists
	await fs.mkdir(dir, {recursive: true});

	const info: Server_Info = {
		version: SERVER_INFO_VERSION,
		pid: process.pid,
		port,
		started: new Date().toISOString(),
		zzz_version,
	};

	const json = JSON.stringify(info, null, '\t');

	// Write to temp file
	const handle = await fs.open(temp_path, 'w');
	try {
		await handle.writeFile(json, 'utf8');
		await handle.sync(); // fsync for durability
	} finally {
		await handle.close();
	}

	// Atomic rename
	await fs.rename(temp_path, path);

	console.log(`[server_info] wrote ${path}`);
	return path;
};

/**
 * Remove server info file (idempotent - ignores if already removed)
 */
export const server_info_remove = async (zzz_dir: string): Promise<void> => {
	const path = server_info_get_path(zzz_dir);
	try {
		await fs.rm(path, {force: true});
		console.log(`[server_info] removed ${path}`);
	} catch (error) {
		if ((error as NodeJS.ErrnoException).code !== 'ENOENT') {
			throw error;
		}
	}
};
