<script lang="ts">
  import {
    decryptRide,
    type Messages,
    type Morning,
    type Practice,
    pickupTime,
    type Ride,
    type RideDetails,
    type RideStatus,
  } from '@app/shared';
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { api } from '$lib/api';
  import Button from '$lib/components/Button.svelte';
  import { formatDate } from '$lib/format';
  import { t } from '$lib/i18n';
  import { teamKey } from '$lib/team-key.svelte';

  type Pickup = Ride & { details: RideDetails | null };

  const LABEL: Record<RideStatus, keyof Messages> = {
    new: 'teamStatusNew',
    confirmed: 'statusConfirmed',
    picked_up: 'statusPickedUp',
    arrived: 'statusArrived',
  };
  const NEXT: Partial<Record<RideStatus, [RideStatus, keyof Messages]>> = {
    new: ['confirmed', 'markConfirmed'],
    confirmed: ['picked_up', 'markPickedUp'],
    picked_up: ['arrived', 'markArrived'],
  };

  let morning = $state<Omit<Morning, 'booked'> | null>(null);
  let practice = $state<Practice | null>(null);
  let pickups = $state<Pickup[]>([]);
  const toCall = $derived(pickups.filter((p) => p.status === 'new').length);

  onMount(async () => {
    const [day, list] = await Promise.all([
      api.get<{ morning: Omit<Morning, 'booked'>; rides: Ride[] }>(`/team/mornings/${page.params.id}/rides`),
      api.get<{ practices: Practice[] }>('/team/practices'),
    ]);
    morning = day.morning;
    practice = list.practices.find((p) => p.id === day.morning.practiceId) ?? null;
    const opened = await Promise.all(
      day.rides.map(async (ride) => ({
        ...ride,
        details: (await decryptRide(teamKey.key!, ride.payload).catch(() => null)) as RideDetails | null,
      })),
    );
    pickups = opened.sort((a, b) => (a.details?.appointment ?? '').localeCompare(b.details?.appointment ?? ''));
  });

  async function advance(pickup: Pickup, status: RideStatus) {
    await api.patch(`/team/rides/${pickup.id}`, { status });
    pickup.status = status;
  }

  // Opens the phone's own maps app, no address goes to a web service
  const mapsLink = (address: string) =>
    /iPhone|iPad/.test(navigator.userAgent)
      ? `maps://?daddr=${encodeURIComponent(address)}`
      : `geo:0,0?q=${encodeURIComponent(address)}`;
</script>

<a href="/team" class="back">← {t().allMornings}</a>
{#if morning}
  <p class="muted">{practice?.name}</p>
  <h1>{formatDate(morning.date, page.data.locale)}</h1>
  <p class="stats">
    <span><b>{t().pickups(pickups.length)}</b></span>
    <span>{morning.start}–{morning.end}</span>
    {#if toCall}<span class="needs">{t().toCall(toCall)}</span>{/if}
  </p>
  {#if pickups.length === 0}
    <p class="muted">{t().noRides}</p>
  {/if}
  <div class="pickups">
    {#each pickups as pickup (pickup.id)}
      {@const d = pickup.details}
      {@const next = NEXT[pickup.status]}
      <article class:done={pickup.status === 'arrived'}>
        <header>
          <span class="time">{d ? pickupTime(d.appointment) : '–'}</span>
          <span class="name">{d?.firstName ?? t().unreadable}</span>
          <span class="chip" class:needs={pickup.status === 'new'} class:new={pickup.status === 'picked_up'}
            >{t()[LABEL[pickup.status]]}</span
          >
        </header>
        {#if d}
          <div class="facts">
            <span><a href={mapsLink(`${d.street}, ${d.city}`)}>{d.street}, {d.city}</a></span>
            <span>{[d.car, d.plate].filter(Boolean).join(' · ')}</span>
            <span class="muted">{t().appointment(d.appointment)} · <a href="tel:{d.phone}">{d.phone}</a></span>
          </div>
        {/if}
        <div class="actions">
          {#if d}<Button variant="secondary" href="tel:{d.phone}">{t().call}</Button>{/if}
          {#if next}
            <Button onclick={() => advance(pickup, next[0])}>{t()[next[1]] as string}</Button>
          {/if}
        </div>
      </article>
    {/each}
  </div>
{/if}

<style>
  .back {
    color: var(--muted);
    text-decoration: none;
  }
  h1 {
    margin: 0 0 0.5rem;
  }
  p {
    margin: 0.75rem 0 0;
  }
  .muted {
    color: var(--muted);
  }
  .stats {
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    margin-bottom: 1.25rem;
    color: var(--muted);
  }
  .stats b {
    color: var(--text);
  }
  .stats .needs {
    color: var(--needs);
    font-weight: 600;
  }
  .pickups {
    display: grid;
    gap: 0.75rem;
  }
  article {
    display: grid;
    gap: 0.6rem;
    padding: 1rem 1.1rem;
    border: 1px solid var(--border);
    border-radius: 14px;
    background: var(--surface);
  }
  article.done {
    opacity: 0.6;
  }
  header {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    align-items: baseline;
  }
  .time {
    font-family: var(--font-display);
    font-size: 1.9rem;
    font-weight: 790;
    font-stretch: 78%;
    font-variant-numeric: tabular-nums;
  }
  .name {
    font-family: var(--font-display);
    font-size: 1.2rem;
    font-weight: 760;
    font-stretch: 80%;
  }
  .chip {
    margin-left: auto;
    padding: 0.15rem 0.6rem;
    border: 1px solid var(--border);
    border-radius: 99px;
    color: var(--muted);
    font-size: 0.85rem;
    font-weight: 600;
  }
  .chip.needs {
    border-color: var(--needs);
    color: var(--needs);
  }
  .chip.new {
    border-color: var(--new);
    color: var(--new);
  }
  .facts {
    display: grid;
    gap: 0.2rem;
  }
  .facts a {
    color: var(--accent);
  }
  .actions {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem;
  }
</style>
