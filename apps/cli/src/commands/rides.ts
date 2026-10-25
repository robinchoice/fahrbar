import { RIDE_STATUSES } from '@app/shared';
import { z } from 'zod';
import { type Command, EXIT, Failure, str } from '../command';
import { SLUG } from '../config';

const morningSchema = z.object({
  id: z.uuid(),
  practiceId: z.uuid(),
  date: z.string(),
  start: z.string(),
  end: z.string(),
  capacity: z.number(),
});
const morningsSchema = z.object({ mornings: z.array(morningSchema.extend({ booked: z.number() })) });
// Deliberately omit payload: the CLI reports metadata without decrypting patient details.
const ridesSchema = z.object({
  morning: morningSchema,
  rides: z.array(z.object({ id: z.uuid(), status: z.enum(RIDE_STATUSES), createdAt: z.string() })),
});

export const rides: Command = {
  help: (m) => [['rides [--morning <id>]', m.cliRidesHelp]],
  options: { morning: { type: 'string' } },
  async run({ api, session, values, m }) {
    const morning = str(values.morning);
    if (morning !== undefined && !z.uuid().safeParse(morning).success) {
      throw new Failure(m.cliBadOptions('--morning <UUID>', SLUG), EXIT.usage);
    }
    if (!session) throw new Failure(m.notLoggedIn, EXIT.loggedOut);
    if (morning === undefined) {
      const data = await api.get('/team/mornings', morningsSchema);
      return {
        data,
        text: data.mornings.length
          ? data.mornings
              .map(
                (day) => `${day.id} · ${day.date} ${day.start}–${day.end} · ${m.pickups(day.booked)}/${day.capacity}`,
              )
              .join('\n')
          : m.noMorningsPlanned,
      };
    }
    const data = await api.get(`/team/mornings/${morning}/rides`, ridesSchema);
    const statuses = {
      new: m.teamStatusNew,
      confirmed: m.statusConfirmed,
      picked_up: m.statusPickedUp,
      arrived: m.statusArrived,
    };
    return {
      data,
      text: [
        `${data.morning.date} ${data.morning.start}–${data.morning.end}`,
        ...data.rides.map((ride) => `${ride.id} · ${statuses[ride.status]} · ${ride.createdAt}`),
        ...(data.rides.length ? [] : [m.noRides]),
      ].join('\n'),
    };
  },
};
