<script lang="ts">
  import { APP_NAME } from '@app/shared';
  import { onMount } from 'svelte';
  import { goto } from '$app/navigation';
  import { page } from '$app/state';
  import { auth, checkAuth, logout } from '$lib/auth.svelte';
  import Button from '$lib/components/Button.svelte';
  import Feedback from '$lib/components/Feedback.svelte';
  import { openFeedback } from '$lib/feedback.svelte';
  import { t } from '$lib/i18n';

  let { children } = $props();
  let ready = $state(false);

  onMount(async () => {
    await checkAuth();
    if (auth.user) {
      ready = true;
      return;
    }
    // Come back to the requested page after logging in
    goto(`/login?next=${encodeURIComponent(page.url.pathname + page.url.search)}`, { replaceState: true });
  });

  async function handleLogout() {
    await logout();
    goto('/');
  }
</script>

{#if ready && auth.user}
  <header>
    <a href="/team" class="brand"><img src="/favicon.svg" alt="" width="26" height="26" />{APP_NAME}</a>
    <span class="user">{auth.user.name}</span>
    <Button variant="secondary" onclick={() => openFeedback('idea')}>{t().giveFeedback}</Button>
    <Button variant="secondary" onclick={handleLogout}>{t().logOut}</Button>
  </header>
  <main>
    {@render children()}
  </main>
  <Feedback />
{/if}

<style>
  header {
    display: flex;
    gap: 1rem;
    align-items: center;
    padding: 0.75rem 1.5rem;
    border-bottom: 1px solid var(--border);
    background: var(--surface);
  }
  .brand {
    display: flex;
    gap: 0.5rem;
    align-items: center;
    margin-right: auto;
    font-family: var(--font-display);
    font-size: 1.3rem;
    font-weight: 750;
    font-stretch: 80%;
    text-decoration: none;
  }
  .user {
    color: var(--muted);
  }
  @media (max-width: 640px) {
    .user {
      display: none;
    }
  }
  main {
    max-width: 960px;
    margin: 0 auto;
    padding: 2rem 1.5rem;
  }
</style>
