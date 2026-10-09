<script lang="ts">
  import { APP_BAND } from '@app/shared';
  import { page } from '$app/state';
  import { auth } from '$lib/auth.svelte';
  import { setTestMode, testMode } from '$lib/feedback.svelte';
  import { setLocale, t } from '$lib/i18n';

  const other = $derived(page.data.locale === 'de' ? 'en' : 'de');
</script>

<footer>
  <a href="https://pleasance.org">
    <span class="by">{t().madeBy}</span>
    <span class="signature">
      <span class="wordmark" role="img" aria-label="Pleasance"></span>
      <span class="band" aria-hidden="true"><span
          class="marker"
          style:left="{((APP_BAND.from - 1) / 6) * 100}%"
          style:width="{((APP_BAND.to - APP_BAND.from) / 6) * 100}%"
        ></span></span>
    </span>
  </a>
  <div class="settings">
    {#if auth.user}
      <label title={t().testModeHint}>
        <input type="checkbox" checked={testMode.on} onchange={(e) => setTestMode(e.currentTarget.checked)} />
        {t().testMode}
      </label>
    {/if}
    <button type="button" lang={other} onclick={() => setLocale(other)}>{t().otherLanguage}</button>
  </div>
</footer>

<style>
  footer {
    display: flex;
    gap: 1rem;
    align-items: center;
    justify-content: space-between;
    padding: 1.125rem 1.5rem;
    border-top: 1px solid var(--border);
    color: var(--muted);
    font-size: 0.8125rem;
  }
  a {
    display: inline-flex;
    gap: 0.5rem;
    align-items: baseline;
    text-decoration: none;
  }
  .by {
    font-family: var(--font-display);
    font-size: 0.875rem;
    font-weight: 650;
    font-stretch: 80%;
    transform: translateY(2px);
  }
  .signature {
    display: inline-flex;
    flex-direction: column;
    gap: 5px;
    transform: translateY(4px);
  }
  .wordmark {
    width: 99px;
    height: 11px;
    background: currentColor;
    mask: url('/pleasance-wordmark.svg') left center / contain no-repeat;
  }
  .band {
    position: relative;
    width: 99px;
    height: 2px;
    border-radius: 1px;
    background: linear-gradient(rgb(255 255 255 / 0.6), rgb(255 255 255 / 0.6)), var(--spectrum);
  }
  .marker {
    position: absolute;
    top: -1px;
    min-width: 6px;
    height: 4px;
    border-radius: 2px;
    background: var(--gradient);
  }
  .settings {
    display: flex;
    gap: 1rem;
    align-items: center;
  }
  label {
    display: inline-flex;
    gap: 0.375rem;
    align-items: center;
    cursor: pointer;
  }
  input {
    margin: 0;
    accent-color: var(--accent);
  }
  button {
    padding: 0.25rem 0;
    border: none;
    background: none;
    color: inherit;
    font: inherit;
    text-decoration: underline;
    text-underline-offset: 0.2em;
    cursor: pointer;
  }
</style>
