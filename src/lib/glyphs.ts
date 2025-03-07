export const GLYPH_REMOVE = '⨉'; // ⨉ ✕ 🗙 ⤫ ⤬
export const GLYPH_DRAG = '≡'; // ≡ ☰ ☷
export const GLYPH_COPY = '⧉';
export const GLYPH_PASTE = '⎌'; // ⧈ ⎗ ⎘ ⎙
// export const GLYPH_EDIT = '✎'; // ✎ ✏ ✐ ✑ ✒
// export const GLYPH_ADD = '⊞'; // ⊞ ⧉ ⧈
// export const GLYPH_MOVE = '⧈';

export const GLYPH_CHAT = '⌸';
export const GLYPH_TAPE = '☷';
export const GLYPH_FILE = '⧈'; // ⏚ ⧈ ⊞ ⌺ ▤
export const GLYPH_PROMPT = '⌇'; // ⌇ ⍋  ⌭
export const GLYPH_BIT = '┊'; //  ┊ ┋ ╎ ╏
export const GLYPH_PROVIDER = '⨕';
export const GLYPH_MODEL = '⊛'; // ⨹ ⨺ ⊛
export const GLYPH_MESSAGE = '⍾';
export const GLYPH_CAPABILITY = '⧰'; // ⌁
export const GLYPH_SETTINGS = '⛮'; // ⛭  ⚙  ⛮  ⛯ ⛣

export const GLYPH_ECHO = '⥀';
export const GLYPH_RESPONSE = '⮑';
export const GLYPH_SESSION = '⏣';

// Direction icons
export const GLYPH_DIRECTION_CLIENT = '⥘'; // ⤤ ⤳
export const GLYPH_DIRECTION_SERVER = '⥙'; // ⤷
export const GLYPH_DIRECTION_BOTH = '⤨';

export const get_icon_for_message_type = (type: string): string => {
	switch (type) {
		case 'echo':
			return GLYPH_ECHO;
		case 'send_prompt':
			return GLYPH_PROMPT;
		case 'completion_response':
			return GLYPH_RESPONSE;
		case 'load_session':
		case 'loaded_session':
			return GLYPH_SESSION;
		case 'update_diskfile':
		case 'delete_diskfile':
		case 'filer_change':
			return GLYPH_FILE;
		default:
			return GLYPH_MESSAGE;
	}
};

export const get_direction_icon = (direction: string): string => {
	switch (direction) {
		case 'client':
			return GLYPH_DIRECTION_CLIENT;
		case 'server':
			return GLYPH_DIRECTION_SERVER;
		case 'both':
			return GLYPH_DIRECTION_BOTH;
		default:
			return '?';
	}
};

// ⭍
//⥘ ⥙
// ⬎⤣

// ⎗ ⎘

// ⇇ ⇉  maybe use these for deps?

// ⏛
// ☳ ☷
// ≣
// ⠿
// TODO GLYPH_TAPE
// ⧛
// ☁

// ⚟

// ⌬ ⬡ ⬢ ⏣

// ⍝

// 🜢

// ⨖

// ⌾
// ⌓
// ⍜
// ⍖
// ⍤

// ⍾

// ⌯
// ⌗
// ⎍

// ⨳

// ⎕
// ⌘

// ⌥
// ⌤

// ⏀
// ⏁

// ⎎
// 🗎  🗏  🗀  🗁  🗂  🗃  🗄  ❏  ❐  ▣  ▢  □  ⧉  ⧈

// ·
// •
// ․
// ‥
// …
// ⋮
// ⋯
// ⋰
// ⋱
// ⁚
// ⁝
// ⁘
// ⁙
// ⁖
// ⁛
// ⁞
// ⸪
// ⸫
// ⸬
// ⋗
// ∴
// ∵
// ∷
// ⁂
// ⨀
// ⁜
// ․
// ⠂
// ⠃
// ⠒
// ⠤
// ⋄
// ⨪
// ⨯
// ⦙
// ∙
// ⦁
// ◦
// ◉
// ◌
// ◍
// ◎
// ⊙
// ⨁
// ⊚
// ◌̣
// ◌̇
// ⊓̇
// ∴
// ⟐
// ⋮
// ⸭
// ⟇
// ⏏
// ⌑
// ⍩
// ⌂
// ⌘
// ▄
// ▪
