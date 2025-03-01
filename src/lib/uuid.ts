import {z} from 'zod';

export const Uuid_Base = z.string().uuid().brand('Uuid');
export type Uuid_Base = z.infer<typeof Uuid_Base>;

export const Uuid = Uuid_Base.default(() => globalThis.crypto.randomUUID());
export type Uuid = z.infer<typeof Uuid>;
