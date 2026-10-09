<script lang="ts">
  import type { Messages, RideStatus } from '@app/shared';
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { api } from '$lib/api';
  import Button from '$lib/components/Button.svelte';
  import Header from '$lib/components/Header.svelte';
  import { formatDate } from '$lib/format';
  import { t } from '$lib/i18n';

  type Ride = { status: RideStatus; date: string; start: string; end: string; practice: string; address: string };

  const STATUS: Record<RideStatus, keyof Messages> = {
    new: 'statusNew',
    confirmed: 'statusConfirmed',
    picked_up: 'statusPickedUp',
    arrived: 'statusArrived',
  };

  let ride = $state<Ride | null>(null);
  let missing = $state(false);
  let sure = $state(false);
  let cancelling = $state(false);
  let cancelled = $state(false);
  const path = `/rides/${encodeURIComponent(page.params.token ?? '')}`;

  onMount(async () => {
    try {
      ride = (await api.get<{ ride: Ride }>(path, true)).ride;
    } catch {
      missing = true;
    }
  });

  async function cancel() {
    cancelling = true;
    try {
      await api.delete(path);
      cancelled = true;
    } finally {
      cancelling = false;
    }
  }
</script>

<Header />

<main>
  <h1>{t().rideTitle}</h1>
  {#if cancelled}
    <p>{t().cancelled}</p>
  {:else if missing}
    <p>{t().rideNotFound}</p>
  {:else if ride}
    <dl>
      <dt>{t().morning}</dt>
      <dd>{formatDate(ride.date, page.data.locale)}, {ride.start}–{ride.end}</dd>
      <dt>{t().practice}</dt>
      <dd>{ride.practice}<br /><span class="muted">{ride.address}</span></dd>
      <dt>{t().statusLabel}</dt>
      <dd>{t()[STATUS[ride.status]]}</dd>
    </dl>
    {#if ride.status === 'new' || ride.status === 'confirmed'}
      {#if sure}
        <Button onclick={cancel} loading={cancelling}>{t().cancelSure}</Button>
      {:else}
        <Button variant="secondary" onclick={() => (sure = true)}>{t().cancelRide}</Button>
      {/if}
    {/if}
  {/if}
</main>

<style>
  main {
    max-width: 560px;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
  }
  dl {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 0.5rem 1rem;
    margin: 0 0 1.5rem;
    padding: 1.1rem;
    border: 1px solid var(--border);
    border-radius: 14px;
    background: var(--surface);
  }
  dt,
  .muted {
    color: var(--muted);
  }
  dd {
    margin: 0;
  }
</style>
