<script lang="ts">
	import {base} from '$app/paths';
	import type {Repo} from '$routes/projects/repo.svelte.js';

	interface Props {
		repo: Repo;
		project_id: string;
	}

	const {repo, project_id}: Props = $props();
</script>

<tr>
	<td>
		<a href="{base}/projects/{project_id}/repos/{repo.id}">
			{repo.git_url || '[new repo]'}
		</a>
	</td>
	<td>
		{repo.checkouts.length}
	</td>
	<td>{new Date(repo.created).toLocaleString()}</td>
	<td>{new Date(repo.updated).toLocaleString()}</td>
</tr>
