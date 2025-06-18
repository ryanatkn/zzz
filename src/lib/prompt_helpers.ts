import type {Bit_Type} from '$lib/bit.svelte.js';

/**
 * Formats a collection of bits into a prompt string,
 * applying XML tags and attributes where specified.
 */
export const format_prompt_content = (bits: Array<Bit_Type>): string => {
	const formatted_contents = [];

	for (const bit of bits) {
		if (!bit.enabled) continue;

		const content = bit.content?.trim();
		if (!content) continue;

		if (!bit.has_xml_tag) {
			formatted_contents.push(content);
			continue;
		}

		const xml_tag_name = bit.xml_tag_name.trim() || bit.xml_tag_name_default;

		// Build attributes string
		let attrs = '';
		for (const attr of bit.attributes) {
			// Safely handle key which might be null (in tests) but should be string in production
			const trimmed_key = attr.key?.trim() || ''; // eslint-disable-line @typescript-eslint/no-unnecessary-condition
			if (trimmed_key) {
				if (attr.value === '') {
					// Handle boolean attributes (just the key)
					attrs += ` ${trimmed_key}`;
				} else {
					// Handle regular attributes with values
					attrs += ` ${trimmed_key}="${attr.value}"`;
				}
			}
		}
		formatted_contents.push(`<${xml_tag_name}${attrs}>\n${content}\n</${xml_tag_name}>`);
	}

	return formatted_contents.join('\n\n');
};
