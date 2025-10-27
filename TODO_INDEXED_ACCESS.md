# noUncheckedIndexedAccess Type Errors

This document catalogs remaining type errors from enabling `noUncheckedIndexedAccess` in TypeScript.
These all require proper undefined handling or additional checks.

**Remaining Errors:** ~241 across 42 files

---

## MAY NOT BE SAFE

These need runtime checks or proper undefined handling.

### src/lib/list_helpers.ts:42
```typescript
const item_moved = items[from_index];
if (from_index < to_index) {
    return [
        ...items.slice(0, from_index),
        ...items.slice(from_index + 1, to_index + 1),
        item_moved, // ← item_moved could be undefined
```
**Issue:** Even with validation at line 31, TS doesn't infer safety for `items[from_index]`
**Context:** Function validates indices but TypeScript can't prove the access is safe

### src/lib/list_helpers.ts:50
```typescript
} else {
    return [
        ...items.slice(0, to_index),
        item_moved, // ← item_moved could be undefined
```
**Issue:** Same as line 42

### src/lib/chats.svelte.ts:120
```typescript
if (
    select === true ||
    typeof select === 'number' ||
    (this.#selected_id === null && chats.length > 0)
) {
    void this.select(chats[typeof select === 'number' ? select : 0].id);
```
**Issue:** If `select` is a number, `chats[select]` could be out of bounds
**Context:** No validation that `select` is within `chats` array bounds

### src/lib/chats.svelte.ts:180
```typescript
get_default_template(): Chat_Template {
    return this.chat_templates[0]; // ← Could be undefined if array empty
```
**Issue:** No guarantee `chat_templates` has any elements
**Context:** Returns a non-nullable but accesses potentially empty array

### src/lib/threads.svelte.ts:94
```typescript
if (
    select === true ||
    typeof select === 'number' ||
    (this.selected_id === null && threads.length > 0)
) {
    this.selected_id = threads[typeof select === 'number' ? select : 0].id;
```
**Issue:** If `select` is a number, `threads[select]` could be out of bounds
**Context:** Same pattern as chats.svelte.ts:120

### src/lib/diskfile_tabs.svelte.ts:330
```typescript
const tab_index = this.tab_order.indexOf(tab_id);
if (tab_index !== -1 && tab_index < this.tab_order.length - 1) {
    this.selected_tab_id = this.tab_order[tab_index + 1];
```
**Issue:** Even with bounds check, TS doesn't infer `tab_order[tab_index + 1]` is safe
**Context:** Logic is correct but TypeScript can't prove array access safety

### src/lib/diskfile_tabs.svelte.ts:334
```typescript
else if (tab_index > 0) {
    this.selected_tab_id = this.tab_order[tab_index - 1];
```
**Issue:** Same as line 330

### src/lib/diskfile_history.svelte.ts:51
```typescript
readonly current_entry: History_Entry | null = $derived(
    this.entries.length > 0 ? this.entries[0] : null
```
**Issue:** TypeScript doesn't infer safety despite ternary guard
**Context:** Actually safe due to ternary, but TS flags it

### src/lib/server/security.ts:111
```typescript
const [, protocol, hostname, port = '', path = ''] = parts;
```
**Issue:** Destructuring regex result where elements could be undefined
**Context:** All subsequent uses of `protocol`, `hostname` assume they exist

### src/lib/server/security.ts:119
```typescript
if (hostname.startsWith('[') && hostname.includes('*')) {
```
**Issue:** `hostname` from regex destructuring could be undefined

### src/lib/server/security.ts:124
```typescript
if (!hostname.startsWith('[')) {
    const labels = hostname.split('.');
```
**Issue:** Multiple uses of potentially undefined `hostname`

### src/lib/server/security.ts:125
```typescript
const labels = hostname.split('.');
```
**Issue:** Same

### src/lib/server/security.ts:142
```typescript
regex_pattern += escape_regexp(protocol);
```
**Issue:** `protocol` from regex destructuring could be undefined

### src/lib/server/security.ts:145
```typescript
if (hostname.startsWith('[')) {
```
**Issue:** Same as above

### src/lib/server/security.ts:147
```typescript
regex_pattern += escape_regexp(hostname);
```
**Issue:** Same

### src/lib/server/security.ts:150
```typescript
const labels = hostname.split('.');
```
**Issue:** Same

### src/routes/projects/page_viewmodel.svelte.ts:61
```typescript
const items = p.split('\n- ');
const list_items = items
    .slice(1)
    .map((item) => `<li>${sanitize_html(item)}</li>`)
    .join('');

if (items[0].trim() === '') { // ← Could be undefined
```
**Issue:** No guarantee `items` array has any elements after split

### src/routes/projects/page_viewmodel.svelte.ts:64
```typescript
} else {
    return `<p>${sanitize_html(items[0])}</p><ul>${list_items}</ul>`;
```
**Issue:** Same as line 61

### src/routes/tabs/browser_tabs.svelte.ts:120
```typescript
const tab_to_close = tabs[index];
const was_selected = tab_to_close.selected; // ← tab_to_close could be undefined
```
**Issue:** Even with bounds check at line 118, TS doesn't trust array access
**Context:** Function checks `index >= 0 && index < tabs.length` but access still flagged

### src/routes/tabs/browser_tabs.svelte.ts:123
```typescript
this.recently_closed_tabs.push(tab_to_close);
```
**Issue:** Same variable, multiple uses

### src/routes/tabs/browser_tabs.svelte.ts:125
```typescript
this.items.remove(tab_to_close.id);
```
**Issue:** Same

### src/routes/tabs/browser_tabs.svelte.ts:132
```typescript
const new_index = Math.min(this.ordered_tabs.length - 1, index);
this.ordered_tabs[new_index].selected = true;
```
**Issue:** `ordered_tabs[new_index]` could be undefined if array is empty

### src/routes/tabs/browser_tabs.svelte.ts:156
```typescript
for (let i = 0; i < tabs.length; i++) {
    tabs[i].selected = i === index; // ← TS doesn't trust loop bounds
```
**Issue:** Loop index access not trusted by TypeScript

### src/routes/tabs/browser.svelte.ts:43
```typescript
const selected_tab = this.tabs.ordered_tabs.find((tab) => tab.selected);
if (!selected_tab && this.tabs.ordered_tabs.length > 0) {
    this.tabs.ordered_tabs[0].selected = true; // ← Could be undefined
```
**Issue:** Check `length > 0` should guarantee, but TS doesn't infer safety

### src/lib/Diskfile_Editor_Nav.svelte:70
```typescript
const previous_id = history_stack[0];
// ...
const result = editor.tabs.navigate_to_tab(previous_id);
```
**Issue:** `history_stack[0]` could be undefined even with `can_go_back` check
**Context:** `can_go_back` derived from `history_stack.length > 0` but used later

### src/lib/Diskfile_Editor_Nav.svelte:103
```typescript
const next_id = future_stack[0];
// ...
const result = editor.tabs.navigate_to_tab(next_id);
```
**Issue:** Same pattern as line 70

---

## Summary

All remaining cases fall into these patterns:
1. **Array bounds not inferred:** TypeScript can't prove index is valid despite checks
2. **Regex destructuring:** Capture groups might be undefined
3. **Derived conditions:** Guards separated from usage by derivation boundaries
4. **Loop index access:** TypeScript doesn't trust loop bounds for array access
5. **Empty array edge cases:** No check that array has elements before accessing first element

**Next steps:** Review each "MAY NOT BE SAFE" case to determine:
- Add proper undefined checks/guards
- Use optional chaining `?.`
- Add non-null assertions `!` only if truly safe with comment explaining why
- Refactor to make safety more explicit to TypeScript
