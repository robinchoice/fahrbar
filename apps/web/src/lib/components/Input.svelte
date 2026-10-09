<script lang="ts">
  import type { HTMLInputAttributes } from 'svelte/elements';

  let {
    value = $bindable(''),
    label,
    type = 'text',
    placeholder = '',
    hint,
    error,
    required = false,
    autocomplete,
    inputmode,
  }: {
    value?: string;
    label: string;
    type?: 'text' | 'email' | 'tel' | 'password' | 'date' | 'time';
    placeholder?: string;
    hint?: string;
    error?: string;
    required?: boolean;
    autocomplete?: HTMLInputAttributes['autocomplete'];
    inputmode?: HTMLInputAttributes['inputmode'];
  } = $props();

  // Hint and error describe the field without becoming part of its name
  const note = $props.id();
</script>

<div class="field">
  <label>
    <span>{label}</span>
    <input
      {type}
      bind:value
      {placeholder}
      {required}
      {autocomplete}
      {inputmode}
      class:invalid={!!error}
      aria-invalid={!!error}
      aria-describedby={error || hint ? note : undefined}
    />
  </label>
  {#if error}<small id={note}>{error}</small>{:else if hint}<small id={note} class="hint">{hint}</small>{/if}
</div>

<style>
  .field {
    display: flex;
    flex-direction: column;
    gap: 0.3rem;
  }
  label {
    display: flex;
    flex-direction: column;
    gap: 0.4rem;
  }
  span {
    font-size: 0.85rem;
    font-weight: 600;
  }
  input {
    height: 42px;
    padding: 0 0.8rem;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--surface);
    color: var(--text);
    font: inherit;
  }
  input:focus {
    outline: 2px solid var(--accent);
    outline-offset: -1px;
  }
  .invalid {
    border-color: var(--error);
  }
  small {
    color: var(--error);
  }
  .hint {
    color: var(--muted);
  }
</style>
