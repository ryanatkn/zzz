import {test, expect} from 'vitest';

import {generate_position_styles, type Position, type Alignment} from '$lib/position_helpers.js';

// Helper to check common properties that should be on all position styles
const check_common_styles = (styles: Record<string, string>) => {
	expect(styles.position).toBe('absolute');
	expect(styles['z-index']).toBe('10');
};

// Helper to check expected style value, considering browser normalization
const check_style_value = (styles: Record<string, string>, prop: string, expected: string) => {
	if (
		(expected === 'auto' && styles[prop] === '') ||
		(expected === '0' && styles[prop] === '0px')
	) {
		return true;
	}
	expect(styles[prop]).toBe(expected);
	return true; // Added return statement to fix type error
};

test('generate_position_styles - left position with different alignments', () => {
	// Left + Start
	let styles = generate_position_styles('left', 'start');
	check_common_styles(styles);
	check_style_value(styles, 'right', '100%');
	check_style_value(styles, 'left', 'auto');
	check_style_value(styles, 'top', '0');
	check_style_value(styles, 'bottom', 'auto');
	expect(styles['transform-origin']).toBe('right');
	expect(styles.transform || '').not.toContain('translate');

	// Left + Center
	styles = generate_position_styles('left', 'center');
	check_common_styles(styles);
	check_style_value(styles, 'right', '100%');
	check_style_value(styles, 'left', 'auto');
	check_style_value(styles, 'top', '50%');
	expect(styles.transform).toBe('translateY(-50%)');

	// Left + End
	styles = generate_position_styles('left', 'end');
	check_common_styles(styles);
	check_style_value(styles, 'right', '100%');
	check_style_value(styles, 'left', 'auto');
	check_style_value(styles, 'bottom', '0');
	check_style_value(styles, 'top', 'auto');
});

test('generate_position_styles - right position with different alignments', () => {
	// Right + Start
	let styles = generate_position_styles('right', 'start');
	check_common_styles(styles);
	check_style_value(styles, 'left', '100%');
	check_style_value(styles, 'right', 'auto');
	check_style_value(styles, 'top', '0');
	check_style_value(styles, 'bottom', 'auto');
	expect(styles['transform-origin']).toBe('left');

	// Right + Center
	styles = generate_position_styles('right', 'center');
	check_common_styles(styles);
	check_style_value(styles, 'left', '100%');
	check_style_value(styles, 'right', 'auto');
	check_style_value(styles, 'top', '50%');
	expect(styles.transform).toBe('translateY(-50%)');

	// Right + End
	styles = generate_position_styles('right', 'end');
	check_common_styles(styles);
	check_style_value(styles, 'left', '100%');
	check_style_value(styles, 'right', 'auto');
	check_style_value(styles, 'bottom', '0');
	check_style_value(styles, 'top', 'auto');
});

test('generate_position_styles - top position with different alignments', () => {
	// Top + Start
	let styles = generate_position_styles('top', 'start');
	check_common_styles(styles);
	check_style_value(styles, 'bottom', '100%');
	check_style_value(styles, 'top', 'auto');
	check_style_value(styles, 'left', '0');
	check_style_value(styles, 'right', 'auto');
	expect(styles['transform-origin']).toBe('bottom');

	// Top + Center
	styles = generate_position_styles('top', 'center');
	check_common_styles(styles);
	check_style_value(styles, 'bottom', '100%');
	check_style_value(styles, 'top', 'auto');
	check_style_value(styles, 'left', '50%');
	expect(styles.transform).toBe('translateX(-50%)');

	// Top + End
	styles = generate_position_styles('top', 'end');
	check_common_styles(styles);
	check_style_value(styles, 'bottom', '100%');
	check_style_value(styles, 'top', 'auto');
	check_style_value(styles, 'left', 'auto');
	check_style_value(styles, 'right', '0');
});

test('generate_position_styles - bottom position with different alignments', () => {
	// Bottom + Start
	let styles = generate_position_styles('bottom', 'start');
	check_common_styles(styles);
	check_style_value(styles, 'top', '100%');
	check_style_value(styles, 'bottom', 'auto');
	check_style_value(styles, 'left', '0');
	check_style_value(styles, 'right', 'auto');
	expect(styles['transform-origin']).toBe('top');

	// Bottom + Center
	styles = generate_position_styles('bottom', 'center');
	check_common_styles(styles);
	check_style_value(styles, 'top', '100%');
	check_style_value(styles, 'bottom', 'auto');
	check_style_value(styles, 'left', '50%');
	expect(styles.transform).toBe('translateX(-50%)');

	// Bottom + End
	styles = generate_position_styles('bottom', 'end');
	check_common_styles(styles);
	check_style_value(styles, 'top', '100%');
	check_style_value(styles, 'bottom', 'auto');
	check_style_value(styles, 'left', 'auto');
	check_style_value(styles, 'right', '0');
});

test('generate_position_styles - with offsets', () => {
	// Test left with offset
	let styles = generate_position_styles('left', 'start', '10px');
	expect(styles.right).toBe('calc(100% + 10px)');

	// Test right with offset
	styles = generate_position_styles('right', 'start', '10px');
	expect(styles.left).toBe('calc(100% + 10px)');

	// Test top with offset
	styles = generate_position_styles('top', 'start', '10px');
	expect(styles.bottom).toBe('calc(100% + 10px)');

	// Test bottom with offset
	styles = generate_position_styles('bottom', 'start', '10px');
	expect(styles.top).toBe('calc(100% + 10px)');

	// Test with different offset values
	styles = generate_position_styles('left', 'start', '5rem');
	expect(styles.right).toBe('calc(100% + 5rem)');

	// Test with negative offset
	styles = generate_position_styles('left', 'start', '-8px');
	expect(styles.right).toBe('calc(100% + -8px)');
});

test('generate_position_styles - center position', () => {
	const styles = generate_position_styles('center');
	check_common_styles(styles);
	check_style_value(styles, 'top', '50%');
	check_style_value(styles, 'left', '50%');
	expect(styles.transform).toBe('translate(-50%, -50%)');
	expect(styles['transform-origin']).toBe('center');

	// Center ignores alignment and offset
	const styles_with_params = generate_position_styles('center', 'start', '10px');
	check_style_value(styles_with_params, 'top', '50%');
	check_style_value(styles_with_params, 'left', '50%');
	expect(styles_with_params.transform).toBe('translate(-50%, -50%)');
});

test('generate_position_styles - overlay position', () => {
	const styles = generate_position_styles('overlay');
	check_common_styles(styles);
	check_style_value(styles, 'top', '0');
	check_style_value(styles, 'left', '0');
	expect(styles.width).toBe('100%');
	expect(styles.height).toBe('100%');
	expect(styles['transform-origin']).toBe('center');

	// Overlay ignores alignment and offset
	const styles_with_params = generate_position_styles('overlay', 'start', '10px');
	check_style_value(styles_with_params, 'top', '0');
	check_style_value(styles_with_params, 'left', '0');
	expect(styles_with_params.width).toBe('100%');
	expect(styles_with_params.height).toBe('100%');
});

test('generate_position_styles - default parameters', () => {
	// No parameters (uses defaults)
	const styles = generate_position_styles();
	check_common_styles(styles);
	check_style_value(styles, 'top', '50%');
	check_style_value(styles, 'left', '50%');
	expect(styles.transform).toBe('translate(-50%, -50%)');
	expect(styles['transform-origin']).toBe('center');
});

test('generate_position_styles - throws on invalid position', () => {
	// @ts-expect-error - Testing invalid position
	expect(() => generate_position_styles('invalid')).toThrow();
});

// Test all possible combinations systematically
test('generate_position_styles - all position/alignment combinations work', () => {
	const positions: Array<Position> = ['left', 'right', 'top', 'bottom', 'center', 'overlay'];
	const alignments: Array<Alignment> = ['start', 'center', 'end'];
	const offsets = ['0', '10px'];

	for (const position of positions) {
		for (const align of alignments) {
			for (const offset of offsets) {
				expect(() => {
					const styles = generate_position_styles(position, align, offset);
					// Basic validation that we got a style object back
					expect(typeof styles).toBe('object');
					expect(styles.position).toBe('absolute');
				}).not.toThrow();
			}
		}
	}
});
