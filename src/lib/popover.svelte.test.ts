// @vitest-environment jsdom

import {describe, test, expect, vi, beforeEach, afterEach} from 'vitest';

import {Popover} from '$lib/popover.svelte.js';
import type {Position} from '$lib/position_helpers.js';
import type {ActionReturn} from 'svelte/action';

// Helper functions for testing
const create_elements = (): {
	container: HTMLElement;
	trigger: HTMLElement;
	content: HTMLElement;
	body: HTMLElement;
} => {
	const container = document.createElement('div');
	container.classList.add('container');

	const trigger = document.createElement('button');
	trigger.textContent = 'Trigger Button';
	container.appendChild(trigger);

	const content = document.createElement('div');
	content.textContent = 'Popover Content';
	container.appendChild(content);

	document.body.appendChild(container);

	return {container, trigger, content, body: document.body};
};

const create_mock_event = (type: string, target?: HTMLElement): Event => {
	const event = new Event(type, {bubbles: true, cancelable: true});
	if (target) {
		Object.defineProperty(event, 'target', {value: target});
	}
	return event;
};

// Helper for checking style values that handles browser normalization
const check_style = (element: HTMLElement, prop: string, expected: string): void => {
	const value = element.style.getPropertyValue(prop);
	// Handle empty string vs 'auto' case
	if (expected === 'auto' && value === '') {
		return;
	}
	// Handle '0' vs '0px' case
	if (expected === '0' && value === '0px') {
		return;
	}
	expect(value).toBe(expected);
};

describe('Popover', () => {
	// Define shared variables
	let elements: ReturnType<typeof create_elements>;
	let popover: Popover;
	let cleanup_actions: Array<() => void>;

	beforeEach(() => {
		elements = create_elements();
		popover = new Popover();
		cleanup_actions = [];
	});

	afterEach(() => {
		// Clean up all actions registered during the test
		for (const cleanup of cleanup_actions) {
			cleanup();
		}

		// Clean up DOM after each test
		if (elements.body.contains(elements.container)) {
			elements.body.removeChild(elements.container);
		}
	});

	// Helper to register actions for automatic cleanup
	const register_action = <T extends ActionReturn<any, any>>(action: T | void): T => {
		if (!action) throw Error('Expected action to be defined');
		if (action.destroy) {
			cleanup_actions.push(action.destroy);
		}
		return action;
	};

	describe('constructor', () => {
		test('creates with default values', () => {
			expect(popover.visible).toBe(false);
			expect(popover.position).toBe('bottom');
			expect(popover.align).toBe('center');
			expect(popover.offset).toBe('0');
			expect(popover.disable_outside_click).toBe(false);
			expect(popover.popover_class).toBe('');
		});

		test('accepts custom parameters', () => {
			const onshow = vi.fn();
			const onhide = vi.fn();

			popover = new Popover({
				position: 'top',
				align: 'start',
				offset: '16px',
				disable_outside_click: true,
				popover_class: 'test-class',
				onshow,
				onhide,
			});

			expect(popover.position).toBe('top');
			expect(popover.align).toBe('start');
			expect(popover.offset).toBe('16px');
			expect(popover.disable_outside_click).toBe(true);
			expect(popover.popover_class).toBe('test-class');
		});
	});

	describe('visibility methods', () => {
		test('show() makes popover visible and calls onshow callback', () => {
			const onshow = vi.fn();
			popover = new Popover({onshow});

			expect(popover.visible).toBe(false);

			popover.show();

			expect(popover.visible).toBe(true);
			expect(onshow).toHaveBeenCalledTimes(1);

			// Showing when already visible should not call onshow again
			popover.show();
			expect(onshow).toHaveBeenCalledTimes(1);
		});

		test('hide() hides popover and calls onhide callback', () => {
			const onhide = vi.fn();
			popover = new Popover({onhide});

			// Set visible manually first
			popover.visible = true;

			popover.hide();

			expect(popover.visible).toBe(false);
			expect(onhide).toHaveBeenCalledTimes(1);

			// Hiding when already hidden should not call onhide again
			popover.hide();
			expect(onhide).toHaveBeenCalledTimes(1);
		});

		test('toggle() toggles visibility state', () => {
			const onshow = vi.fn();
			const onhide = vi.fn();
			popover = new Popover({onshow, onhide});

			// Initially hidden
			expect(popover.visible).toBe(false);

			// First toggle should show
			popover.toggle();
			expect(popover.visible).toBe(true);
			expect(onshow).toHaveBeenCalledTimes(1);
			expect(onhide).not.toHaveBeenCalled();

			// Second toggle should hide
			popover.toggle();
			expect(popover.visible).toBe(false);
			expect(onshow).toHaveBeenCalledTimes(1);
			expect(onhide).toHaveBeenCalledTimes(1);
		});
	});

	describe('update()', () => {
		test('changes configuration completely', () => {
			popover = new Popover({
				position: 'left',
				align: 'end',
				popover_class: 'old-class',
			});

			const new_onshow = vi.fn();
			const new_onhide = vi.fn();

			// Update with new parameters
			popover.update({
				position: 'right',
				align: 'start',
				offset: '20px',
				disable_outside_click: true,
				popover_class: 'new-class',
				onshow: new_onshow,
				onhide: new_onhide,
			});

			expect(popover.position).toBe('right');
			expect(popover.align).toBe('start');
			expect(popover.offset).toBe('20px');
			expect(popover.disable_outside_click).toBe(true);
			expect(popover.popover_class).toBe('new-class');

			// Test the new callbacks work
			popover.show();
			expect(new_onshow).toHaveBeenCalled();

			popover.hide();
			expect(new_onhide).toHaveBeenCalled();
		});

		test('handles partial updates correctly', () => {
			popover = new Popover({
				position: 'left',
				align: 'end',
				offset: '10px',
			});

			// Update only some parameters
			popover.update({
				position: 'right',
				// Align should remain 'end'
				// Offset should remain '10px'
			});

			expect(popover.position).toBe('right');
			expect(popover.align).toBe('end');
			expect(popover.offset).toBe('10px');
		});
	});

	describe('actions', () => {
		describe('trigger action', () => {
			test('attaches click handler to show/hide popover', () => {
				const {trigger} = elements;

				// Set up trigger action
				register_action(popover.trigger(trigger));

				// Initial state
				expect(popover.visible).toBe(false);

				// Simulate click to show
				trigger.click();
				expect(popover.visible).toBe(true);

				// Simulate another click to hide
				trigger.click();
				expect(popover.visible).toBe(false);
			});

			test('accepts and updates parameters', () => {
				const {trigger} = elements;

				// Set up trigger action with params
				const action_result = register_action(
					popover.trigger(trigger, {
						position: 'right',
						align: 'start',
					}),
				);

				// Check params were applied
				expect(popover.position).toBe('right');
				expect(popover.align).toBe('start');

				// Update params
				action_result.update?.({
					position: 'top',
					align: 'end',
					offset: '20px',
				});

				// Check updated params
				expect(popover.position).toBe('top');
				expect(popover.align).toBe('end');
				expect(popover.offset).toBe('20px');
			});

			test('sets proper aria attributes', () => {
				const {trigger, content} = elements;

				// Set up actions
				register_action(popover.trigger(trigger));
				register_action(popover.content(content));

				// Check for aria-expanded on trigger
				expect(trigger.getAttribute('aria-expanded')).toBe('false');

				// Show popover
				popover.show();

				// aria-expanded should update
				expect(trigger.getAttribute('aria-expanded')).toBe('true');

				// Hide popover
				popover.hide();

				// aria-expanded should update back
				expect(trigger.getAttribute('aria-expanded')).toBe('false');
			});
		});

		describe('content action', () => {
			test('applies position styles and classes', () => {
				const {content} = elements;

				// Set up content action
				register_action(
					popover.content(content, {
						position: 'bottom',
						align: 'start',
						offset: '15px',
						popover_class: 'test-popover',
					}),
				);

				// Check styles were applied
				expect(content.style.position).toBe('absolute');
				expect(content.style.zIndex).toBe('10');
				expect(content.classList.contains('test-popover')).toBe(true);

				// Initial state - content shouldn't be visible, but we don't check display style
				// since we might want to allow animations
				expect(popover.visible).toBe(false);

				// Make visible
				popover.show();
				expect(popover.visible).toBe(true);
			});

			test('updates styles when parameters change', () => {
				const {content} = elements;

				// Set up content action
				const action_result = register_action(
					popover.content(content, {
						position: 'bottom',
						align: 'start',
						popover_class: 'test-popover',
					}),
				);

				// Update params
				action_result.update?.({
					position: 'right',
					align: 'center',
					popover_class: 'updated-class',
				});

				// Check class was updated
				expect(content.classList.contains('test-popover')).toBe(false);
				expect(content.classList.contains('updated-class')).toBe(true);
			});
		});

		describe('container action', () => {
			test('registers container element for positioning', () => {
				const {container, trigger, content} = elements;

				// Set up all actions
				register_action(popover.container(container));
				register_action(popover.trigger(trigger));
				register_action(popover.content(content));

				// Show popover
				popover.show();

				// Basic check that content is visible
				expect(content.style.display).not.toBe('none');
			});
		});
	});

	describe('positioning', () => {
		test.each([
			{position: 'left', align: 'start'},
			{position: 'left', align: 'center'},
			{position: 'left', align: 'end'},
			{position: 'right', align: 'start'},
			{position: 'right', align: 'center'},
			{position: 'right', align: 'end'},
			{position: 'top', align: 'start'},
			{position: 'top', align: 'center'},
			{position: 'top', align: 'end'},
			{position: 'bottom', align: 'start'},
			{position: 'bottom', align: 'center'},
			{position: 'bottom', align: 'end'},
		] as const)('applies correct styles for %s/%s', ({position, align}) => {
			const {content} = elements;

			// Apply position and alignment
			register_action(popover.content(content, {position, align}));

			// Show popover
			popover.show();

			// Ensure some key styles are set based on position and alignment
			if (position === 'left' || position === 'right') {
				if (align === 'center') {
					expect(content.style.transform).toMatch(/translateY/);
				} else {
					// For start/end alignment, one of top/bottom should be set
					const has_position = content.style.top || content.style.bottom;
					expect(has_position).toBeTruthy();
				}
				// eslint-disable-next-line @typescript-eslint/no-unnecessary-condition
			} else if (position === 'top' || position === 'bottom') {
				if (align === 'center') {
					expect(content.style.transform).toMatch(/translateX/);
				} else {
					// For start/end alignment, one of left/right should be set
					const has_position = content.style.left || content.style.right;
					expect(has_position).toBeTruthy();
				}
			}
		});

		describe('detailed positioning', () => {
			test('verifies left position styles with various alignments', () => {
				const {content} = elements;

				// Test left + start
				register_action(popover.content(content, {position: 'left', align: 'start'}));
				check_style(content, 'right', '100%');
				check_style(content, 'left', 'auto');
				check_style(content, 'top', '0');
				check_style(content, 'bottom', 'auto');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'right');
				cleanup_actions.pop()?.();

				// Test left + center
				register_action(popover.content(content, {position: 'left', align: 'center'}));
				check_style(content, 'right', '100%');
				check_style(content, 'left', 'auto');
				check_style(content, 'top', '50%');
				check_style(content, 'bottom', 'auto');
				check_style(content, 'transform', 'translateY(-50%)');
				check_style(content, 'transform-origin', 'right');
				cleanup_actions.pop()?.();

				// Test left + end
				register_action(popover.content(content, {position: 'left', align: 'end'}));
				check_style(content, 'right', '100%');
				check_style(content, 'left', 'auto');
				check_style(content, 'top', 'auto');
				check_style(content, 'bottom', '0');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'right');
				cleanup_actions.pop()?.();

				// Test left with offset
				register_action(
					popover.content(content, {position: 'left', align: 'start', offset: '10px'}),
				);
				check_style(content, 'right', 'calc(100% + 10px)');
			});

			test('verifies right position styles with various alignments', () => {
				const {content} = elements;

				// Test right + start
				register_action(popover.content(content, {position: 'right', align: 'start'}));
				check_style(content, 'left', '100%');
				check_style(content, 'right', 'auto');
				check_style(content, 'top', '0');
				check_style(content, 'bottom', 'auto');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'left');
				cleanup_actions.pop()?.();

				// Test right + center
				register_action(popover.content(content, {position: 'right', align: 'center'}));
				check_style(content, 'left', '100%');
				check_style(content, 'right', 'auto');
				check_style(content, 'top', '50%');
				check_style(content, 'bottom', 'auto');
				check_style(content, 'transform', 'translateY(-50%)');
				check_style(content, 'transform-origin', 'left');
				cleanup_actions.pop()?.();

				// Test right + end
				register_action(popover.content(content, {position: 'right', align: 'end'}));
				check_style(content, 'left', '100%');
				check_style(content, 'right', 'auto');
				check_style(content, 'top', 'auto');
				check_style(content, 'bottom', '0');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'left');
				cleanup_actions.pop()?.();

				// Test right with offset
				register_action(
					popover.content(content, {position: 'right', align: 'start', offset: '10px'}),
				);
				check_style(content, 'left', 'calc(100% + 10px)');
			});

			test('verifies top position styles with various alignments', () => {
				const {content} = elements;

				// Test top + start
				register_action(popover.content(content, {position: 'top', align: 'start'}));
				check_style(content, 'bottom', '100%');
				check_style(content, 'top', 'auto');
				check_style(content, 'left', '0');
				check_style(content, 'right', 'auto');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'bottom');
				cleanup_actions.pop()?.();

				// Test top + center
				register_action(popover.content(content, {position: 'top', align: 'center'}));
				check_style(content, 'bottom', '100%');
				check_style(content, 'top', 'auto');
				check_style(content, 'left', '50%');
				check_style(content, 'right', 'auto');
				check_style(content, 'transform', 'translateX(-50%)');
				check_style(content, 'transform-origin', 'bottom');
				cleanup_actions.pop()?.();

				// Test top + end
				register_action(popover.content(content, {position: 'top', align: 'end'}));
				check_style(content, 'bottom', '100%');
				check_style(content, 'top', 'auto');
				check_style(content, 'left', 'auto');
				check_style(content, 'right', '0');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'bottom');
				cleanup_actions.pop()?.();

				// Test top with offset
				register_action(
					popover.content(content, {position: 'top', align: 'start', offset: '10px'}),
				);
				check_style(content, 'bottom', 'calc(100% + 10px)');
			});

			test('verifies bottom position styles with various alignments', () => {
				const {content} = elements;

				// Test bottom + start
				register_action(popover.content(content, {position: 'bottom', align: 'start'}));
				check_style(content, 'top', '100%');
				check_style(content, 'bottom', 'auto');
				check_style(content, 'left', '0');
				check_style(content, 'right', 'auto');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'top');
				cleanup_actions.pop()?.();

				// Test bottom + center
				register_action(popover.content(content, {position: 'bottom', align: 'center'}));
				check_style(content, 'top', '100%');
				check_style(content, 'bottom', 'auto');
				check_style(content, 'left', '50%');
				check_style(content, 'right', 'auto');
				check_style(content, 'transform', 'translateX(-50%)');
				check_style(content, 'transform-origin', 'top');
				cleanup_actions.pop()?.();

				// Test bottom + end
				register_action(popover.content(content, {position: 'bottom', align: 'end'}));
				check_style(content, 'top', '100%');
				check_style(content, 'bottom', 'auto');
				check_style(content, 'left', 'auto');
				check_style(content, 'right', '0');
				check_style(content, 'transform', '');
				check_style(content, 'transform-origin', 'top');
				cleanup_actions.pop()?.();

				// Test bottom with offset
				register_action(
					popover.content(content, {position: 'bottom', align: 'start', offset: '10px'}),
				);
				check_style(content, 'top', 'calc(100% + 10px)');
			});

			test('verifies center position styles', () => {
				const {content} = elements;

				register_action(popover.content(content, {position: 'center'}));
				check_style(content, 'top', '50%');
				check_style(content, 'left', '50%');
				check_style(content, 'transform', 'translate(-50%, -50%)');
				check_style(content, 'transform-origin', 'center');
				cleanup_actions.pop()?.();

				// Center ignores alignment and offset
				register_action(
					popover.content(content, {position: 'center', align: 'start', offset: '10px'}),
				);
				check_style(content, 'top', '50%');
				check_style(content, 'left', '50%');
				check_style(content, 'transform', 'translate(-50%, -50%)');
			});

			test('verifies overlay position styles', () => {
				const {content} = elements;

				register_action(popover.content(content, {position: 'overlay'}));
				check_style(content, 'top', '0');
				check_style(content, 'left', '0');
				check_style(content, 'width', '100%');
				check_style(content, 'height', '100%');
				check_style(content, 'transform-origin', 'center');
				cleanup_actions.pop()?.();

				// Overlay ignores alignment and offset
				register_action(
					popover.content(content, {position: 'overlay', align: 'end', offset: '10px'}),
				);
				check_style(content, 'top', '0');
				check_style(content, 'left', '0');
				check_style(content, 'width', '100%');
				check_style(content, 'height', '100%');
			});

			test('updating position and offset dynamically updates styles', () => {
				const {content} = elements;
				popover = new Popover({
					position: 'bottom',
					align: 'center',
					offset: '0',
				});

				// Initial setup
				register_action(popover.content(content));
				check_style(content, 'top', '100%');
				check_style(content, 'left', '50%');

				// Need to force refresh of styles by destroying and recreating the action
				cleanup_actions.pop()?.();

				// Update position
				popover.update({position: 'right'});
				register_action(popover.content(content));
				check_style(content, 'left', '100%');
				check_style(content, 'top', '50%');
				cleanup_actions.pop()?.();

				// Update alignment
				popover.update({align: 'start'});
				register_action(popover.content(content));
				check_style(content, 'top', '0');
				cleanup_actions.pop()?.();

				// Update offset
				popover.update({offset: '15px'});
				register_action(popover.content(content));
				check_style(content, 'left', 'calc(100% + 15px)');
				cleanup_actions.pop()?.();

				// Multiple updates at once
				popover.update({position: 'top', align: 'end', offset: '5px'});
				register_action(popover.content(content));
				check_style(content, 'bottom', 'calc(100% + 5px)');
				check_style(content, 'right', '0');
				check_style(content, 'top', 'auto');
				check_style(content, 'left', 'auto');
			});

			test('z-index is always applied', () => {
				const {content} = elements;

				// Test each position type to ensure z-index is always applied
				const positions: Array<Position> = ['left', 'right', 'top', 'bottom', 'center', 'overlay'];

				for (const position of positions) {
					register_action(popover.content(content, {position}));
					expect(content.style.zIndex).toBe('10');
					cleanup_actions.pop()?.();
				}
			});

			test('transform-origin is set correctly for each position', () => {
				const {content} = elements;

				const position_origins = [
					{position: 'left', expected: 'right'},
					{position: 'right', expected: 'left'},
					{position: 'top', expected: 'bottom'},
					{position: 'bottom', expected: 'top'},
					{position: 'center', expected: 'center'},
					{position: 'overlay', expected: 'center'},
				];

				for (const {position, expected} of position_origins) {
					register_action(popover.content(content, {position: position as Position}));
					expect(content.style.getPropertyValue('transform-origin')).toBe(expected);
					cleanup_actions.pop()?.();
				}
			});
		});
	});

	describe('interaction', () => {
		test('clicking outside hides popover when disable_outside_click is false', () => {
			const {trigger, content, body} = elements;
			const onhide = vi.fn();
			popover = new Popover({onhide});

			// Set up actions
			register_action(popover.trigger(trigger));
			register_action(popover.content(content));

			// Show the popover
			popover.show();
			expect(popover.visible).toBe(true);

			// Simulate click outside
			const click_event = create_mock_event('click', body);
			document.dispatchEvent(click_event);

			// Popover should be hidden
			expect(popover.visible).toBe(false);
			expect(onhide).toHaveBeenCalled();
		});

		test('clicking outside does not hide when disable_outside_click is true', () => {
			const {trigger, content, body} = elements;
			const onhide = vi.fn();
			popover = new Popover({
				disable_outside_click: true,
				onhide,
			});

			// Set up actions
			register_action(popover.trigger(trigger));
			register_action(popover.content(content));

			// Show the popover
			popover.show();
			expect(popover.visible).toBe(true);

			// Simulate click outside
			const click_event = create_mock_event('click', body);
			document.dispatchEvent(click_event);

			// Popover should still be visible
			expect(popover.visible).toBe(true);
			expect(onhide).not.toHaveBeenCalled();
		});

		test('clicking on trigger or content does not hide popover', () => {
			const {trigger, content} = elements;
			const onhide = vi.fn();
			popover = new Popover({onhide});

			// Set up actions
			register_action(popover.trigger(trigger));
			register_action(popover.content(content));

			// Show the popover
			popover.show();
			expect(popover.visible).toBe(true);

			// Simulate click on content (this is intercepted earlier in the event chain)
			const content_click = create_mock_event('click', content);
			document.dispatchEvent(content_click);

			// Should still be visible
			expect(popover.visible).toBe(true);
			expect(onhide).not.toHaveBeenCalled();

			// Simulate click on trigger
			const trigger_click = create_mock_event('click', trigger);
			document.dispatchEvent(trigger_click);

			// Should still be visible (actual trigger handling is tested separately)
			expect(popover.visible).toBe(true);
			expect(onhide).not.toHaveBeenCalled();
		});
	});

	describe('edge cases', () => {
		test('nested elements within trigger or content', () => {
			const {trigger, content} = elements;

			// Create nested elements
			const inner_trigger = document.createElement('span');
			trigger.appendChild(inner_trigger);

			const inner_content = document.createElement('span');
			content.appendChild(inner_content);

			// Set up actions
			register_action(popover.trigger(trigger));
			register_action(popover.content(content));

			// Show popover
			popover.show();

			// Now we'll test if a click on the inner trigger toggles the popover
			// First note current visibility
			expect(popover.visible).toBe(true);

			// Click the trigger element directly
			trigger.click();

			// The popover should toggle to hidden
			expect(popover.visible).toBe(false);

			// Show it again for the next test
			trigger.click();
			expect(popover.visible).toBe(true);

			// Now test if outside clicks work - click on document body (not content or trigger)
			const body_click = create_mock_event('click', document.body);
			document.dispatchEvent(body_click);

			// This should close the popover
			expect(popover.visible).toBe(false);
		});

		test('changing disable_outside_click dynamically', () => {
			const {trigger, content, body} = elements;

			// Set up actions
			register_action(popover.trigger(trigger));
			register_action(popover.content(content));

			// Show popover

			popover.show();

			// Initially outside clicks should hide
			const outside_click1 = create_mock_event('click', body);
			document.dispatchEvent(outside_click1);
			expect(popover.visible).toBe(false);

			// Update to disable outside clicks
			popover.update({disable_outside_click: true});

			// Show again
			popover.show();

			// Now outside clicks should not hide
			const outside_click2 = create_mock_event('click', body);
			document.dispatchEvent(outside_click2);
			expect(popover.visible).toBe(true);

			// Change back to allowing outside clicks
			popover.update({disable_outside_click: false});

			// Outside clicks should hide again
			const outside_click3 = create_mock_event('click', body);
			document.dispatchEvent(outside_click3);
			expect(popover.visible).toBe(false);
		});

		test('changing class dynamically updates DOM', () => {
			const {content} = elements;
			popover = new Popover({
				popover_class: 'initial-class',
			});

			// Set up content action
			register_action(popover.content(content));

			// Initial class should be applied
			expect(content.classList.contains('initial-class')).toBe(true);

			// Update class
			popover.update({popover_class: 'updated-class'});

			// Old class should be removed, new class added
			expect(content.classList.contains('initial-class')).toBe(false);
			expect(content.classList.contains('updated-class')).toBe(true);
		});

		test('cleanup removes event listeners', () => {
			const {trigger, content} = elements;

			// Set up actions
			const trigger_action = register_action(popover.trigger(trigger));
			const content_action = register_action(popover.content(content));

			// Show popover to set up document click listener
			popover.show();

			// Clean up actions
			cleanup_actions = []; // Clear all registered cleanups
			trigger_action.destroy?.();
			content_action.destroy?.();

			// After cleanup, clicking trigger should do nothing
			trigger.click();
			expect(popover.visible).toBe(true); // Still true because cleanup removed click handler
		});

		test('multiple popovers work independently', () => {
			// Create two sets of elements
			const elements1 = create_elements();
			const elements2 = create_elements();
			document.body.appendChild(elements2.container);

			const popover1 = new Popover();
			const popover2 = new Popover();

			// Set up actions for both popovers
			register_action(popover1.trigger(elements1.trigger));
			register_action(popover1.content(elements1.content));

			register_action(popover2.trigger(elements2.trigger));
			register_action(popover2.content(elements2.content));

			// Show first popover
			elements1.trigger.click();
			expect(popover1.visible).toBe(true);
			expect(popover2.visible).toBe(false);

			// Show second popover
			elements2.trigger.click();
			expect(popover1.visible).toBe(true);
			expect(popover2.visible).toBe(true);

			// Hide first popover
			elements1.trigger.click();
			expect(popover1.visible).toBe(false);
			expect(popover2.visible).toBe(true);

			// Clean up
			document.body.removeChild(elements2.container);
		});
	});
});
