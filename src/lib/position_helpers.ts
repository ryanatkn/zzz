// @slop Claude Sonnet 3.7

import {Unreachable_Error} from '@ryanatkn/belt/error.js';

// TODO zod schemas

/**
 * Basic position options for UI elements (cardinal directions).
 */
export type Cardinal_Position = 'left' | 'right' | 'top' | 'bottom';

/**
 * Extended position options including overlay and center.
 */
export type Position = Cardinal_Position | 'overlay' | 'center';

/**
 * Alignment options for positioned elements.
 */
export type Alignment = 'start' | 'center' | 'end';

/**
 * Generates CSS positioning styles for UI elements.
 *
 * @param position - Where to position the element ('left', 'right', etc.)
 * @param align - Alignment along the position edge ('start', 'center', 'end')
 * @param offset - Distance from the position (CSS value)
 * @returns CSS styles as a Record
 */
export const generate_position_styles = (
	position: Position = 'center',
	align: Alignment = 'center',
	offset = '0',
): Record<string, string> => {
	const styles: Record<string, string> = {
		position: 'absolute',
		'z-index': '10',
	};

	// Check if there's an offset to apply
	const has_offset = offset !== '0';

	// Set transform-origin based on position for proper animation direction
	switch (position) {
		case 'left':
			styles.right = has_offset ? `calc(100% + ${offset})` : '100%';
			styles.left = 'auto';
			styles.transform = '';
			styles.top = align === 'center' ? '50%' : align === 'start' ? '0' : 'auto';
			styles.bottom = align === 'end' ? '0' : 'auto';
			styles['transform-origin'] = 'right';
			if (align === 'center') styles.transform = 'translateY(-50%)';
			break;
		case 'right':
			styles.left = has_offset ? `calc(100% + ${offset})` : '100%';
			styles.right = 'auto';
			styles.transform = '';
			styles.top = align === 'center' ? '50%' : align === 'start' ? '0' : 'auto';
			styles.bottom = align === 'end' ? '0' : 'auto';
			styles['transform-origin'] = 'left';
			if (align === 'center') styles.transform = 'translateY(-50%)';
			break;
		case 'top':
			styles.bottom = has_offset ? `calc(100% + ${offset})` : '100%';
			styles.top = 'auto';
			styles.transform = '';
			styles.left = align === 'center' ? '50%' : align === 'start' ? '0' : 'auto';
			styles.right = align === 'end' ? '0' : 'auto';
			styles['transform-origin'] = 'bottom';
			if (align === 'center') styles.transform = 'translateX(-50%)';
			break;
		case 'bottom':
			styles.top = has_offset ? `calc(100% + ${offset})` : '100%';
			styles.bottom = 'auto';
			styles.transform = '';
			styles.left = align === 'center' ? '50%' : align === 'start' ? '0' : 'auto';
			styles.right = align === 'end' ? '0' : 'auto';
			styles['transform-origin'] = 'top';
			if (align === 'center') styles.transform = 'translateX(-50%)';
			break;
		case 'center':
			styles.top = '50%';
			styles.left = '50%';
			styles.transform = 'translate(-50%, -50%)';
			styles['transform-origin'] = 'center';
			break;
		case 'overlay':
			styles.top = '0';
			styles.left = '0';
			styles.width = '100%';
			styles.height = '100%';
			styles['transform-origin'] = 'center';
			break;
		default:
			throw new Unreachable_Error(position);
	}

	return styles;
};
