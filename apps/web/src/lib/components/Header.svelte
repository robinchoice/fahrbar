<script lang="ts">
  import { APP_NAME } from '@app/shared';
  import type { Snippet } from 'svelte';

  let { children }: { children?: Snippet } = $props();
</script>

<header>
  <a href="/" class="brand"><img src="/favicon.svg" alt="" width="30" height="30" />{APP_NAME}</a>
  {#if children}<div class="right">{@render children()}</div>{/if}
</header>

<style>
  header {
    display: flex;
    align-items: center;
    gap: 1rem;
    padding: 0.85rem 1.5rem;
    border-bottom: 1px solid var(--border);
  }
  .brand {
    display: flex;
    align-items: center;
    gap: 0.6rem;
    font-family: var(--font-display);
    font-size: 1.5rem;
    font-weight: 790;
    font-stretch: 78%;
    text-decoration: none;
  }
  .right {
    margin-left: auto;
    color: var(--muted);
    font-size: 0.9rem;
    text-align: right;
  }
</style>
