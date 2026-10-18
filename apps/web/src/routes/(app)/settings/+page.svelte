<script lang="ts">
  import type { Passkey } from '@app/shared';
  import { browserSupportsWebAuthn } from '@simplewebauthn/browser';
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { addPasskey, listPasskeys, removePasskey } from '$lib/auth.svelte';
  import Button from '$lib/components/Button.svelte';
  import { t } from '$lib/i18n';
  import { toast } from '$lib/toast.svelte';

  const day = (iso: string) =>
    new Date(iso).toLocaleDateString(page.data.locale === 'de' ? 'de-DE' : 'en-GB', { dateStyle: 'long' });

  let passkeys = $state<Passkey[]>([]);
  let canAddPasskey = $state(false);
  let adding = $state(false);

  onMount(async () => {
    canAddPasskey = browserSupportsWebAuthn();
    passkeys = await listPasskeys().catch(() => []);
  });

  async function add() {
    adding = true;
    try {
      passkeys = [...passkeys, await addPasskey()];
      toast(t().passkeyAdded);
    } catch {
      // Cancelled in the browser's dialog, or the API client showed the error
    } finally {
      adding = false;
    }
  }

  async function remove(id: string) {
    try {
      await removePasskey(id);
      passkeys = passkeys.filter((passkey) => passkey.id !== id);
      toast(t().passkeyRemoved);
    } catch {
      // The API client already shows the error as a toast
    }
  }
</script>

<h1>{t().settings}</h1>

<section>
  <h2>{t().passkeys}</h2>
  <p>{t().passkeysHint}</p>
  {#if passkeys.length}
    <ul>
      {#each passkeys as passkey (passkey.id)}
        <li>
          <div>
            <strong>{t().passkeyAddedOn(day(passkey.createdAt))}</strong>
            <p>
              {passkey.backedUp ? t().passkeySynced : t().passkeyOneDevice}{#if passkey.lastUsedAt}
                · {t().passkeyUsedOn(day(passkey.lastUsedAt))}{/if}
            </p>
          </div>
          <Button variant="secondary" onclick={() => remove(passkey.id)}>{t().removePasskey}</Button>
        </li>
      {/each}
    </ul>
  {:else}
    <p>{t().noPasskeys}</p>
  {/if}
  {#if canAddPasskey}
    <div class="add"><Button loading={adding} onclick={add}>{t().addPasskey}</Button></div>
  {/if}
</section>

<style>
  ul {
    margin: 0.8rem 0 0;
    padding: 0;
    list-style: none;
  }
  li {
    display: flex;
    gap: 1rem;
    align-items: center;
    justify-content: space-between;
    padding: 0.7rem 0;
    border-top: 1px solid var(--border);
  }
  .add {
    margin-top: 1rem;
  }
  section {
    max-width: 560px;
    padding: 1.1rem 1.2rem;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: var(--surface);
  }
  h2 {
    margin: 0 0 0.8rem;
    font-size: 1.2rem;
  }
  p {
    margin: 0.2rem 0 0;
    color: var(--muted);
    font-size: 0.9rem;
  }
</style>
