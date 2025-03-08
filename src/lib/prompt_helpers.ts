import type {Bit} from '$lib/bit.svelte.js';
import {XML_TAG_NAME_DEFAULT} from '$lib/constants.js';

/**
 * Formats a collection of bits into a prompt string, applying XML tags and attributes where specified.
 */
export const format_prompt_content = (bits: Array<Bit>): string => {
	const enabled_bits = [];

	// First loop: filter enabled bits once to avoid repeated filtering
	for (const bit of bits) {
		if (bit.enabled) {
			enabled_bits.push(bit);
		}
	}

	const formatted_contents = [];

	// Second loop: process each enabled bit
	for (const bit of enabled_bits) {
		const content = bit.content.trim();
		if (!content) continue;

		if (!bit.has_xml_tag) {
			formatted_contents.push(content);
			continue;
		}

		const xml_tag_name = bit.xml_tag_name.trim() || XML_TAG_NAME_DEFAULT;

		// Build attributes string efficiently
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

// Rename current function but keep it for backwards compatibility
export const render_prompt = format_prompt_content;
