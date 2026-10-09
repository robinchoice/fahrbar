<script lang="ts">
  import { PRICE } from '@app/shared';
  import Header from '$lib/components/Header.svelte';
  import { t } from '$lib/i18n';
</script>

<Header><a href="/login">{t().team}</a></Header>

<main>
  <h1>{t().tagline}</h1>
  <p class="lead">{t().homeLead}</p>
  <ol>
    <li>{t().homeStep1}</li>
    <li>{t().homeStep2}</li>
    <li>{t().homeStep3(PRICE)}</li>
  </ol>
  <p class="note">{t().encryptedNote}</p>
  <p class="muted">
    {t().homePilot}
    <a href="https://github.com/robinchoice/fahrbar">{t().sourceCode}</a>
  </p>
</main>

<style>
  main {
    max-width: 640px;
    margin: 0 auto;
    padding: 4rem 1.5rem;
  }
  h1 {
    margin: 0 0 1rem;
    font-size: clamp(2.5rem, 8vw, 4rem);
    font-weight: 800;
    font-stretch: 75%;
    line-height: 0.95;
  }
  .lead {
    margin: 0 0 2rem;
    color: var(--muted);
    font-size: 1.15rem;
  }
  ol {
    display: grid;
    gap: 0.75rem;
    margin: 0 0 2rem;
    padding-left: 1.4rem;
    font-size: 1.05rem;
  }
  li::marker {
    font-family: var(--font-display);
    font-weight: 750;
    color: var(--accent);
  }
  .note {
    padding: 0.9rem 1rem;
    border: 1px dashed var(--border);
    border-radius: var(--radius);
    color: var(--muted);
  }
  .muted {
    color: var(--muted);
  }
  a {
    color: var(--accent);
  }
</style>
