<script lang="ts">
	import type {Receive_Prompt_Message} from '$lib/zzz_message.js';
	import type {Agent} from '$lib/agent.svelte.js';

	interface Props {
		agent: Agent;
		// TODO more efficient data structures, reactive source prompt_responses
		prompt_response: Receive_Prompt_Message;
	}

	const {agent, prompt_response}: Props = $props();
</script>

<h3>prompt</h3>
<pre>{prompt_response.text}</pre>
<h3>response from {agent.title}</h3>
<table>
	<tbody>
		<tr>
			<th>id</th>
			<td>{prompt_response.data.id}</td>
		</tr>
		<tr>
			<th>model</th>
			<td>{prompt_response.data.model}</td>
		</tr>
		<tr>
			<th>content </th>
			<td>
				<ul class="content-list">
					{#each prompt_response.data.content as item}
						<li class="content-item">
							{#if item.type === 'text'}
								{item.text}
							{:else if item.type === 'tool_use'}
								used tool {item.name} - {item.input} - {item.id}
							{/if}
						</li>
					{/each}
				</ul>
			</td>
		</tr>
		{#if prompt_response.data.stop_reason !== 'end_turn'}
			<tr>
				<th>stop Reason</th>
				<td>{prompt_response.data.stop_reason}</td>
			</tr>
		{/if}
		{#if prompt_response.data.stop_sequence}
			<tr>
				<th>stop Sequence</th>
				<td>{prompt_response.data.stop_sequence}</td>
			</tr>
		{/if}
		<tr>
			<th>tokens</th>
			<td>
				<ul>
					<li><strong>in:</strong> {prompt_response.data.usage.input_tokens}</li>
					<li><strong>out:</strong> {prompt_response.data.usage.output_tokens}</li>
				</ul>
			</td>
		</tr>
	</tbody>
</table>
