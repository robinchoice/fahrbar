import * as Sentry from '@sentry/browser';
import type { HandleClientError } from '@sveltejs/kit';
import posthog from 'posthog-js';
import { env } from '$env/dynamic/public';

Sentry.init({
  dsn: env.PUBLIC_SENTRY_DSN,
  environment: env.PUBLIC_SENTRY_ENVIRONMENT || 'production',
  dataCollection: {
    userInfo: false,
    cookies: false,
    httpHeaders: false,
    httpBodies: [],
    urlQueryParams: false,
    graphQL: { document: false, variables: false },
    genAI: { inputs: false, outputs: false },
    databaseQueryData: false,
    queues: false,
    stackFrameVariables: false,
    frameContextLines: 0,
  },
  maxBreadcrumbs: 0,
  tracesSampleRate: 0,
  sendClientReports: false,
  integrations: (defaults) =>
    defaults.filter((integration) => !['BrowserSession', 'Breadcrumbs', 'HttpContext'].includes(integration.name)),
  beforeSend(event) {
    delete event.request;
    delete event.user;
    return event;
  },
});

// Usage analytics, off without a key. Cookieless needs no consent banner but
// must also be switched on in the PostHog project settings. The server
// forwards /ingest to PostHog EU, so the CSP stays at 'self'.
if (env.PUBLIC_POSTHOG_KEY) {
  posthog.init(env.PUBLIC_POSTHOG_KEY, {
    api_host: '/ingest',
    ui_host: 'https://eu.posthog.com',
    defaults: '2026-08-30',
    cookieless_mode: 'always',
    disable_session_recording: true,
    capture_exceptions: false,
  });
}

export const handleError: HandleClientError = ({ error }) => {
  Sentry.captureException(error);
};
