<script lang="ts">
	import type {Prompt_Response_Message} from '$lib/zzz_message.js';

	interface Props {
		// TODO more efficient data structures, reactive source prompt_responses
		prompt_response: Prompt_Response_Message;
	}

	const {prompt_response}: Props = $props();

	const data = {
		id: 'msg_01FKQ7unuUSmJe43K3KzTJmk',
		type: 'message',
		role: 'assistant',
		model: 'claude-3-5-sonnet-20240620',
		content: [
			{
				type: 'text',
				text: "You're welcome, friend\nWords in rhythm, a sweet blend\nShort and sweet, our chat did end",
			},
		],
		stop_reason: 'end_turn',
		stop_sequence: null,
		usage: {input_tokens: 18, output_tokens: 25},
	};
</script>

<h3>prompt</h3>
<pre>{prompt_response.text}</pre>
<h3>response</h3>
<table>
	<tbody>
		<tr>
			<th>ID</th>
			<td>{data.id}</td>
		</tr>
		{#if data.type !== 'message'}
			<tr>
				<th>Type</th>
				<td>{data.type}</td>
			</tr>
		{/if}
		{#if data.role !== 'assistant'}
			<tr>
				<th>Role</th>
				<td>{data.role}</td>
			</tr>
		{/if}
		<tr>
			<th>Model</th>
			<td>{data.model}</td>
		</tr>
		<tr>
			<th>Content</th>
			<td>
				<ul class="content-list">
					{#each data.content as item}
						<li class="content-item">
							<strong>Type:</strong>
							{item.type}<br />
							<strong>Text:</strong>
							{item.text}
						</li>
					{/each}
				</ul>
			</td>
		</tr>
		{#if data.stop_reason !== 'end_turn'}
			<tr>
				<th>Stop Reason</th>
				<td>{data.stop_reason}</td>
			</tr>
		{/if}
		{#if data.stop_sequence}
			<tr>
				<th>Stop Sequence</th>
				<td>{data.stop_sequence}</td>
			</tr>
		{/if}
		<tr>
			<th>Usage</th>
			<td>
				<ul>
					<li><strong>Input Tokens:</strong> {data.usage.input_tokens}</li>
					<li><strong>Output Tokens:</strong> {data.usage.output_tokens}</li>
				</ul>
			</td>
		</tr>
	</tbody>
</table>
