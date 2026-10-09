<script lang="ts">
  import type { Morning, Practice } from '@app/shared';
  import { onMount } from 'svelte';
  import { page } from '$app/state';
  import { api } from '$lib/api';
  import Button from '$lib/components/Button.svelte';
  import Input from '$lib/components/Input.svelte';
  import { formatDate } from '$lib/format';
  import { t } from '$lib/i18n';

  let mornings = $state<Morning[]>([]);
  let practices = $state<Practice[]>([]);
  const practiceName = (id: string) => practices.find((p) => p.id === id)?.name ?? '';

  let newMorning = $state({ practiceId: '', date: '', start: '08:00', end: '12:00', capacity: '4' });
  let newPractice = $state({ slug: '', name: '', address: '' });

  async function load() {
    [mornings, practices] = await Promise.all([
      api.get<{ mornings: Morning[] }>('/team/mornings').then((r) => r.mornings),
      api.get<{ practices: Practice[] }>('/team/practices').then((r) => r.practices),
    ]);
    newMorning.practiceId ||= practices[0]?.id ?? '';
  }

  onMount(load);

  async function addMorning(e: SubmitEvent) {
    e.preventDefault();
    await api.post('/team/mornings', { ...newMorning, capacity: Number(newMorning.capacity) });
    newMorning.date = '';
    await load();
  }

  async function addPractice(e: SubmitEvent) {
    e.preventDefault();
    await api.post('/team/practices', newPractice);
    newPractice = { slug: '', name: '', address: '' };
    await load();
  }

  async function remove(id: string) {
    await api.delete(`/team/mornings/${id}`);
    await load();
  }
</script>

<h1>{t().morningsTitle}</h1>
{#if mornings.length === 0}
  <p class="muted">{t().noMorningsPlanned}</p>
{:else}
  <ul class="list">
    {#each mornings as m (m.id)}
      <li>
        <a href="/team/{m.id}">
          <b>{formatDate(m.date, page.data.locale)}</b>
          <span class="muted">{m.start}–{m.end} · {practiceName(m.practiceId)}</span>
        </a>
        <span class="chip" class:full={m.booked >= m.capacity}>{t().booked(m.booked, m.capacity)}</span>
        {#if m.booked === 0}
          <Button variant="secondary" onclick={() => remove(m.id)}>{t().delete}</Button>
        {/if}
      </li>
    {/each}
  </ul>
{/if}

{#if practices.length}
  <form class="card" onsubmit={addMorning}>
    <h2>{t().newMorning}</h2>
    <label>
      <span>{t().practice}</span>
      <select bind:value={newMorning.practiceId}>
        {#each practices as p (p.id)}<option value={p.id}>{p.name}</option>{/each}
      </select>
    </label>
    <div class="row">
      <Input type="date" label={t().date} bind:value={newMorning.date} required />
      <Input label={t().seats} bind:value={newMorning.capacity} inputmode="numeric" required />
      <Input type="time" label={t().from} bind:value={newMorning.start} required />
      <Input type="time" label={t().until} bind:value={newMorning.end} required />
    </div>
    <Button type="submit">{t().create}</Button>
  </form>
{/if}

<h2>{t().practicesTitle}</h2>
<ul class="list">
  {#each practices as p (p.id)}
    <li>
      <span><b>{p.name}</b><span class="muted">{p.address}</span></span>
      <a class="link" href="/p/{p.slug}">{page.url.host}/p/{p.slug}</a>
    </li>
  {/each}
</ul>
<form class="card" onsubmit={addPractice}>
  <h2>{t().newPractice}</h2>
  <Input label={t().practiceName} bind:value={newPractice.name} required />
  <Input label={t().practiceAddress} bind:value={newPractice.address} required />
  <Input label={t().practiceSlug} bind:value={newPractice.slug} placeholder="albrecht" required />
  <Button type="submit">{t().create}</Button>
</form>

<style>
  h1 {
    margin: 0 0 1rem;
  }
  h2 {
    margin: 2rem 0 0.75rem;
  }
  .card h2 {
    margin: 0;
  }
  .muted {
    color: var(--muted);
  }
  .list {
    display: grid;
    gap: 0.5rem;
    margin: 0;
    padding: 0;
    list-style: none;
  }
  .list li {
    display: flex;
    flex-wrap: wrap;
    gap: 0.75rem;
    align-items: center;
    padding: 0.8rem 1rem;
    border: 1px solid var(--border);
    border-radius: 12px;
    background: var(--surface);
  }
  .list li > a,
  .list li > span:first-child {
    display: grid;
    flex: 1;
    text-decoration: none;
  }
  .chip {
    padding: 0.15rem 0.6rem;
    border: 1px solid var(--border);
    border-radius: 99px;
    color: var(--muted);
    font-size: 0.85rem;
  }
  .chip.full {
    border-color: var(--new);
    color: var(--new);
  }
  .link {
    color: var(--accent);
    font-size: 0.9rem;
  }
  .card {
    display: flex;
    flex-direction: column;
    gap: 1rem;
    max-width: 520px;
    margin-top: 1.5rem;
    padding: 1.1rem;
    border: 1px solid var(--border);
    border-radius: 14px;
    background: var(--surface);
  }
  .row {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 0.75rem;
  }
  label {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }
  label span {
    font-size: 0.85rem;
    font-weight: 600;
  }
  select {
    height: 42px;
    padding: 0 0.6rem;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--surface);
    color: var(--text);
    font: inherit;
  }
</style>
