import dns from 'node:dns';
import { pickLocale } from '@app/shared';
import type { Handle, HandleServerError } from '@sveltejs/kit';
import { dev } from '$app/environment';
import { captureException } from './monitoring.server';

// Docker's embedded DNS doesn't answer AAAA queries, which otherwise stalls
// the AAAA-before-A lookup order until it times out.
dns.setDefaultResultOrder('ipv4first');

// In production this server forwards /api to the API service, so browser and
// API share one origin and the session cookie needs no CORS. In dev Vite's
// proxy does the same for the browser, fetches in server loads land here.
const API_ORIGIN = process.env.API_INTERNAL_URL || (dev ? 'http://localhost:3000' : 'http://api:3000');

// PostHog's browser SDK sends to /ingest (see hooks.client.ts). Going through
// this server keeps the CSP at 'self' and gets past ad blockers.
function upstream(url: URL) {
  if (url.pathname.startsWith('/api/')) return `${API_ORIGIN}${url.pathname}${url.search}`;
  if (url.pathname.startsWith('/ingest/static/') || url.pathname.startsWith('/ingest/array/'))
    return `https://eu-assets.i.posthog.com${url.pathname.slice(7)}${url.search}`;
  if (url.pathname.startsWith('/ingest/')) return `https://eu.i.posthog.com${url.pathname.slice(7)}${url.search}`;
}

// The CSP comes from svelte.config.js. Browsers ignore HSTS over plain HTTP,
// so it is harmless in dev.
const SECURITY_HEADERS = {
  'strict-transport-security': 'max-age=31536000',
  'x-content-type-options': 'nosniff',
  'referrer-policy': 'strict-origin-when-cross-origin',
};

export const handle: Handle = async ({ event, resolve }) => {
  // The language chosen with the button, else the browser's
  const locale = pickLocale(event.cookies.get('locale') ?? event.request.headers.get('accept-language'));
  event.locals.locale = locale;
  const target = upstream(event.url);
  const response = target
    ? await proxy(event.request, target)
    : await resolve(event, {
        transformPageChunk: ({ html }) => html.replace('<html lang="de">', `<html lang="${locale}">`),
      });
  for (const [name, value] of Object.entries(SECURITY_HEADERS)) response.headers.set(name, value);
  return response;
};

async function proxy(request: Request, target: string) {
  const headers = new Headers(request.headers);
  headers.delete('host');
  // The session cookie is for the API only
  if (!target.startsWith(API_ORIGIN)) headers.delete('cookie');

  const res = await fetch(target, {
    method: request.method,
    headers,
    body: request.method !== 'GET' && request.method !== 'HEAD' ? request.body : undefined,
    // @ts-expect-error — Bun supports duplex
    duplex: 'half',
  });

  // fetch() already decompresses the body, so forwarding the upstream's
  // content-encoding/content-length would mismatch the actual bytes sent.
  const responseHeaders = new Headers(res.headers);
  responseHeaders.delete('content-encoding');
  responseHeaders.delete('content-length');

  return new Response(res.body, { status: res.status, statusText: res.statusText, headers: responseHeaders });
}

export const handleError: HandleServerError = ({ error }) => {
  captureException(error);
};
