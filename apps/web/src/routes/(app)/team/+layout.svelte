<script lang="ts">
  import KeyGate from '$lib/components/KeyGate.svelte';

  let { children } = $props();
</script>

<KeyGate>{@render children()}</KeyGate>
