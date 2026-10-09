import { APP_NAME, type Morning, type Practice } from '@app/shared';
import { error } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

type Booking = { practice: Practice; mornings: Morning[]; publicKey: string | null };

// Server-rendered, so the link preview in WhatsApp names the practice
export const load: PageServerLoad = async ({ fetch, params }) => {
  const res = await fetch(`/api/v1/practices/${encodeURIComponent(params.slug)}`);
  if (res.status === 404) error(404);
  if (!res.ok) error(res.status);
  const booking: Booking = await res.json();
  return { ...booking, meta: { title: `${APP_NAME} · ${booking.practice.name}` } };
};
