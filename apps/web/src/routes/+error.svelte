<script lang="ts">
  import { page } from '$app/state';
  import Header from '$lib/components/Header.svelte';
  import { t } from '$lib/i18n';

  const text = $derived(
    page.status === 404 ? (page.url.pathname.startsWith('/p/') ? t().practiceNotFound : t().notFound) : t().internalError,
  );
</script>

<Header />
<main>
  <h1>{page.status}</h1>
  <p>{text}</p>
</main>

<style>
  main {
    max-width: 560px;
    margin: 0 auto;
    padding: 2.5rem 1.25rem 4rem;
  }
</style>
