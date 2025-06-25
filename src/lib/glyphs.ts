import type {Action_Method} from '$lib/action_metatypes.js';
import type {Action_Kind} from '$lib/action_types.js';

export const GLYPH_UNKNOWN = '⁇'; // ⍰
export const GLYPH_IMPORTANT = '⁈';
export const GLYPH_INFO = 'ⓘ';

export const GLYPH_ADD = '✛'; // + ✚ ✛ ✜
export const GLYPH_REMOVE = '⨉'; // TODO REMOVE and DELETE are currently the same but shouldn't be, maybe DELETE is a trash can?
export const GLYPH_DELETE = '⌧'; // 🗑 ⨉ ✕ 🗙 ⤫ ⤬ ✗ ✘ ⌧ ⨂ ⊝
export const GLYPH_CLEAR = '⌫';
export const GLYPH_RESTORE = '⤻';
export const GLYPH_CANCEL = '⦸';
export const GLYPH_DRAG = '≡'; // ≡ ☰ ☷
export const GLYPH_COPY = '⧉';
export const GLYPH_PASTE = '⎌'; // ⧈ ⎗ ⎘ ⎙
export const GLYPH_RESET = '⤺';
export const GLYPH_REFRESH = '⟳'; // ↻ ⟳
export const GLYPH_CONNECT = '⭍'; // ⨁
export const GLYPH_DISCONNECT = '⊝';
export const GLYPH_RETRY = '↺'; // ⟲'; // ⟲ ⟳ ⤾ ⤼ ↻
export const GLYPH_PLACEHOLDER = '↳';

export const GLYPH_CHECKMARK = '✓'; // ✓ ✔ ✗ ✖ ✕ ✘ ☑ ⍻

export const GLYPH_DOWNLOAD = '⭳'; // ⭳ ⥥ ⤓ ⇩
export const GLYPH_ERROR = '⨂'; // ⁉ ‼ ‽ ⸮ ⸘ ⚠
export const GLYPH_CHEVRON_UP = '⮝'; // ⮝ ⯅ ˄ ∧ ⌃ ▴ ▵ ▲
export const GLYPH_CHEVRON_RIGHT = '⮞'; // ⮞ ❯ ▸ ⭢ ›
export const GLYPH_CHEVRON_DOWN = '⮟'; // ⮟ ⌄ ˅ ∨
export const GLYPH_CHEVRON_LEFT = '⮜'; // ⮜ ⯇ ˂ ‹ ◁ ▹ ◂ ◃ ◀
export const GLYPH_DOUBLE_CHEVRON_LEFT = '«'; // « ⪡ ⪛ ⟪ ⟨ ≪ ⯇ ⭠ ⇇ ⇚ ⇦
export const GLYPH_DOUBLE_CHEVRON_RIGHT = '»'; // » ⪢ ⪜ ⟫ ⟩ ≫ ⯈ ⭢ ⇉ ⇛ ⇨

// ⤉ ⤈ ⤣ ⤤ ⤥ ⤦

export const GLYPH_EDIT = '✎'; // ✎ ✏ ✐ ✑ ✒
// export const GLYPH_MOVE = '⧈';
// ⊞ ⧉ ⧈
// ⎗ ⎗ ⎘ ⌖ ⌶ ⎙
// ⎘ ⎘ ⎌ ⌫ ⊘ ⦸
// ⤺ ⤻ ⤼ ⤽ ⤾ ⤿
export const GLYPH_SORT = '⇅'; // ⇅ ⇵ ⮃ ⮁

export const GLYPH_BACKEND = '🜢';
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
export const GLYPH_VIEW = '⍜'; // ⦿ ⦾ ⦽ ⦼
export const GLYPH_PREVIEW = '⦾'; // ⦾
export const GLYPH_LOG = '⎙'; // ⎙ ⏚ ⌺ ⏏ ⍜
export const GLYPH_TAB = '⛶';
export const GLYPH_PROJECT = '⌬';
export const GLYPH_CAPABILITY = '⧰'; // ⌁
export const GLYPH_SETTINGS = '⛮'; // ⛭  ⚙  ⛮  ⛯ ⛣
export const GLYPH_DOMAIN = '⟡'; // ⟡ ⏥
export const GLYPH_PAGE = '⌺'; // ⌺ ⎚

export const GLYPH_IDEA = '⌆'; // TODO use

export const GLYPH_PING = '⥀';
export const GLYPH_HEARTBEAT = '∽'; // ∿ ≋ 〰 ∽ ~
export const GLYPH_RESPONSE = '⮑';
export const GLYPH_SESSION = '⏣';

export const GLYPH_ACTION_TYPE_LOCAL_CALL = '⤳'; // ⤤ ⤳
export const GLYPH_ACTION_TYPE_REMOTE_NOTIFICATION = '⥙'; // ⤷
export const GLYPH_ACTION_TYPE_REQUEST_RESPONSE = '⥮'; // ⤨ ⥮ ⥯

export const GLYPH_EXTERNAL_LINK = '🡵';

export const GLYPH_ARROW_RIGHT = '→'; // → ➝ ➞ ➜ ➡ ⟶ ⭢ ⤷ ⤳ ⥅ ⮕ ⭆ ⭆ ⭈ ⤞ ⤠
export const GLYPH_ARROW_LEFT = '←'; // ← ⭠

export const get_glyph_for_action_method = (method: Action_Method): string => {
	switch (method) {
		case 'ping':
			return GLYPH_PING;
		case 'submit_completion':
			return GLYPH_RESPONSE;
		case 'load_session':
			return GLYPH_SESSION;
		case 'update_diskfile':
		case 'delete_diskfile':
		case 'filer_change':
			return GLYPH_FILE;
		default:
			return GLYPH_ACTION;
	}
};

export const get_glyph_for_action_kind = (kind: Action_Kind): string => {
	switch (kind) {
		case 'local_call':
			return GLYPH_ACTION_TYPE_LOCAL_CALL;
		case 'request_response':
			return GLYPH_ACTION_TYPE_REQUEST_RESPONSE;
		case 'remote_notification':
			return GLYPH_ACTION_TYPE_REMOTE_NOTIFICATION;
		default:
			return GLYPH_ACTION;
	}
};

// ⭍ ⏻
//⥘ ⥙ ⇅ ⇵ ⇳ ⇊ ⇈  ⮃
// ⬎⤣

// ⎗ ⎘

// ⊞
// ⊟
// ⍈
// ⟁
// ⍟ ✴ ✧

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

// ⭉ ⭊ ⤟⮭ ⎋

// —
// –
