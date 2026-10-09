<script lang="ts">
  import {
    appointmentTimes,
    encryptRide,
    type Messages,
    PRICE,
    pickupTime,
    type RideDetails,
    rideDetailsSchema,
  } from '@app/shared';
  import { invalidateAll } from '$app/navigation';
  import { page } from '$app/state';
  import { api } from '$lib/api';
  import Button from '$lib/components/Button.svelte';
  import Header from '$lib/components/Header.svelte';
  import Input from '$lib/components/Input.svelte';
  import { formatDate } from '$lib/format';
  import { t } from '$lib/i18n';
  import { toast } from '$lib/toast.svelte';

  let { data } = $props();

  const free = $derived(data.mornings.filter((m) => m.booked < m.capacity));
  let morningId = $state('');
  let appointment = $state('');
  const morning = $derived(free.find((m) => m.id === morningId) ?? free[0]);
  const times = $derived(morning ? appointmentTimes(morning.start, morning.end) : []);

  let step = $state<'when' | 'details' | 'done'>('when');
  let details = $state({ firstName: '', street: '', city: '', plate: '', car: '', phone: '' });
  let envelope = $state(false);
  let errors = $state<Partial<Record<keyof RideDetails, string>>>({});
  let sending = $state(false);
  let token = $state('');
  let booked = $state<{ date: string; ride: RideDetails } | null>(null);

  const manageUrl = $derived(`${page.url.origin}/b/${token}`);

  async function book(e: SubmitEvent) {
    e.preventDefault();
    if (!morning || !data.publicKey) return;
    const parsed = rideDetailsSchema.safeParse({ ...details, appointment: appointment || times[0] });
    if (!parsed.success) {
      errors = Object.fromEntries(
        parsed.error.issues.map((issue) => [issue.path[0], t()[issue.message as keyof Messages] as string]),
      );
      return;
    }
    errors = {};
    sending = true;
    try {
      const payload = await encryptRide(data.publicKey, parsed.data);
      token = (await api.post<{ token: string }>('/rides', { morningId: morning.id, payload })).token;
      booked = { date: morning.date, ride: parsed.data };
      step = 'done';
      scrollTo(0, 0);
    } catch {
      // A full morning shows as a toast; fresh seats come with the reload
      await invalidateAll();
    } finally {
      sending = false;
    }
  }

  async function copyLink() {
    await navigator.clipboard.writeText(manageUrl);
    toast(t().linkCopied);
  }
</script>

<Header>{data.practice.name}</Header>

<main>
  {#if step === 'done' && booked}
    <p class="muted">{t().bookedFor(formatDate(booked.date, data.locale))}</p>
    <h1>{t().bookedTitle}</h1>
    <div class="line"></div>
    <div class="card center">
      <div class="muted">{t().driverAsksFor}</div>
      <div class="name">{booked.ride.firstName}</div>
      <div class="muted">{t().driverAsksPlate(booked.ride.plate)}</div>
    </div>
    <dl class="card">
      <dt>{t().pickup}</dt>
      <dd>
        {t().pickupAround(pickupTime(booked.ride.appointment))}<br /><span class="muted"
          >{t().whenDischarged} · {data.practice.address}</span
        >
      </dd>
      <dt>{t().destination}</dt>
      <dd>{booked.ride.street}, {booked.ride.city}</dd>
      <dt>{t().carLabel}</dt>
      <dd>{[booked.ride.car, booked.ride.plate].filter(Boolean).join(' · ')}</dd>
      <dt>{t().priceLabel}</dt>
      <dd><b>{t().priceCash(PRICE)}</b></dd>
    </dl>
    <p>{t().callBefore(booked.ride.phone)}</p>
    <p class="note">{t().deletedAfter}</p>
    <p class="muted">{t().keepLink}</p>
    <p class="link"><a href={manageUrl}>{manageUrl}</a></p>
    <Button variant="secondary" onclick={copyLink}>{t().copyLink}</Button>
  {:else if !data.publicKey}
    <h1>{t().bookTitle}</h1>
    <p>{t().bookingNotReady}</p>
  {:else if step === 'when'}
    <p class="muted">{t().recommendedBy(data.practice.name)}</p>
    <h1>{t().bookTitle}</h1>
    <p class="lead">{t().bookLead(PRICE)}</p>
    {#if !morning}
      <p>{t().noMornings}</p>
    {:else}
      <h2>{t().morning}</h2>
      <div class="slots">
        {#each data.mornings as m (m.id)}
          {@const left = m.capacity - m.booked}
          <button
            type="button"
            class="slot"
            class:selected={m.id === morning.id}
            disabled={left <= 0}
            aria-pressed={m.id === morning.id}
            onclick={() => {
              morningId = m.id;
              appointment = '';
            }}
          >
            <b>{formatDate(m.date, data.locale, 'short')}</b>
            <span>{left > 0 ? t().seatsLeft(m.start, m.end, left) : t().full}</span>
          </button>
        {/each}
      </div>
      <h2>{t().appointmentAt}</h2>
      <div class="times">
        {#each times as time (time)}
          {@const selected = time === (appointment || times[0])}
          <button type="button" class:selected aria-pressed={selected} onclick={() => (appointment = time)}>
            {time}
          </button>
        {/each}
      </div>
      <p class="muted">{t().pickupHint}</p>
      <div class="actions">
        <Button
          onclick={() => {
            step = 'details';
            scrollTo(0, 0);
          }}>{t().toDetails}</Button
        >
      </div>
    {/if}
  {:else if morning}
    <p class="muted">
      {formatDate(morning.date, data.locale)} · {t().appointment(appointment || times[0] || '')}
    </p>
    <h1>{t().detailsTitle}</h1>
    <form onsubmit={book} novalidate>
      <Input
        label={t().firstName}
        hint={t().firstNameHint}
        bind:value={details.firstName}
        error={errors.firstName}
        autocomplete="given-name"
      />
      <Input label={t().street} bind:value={details.street} error={errors.street} autocomplete="street-address" />
      <Input label={t().city} bind:value={details.city} error={errors.city} placeholder="79098 Freiburg" />
      <div class="row">
        <Input label={t().plate} bind:value={details.plate} error={errors.plate} placeholder="FR-AB 123" />
        <Input label={t().car} bind:value={details.car} />
      </div>
      <Input
        type="tel"
        label={t().phone}
        hint={t().phoneHint}
        bind:value={details.phone}
        error={errors.phone}
        autocomplete="tel"
      />
      <p class="note">{t().encryptedNote}</p>
      <p class="muted">{t().priceNote(PRICE)}</p>
      <label class="check"><input type="checkbox" bind:checked={envelope} /> {t().envelope(PRICE)}</label>
      <div class="actions">
        <Button variant="secondary" onclick={() => (step = 'when')}>{t().back}</Button>
        <Button type="submit" loading={sending} disabled={!envelope}>{t().book(PRICE)}</Button>
      </div>
    </form>
  {/if}
</main>

<style>
  main {
    max-width: 560px;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
  }
  h1 {
    margin: 0 0 0.75rem;
    font-size: clamp(2rem, 7vw, 2.6rem);
  }
  h2 {
    margin: 1.75rem 0 0.75rem;
    font-size: 1.25rem;
  }
  p {
    margin: 0 0 1rem;
  }
  .lead {
    color: var(--muted);
    font-size: 1.1rem;
  }
  .muted {
    color: var(--muted);
  }
  .line {
    width: 64px;
    height: 4px;
    margin: 0.5rem 0 1.25rem;
    border-radius: 2px;
    background: var(--gradient);
  }
  .slots {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
    gap: 0.6rem;
  }
  .slot,
  .times button {
    padding: 0.75rem 0.9rem;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: var(--surface);
    color: var(--text);
    font: inherit;
    text-align: left;
    cursor: pointer;
  }
  .slot b {
    display: block;
    font-family: var(--font-display);
    font-size: 1.2rem;
    font-weight: 760;
    font-stretch: 80%;
  }
  .slot span {
    color: var(--muted);
    font-size: 0.85rem;
  }
  .slot:disabled {
    opacity: 0.45;
    cursor: default;
  }
  .times {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 0.5rem;
    margin-bottom: 1rem;
  }
  .times button {
    padding: 0.8rem 0;
    font-size: 1.1rem;
    text-align: center;
  }
  .selected {
    border-color: transparent;
    box-shadow: 0 0 0 2px var(--accent);
    font-weight: 700;
  }
  form {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }
  .row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }
  @media (max-width: 480px) {
    .row {
      grid-template-columns: 1fr;
    }
  }
  .note {
    padding: 0.8rem 1rem;
    border: 1px dashed var(--border);
    border-radius: var(--radius);
    color: var(--muted);
    font-size: 0.95rem;
  }
  .check {
    display: flex;
    gap: 0.6rem;
    align-items: flex-start;
  }
  .check input {
    margin-top: 0.3rem;
  }
  .actions {
    display: flex;
    gap: 0.75rem;
    margin-top: 0.5rem;
  }
  .card {
    margin: 0 0 1rem;
    padding: 1.1rem;
    border: 1px solid var(--border);
    border-radius: 14px;
    background: var(--surface);
  }
  .center {
    text-align: center;
  }
  .name {
    font-family: var(--font-display);
    font-size: 2.6rem;
    font-weight: 800;
    font-stretch: 78%;
  }
  dl {
    display: grid;
    grid-template-columns: max-content 1fr;
    gap: 0.5rem 1rem;
  }
  dt {
    color: var(--muted);
  }
  dd {
    margin: 0;
  }
  .link {
    overflow-wrap: anywhere;
    font-size: 0.9rem;
  }
  a {
    color: var(--accent);
  }
</style>
