<script lang="ts">
  import { createTeamKey, type TeamKey, unlockTeamKey } from '@app/shared';
  import { onMount, type Snippet } from 'svelte';
  import { api } from '$lib/api';
  import Button from '$lib/components/Button.svelte';
  import Input from '$lib/components/Input.svelte';
  import { t } from '$lib/i18n';
  import { teamKey } from '$lib/team-key.svelte';

  let { children }: { children: Snippet } = $props();

  let view = $state<'loading' | 'denied' | 'setup' | 'locked'>('loading');
  let stored: TeamKey | null = null;
  let passphrase = $state('');
  let repeat = $state('');
  let error = $state('');
  let busy = $state(false);

  onMount(async () => {
    if (teamKey.key) return;
    if (!(await api.get<{ team: boolean }>('/team/access')).team) {
      view = 'denied';
      return;
    }
    stored = (await api.get<{ key: TeamKey | null }>('/team/key')).key;
    view = stored ? 'locked' : 'setup';
  });

  async function setup(e: SubmitEvent) {
    e.preventDefault();
    error = passphrase.length < 12 ? t().passphraseShort : passphrase !== repeat ? t().passphraseMismatch : '';
    if (error) return;
    busy = true;
    try {
      const key = await createTeamKey(passphrase);
      await api.post('/team/key', key);
      teamKey.key = await unlockTeamKey(key, passphrase);
    } finally {
      busy = false;
    }
  }

  async function unlock(e: SubmitEvent) {
    e.preventDefault();
    if (!stored) return;
    busy = true;
    try {
      teamKey.key = await unlockTeamKey(stored, passphrase);
    } catch {
      error = t().wrongPassphrase;
    } finally {
      busy = false;
    }
  }
</script>

{#if teamKey.key}
  {@render children()}
{:else if view === 'denied'}
  <p>{t().notInTeam}</p>
{:else if view === 'setup'}
  <form onsubmit={setup}>
    <h1>{t().keySetupTitle}</h1>
    <p>{t().keySetupHint}</p>
    <Input type="password" label={t().passphrase} bind:value={passphrase} autocomplete="new-password" />
    <Input
      type="password"
      label={t().passphraseRepeat}
      bind:value={repeat}
      error={error || undefined}
      autocomplete="new-password"
    />
    <Button type="submit" loading={busy}>{t().createKey}</Button>
  </form>
{:else if view === 'locked'}
  <form onsubmit={unlock}>
    <h1>{t().unlockTitle}</h1>
    <p>{t().unlockHint}</p>
    <Input
      type="password"
      label={t().passphrase}
      bind:value={passphrase}
      error={error || undefined}
      autocomplete="current-password"
    />
    <Button type="submit" loading={busy}>{t().unlock}</Button>
  </form>
{/if}

<style>
  form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    max-width: 420px;
  }
  h1,
  p {
    margin: 0;
  }
  p {
    color: var(--muted);
  }
</style>
