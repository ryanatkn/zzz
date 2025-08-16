<script lang="ts">
  import AIControl from './ai_control_example.svelte';
</script>

<main>
  <AIControl />
</main>

<style>
  :global(body) {
    margin: 0;
    padding: 0;
    background: #0f0f23;
    color: #cccccc;
    font-family: system-ui, -apple-system, sans-serif;
  }
  
  main {
    min-height: 100vh;
  }
</style>