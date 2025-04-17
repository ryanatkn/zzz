export const GLYPH_UNKNOWN = '⁇'; // ⍰
export const GLYPH_IMPORTANT = '⁈';
export const GLYPH_INFO = 'ⓘ';

export const GLYPH_ADD = '✛'; // + ✚ ✛ ✜
export const GLYPH_REMOVE = '⨉'; // TODO REMOVE and DELETE are currently the same but shouldn't be, maybe DELETE is a trash can?
export const GLYPH_DELETE = '⨉'; // ⨉ ✕ 🗙 ⤫ ⤬ ✗ ✘ ⌧ ⨂ ⊝
export const GLYPH_CLEAR = '⌫';
export const GLYPH_RESTORE = '⤻';
export const GLYPH_CANCEL = '⦸';
export const GLYPH_DRAG = '≡'; // ≡ ☰ ☷
export const GLYPH_COPY = '⧉';
export const GLYPH_PASTE = '⎌'; // ⧈ ⎗ ⎘ ⎙
export const GLYPH_RESET = '⤺';
export const GLYPH_REFRESH = '⟳'; // ↻ ⟳
export const GLYPH_CONNECT = '⭍'; // ⨁
export const GLYPH_DISCONNECT = '⨂';
export const GLYPH_RETRY = '↺'; // ⟲'; // ⟲ ⟳ ⤾ ⤼ ↻
export const GLYPH_PLACEHOLDER = '↳';

export const GLYPH_CHECKMARK = '✓'; // ✓ ✔ ✗ ✖ ✕ ✘

export const GLYPH_EDIT = '✎'; // ✎ ✏ ✐ ✑ ✒
// export const GLYPH_MOVE = '⧈';
// ⊞ ⧉ ⧈
// ⎗ ⎗ ⎘ ⌖ ⌶ ⎙
// ⎘ ⎘ ⎌ ⌫ ⊘ ⦸
// ⤺ ⤻ ⤼ ⤽ ⤾ ⤿
export const GLYPH_SORT = '⇅'; // ⇅ ⇵ ⥮ ⮃

export const GLYPH_SERVER = '🜢';
export const GLYPH_CHAT = '⌸';
export const GLYPH_TAPE = '☷';
export const GLYPH_STRIP = '⎍'; // ⎎ ⎍
export const GLYPH_FILE = '⧈'; // ⏚ ⧈ ⊞ ⌺ ▤
export const GLYPH_LIST = '▤'; //
export const GLYPH_DIRECTORY = '▦'; // 🗁 ▦ ▥ 🗀
export const GLYPH_CREATE_FILE = '🗎';
export const GLYPH_CREATE_FOLDER = '🗁';
export const GLYPH_PROMPT = '⌇'; // ⌇ ⍋  ⌭
export const GLYPH_BIT = '┊'; //  ┊ ┋ ╎ ╏
export const GLYPH_PROVIDER = '⨕';
export const GLYPH_MODEL = '⊛'; // ⨹ ⨺ ⊛
export const GLYPH_ACTION = '⍾';
export const GLYPH_VIEW = '⍜'; // ⦿ ⦾ ⦽ ⦼ ◉
export const GLYPH_LOG = '⎙'; // ⎙ ⏚ ⌺ ⏏ ⍜
export const GLYPH_TAB = '⛶';
export const GLYPH_SITE = '⌬';
export const GLYPH_CAPABILITY = '⧰'; // ⌁
export const GLYPH_SETTINGS = '⛮'; // ⛭  ⚙  ⛮  ⛯ ⛣
export const GLYPH_DOMAIN = '⟡'; // ⟡ ⏥
export const GLYPH_PAGE = '⌺'; // ⌺ ⎚

export const GLYPH_ECHO = '⥀';
export const GLYPH_HEARTBEAT = '∽'; // ∿ ≋ 〰 ∽ ~
export const GLYPH_RESPONSE = '⮑';
export const GLYPH_SESSION = '⏣';

export const GLYPH_DIRECTION_CLIENT = '⥘'; // ⤤ ⤳
export const GLYPH_DIRECTION_SERVER = '⥙'; // ⤷
export const GLYPH_DIRECTION_BOTH = '⤨';

export const GLYPH_EXTERNAL_LINK = '🡵';

export const GLYPH_ARROW_RIGHT = '→'; // → ➝ ➞ ➜ ➡ ⟶ ⭢ ⤷ ⤳ ⥅ ⮕ ⭆ ⮞ ⭆ ⭈ ⤞ ⤠
export const GLYPH_ARROW_LEFT = '←'; // ← ⭠

export const get_icon_for_action_type = (type: string): string => {
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
			return GLYPH_ACTION;
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
			return GLYPH_UNKNOWN;
	}
};

// ⭍ ⏻
//⥘ ⥙
// ⬎⤣

// ⎗ ⎘

// ⊞
// ⊟
// ⟁

// ⇇ ⇉  maybe use these for deps?

// ⛶
// ⏛
// ☳ ☷
// ≣
// ⠿
// TODO GLYPH_TAPE
// ⧛

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

// ⮟

// ⭉ ⭊ ⤟⮭ ⎋

// —
// –
