-- ============================================================
-- PROFILES: personal data stays private
-- ============================================================
drop policy "Users can view all profiles" on public.profiles;

create policy "Users can view own profile"
  on public.profiles for select using (auth.uid() = id);

-- Verification, ratings and Stripe IDs are set server-side only
revoke update on public.profiles from anon, authenticated;
grant update (display_name, phone, avatar_url, driver_license_url)
  on public.profiles to authenticated;

-- ============================================================
-- CARS / DRIVER PROFILES: ratings come from reviews only
-- ============================================================
revoke insert, update on public.cars from anon, authenticated;
grant insert (owner_id, make, model, year, license_plate, color, seats, fuel_type,
              transmission, price_per_hour, price_per_day, currency, location,
              address, is_available, photos, features)
  on public.cars to authenticated;
grant update (make, model, year, license_plate, color, seats, fuel_type,
              transmission, price_per_hour, price_per_day, currency, location,
              address, is_available, photos, features)
  on public.cars to authenticated;

revoke insert, update on public.driver_profiles from anon, authenticated;
grant insert (user_id, is_available, current_location, hourly_rate, bio, service_radius_km)
  on public.driver_profiles to authenticated;
grant update (is_available, current_location, hourly_rate, bio, service_radius_km)
  on public.driver_profiles to authenticated;

-- ============================================================
-- BOOKINGS: requests are created server-side, clients only move the status
-- ============================================================
drop policy "Renters can create bookings" on public.bookings;
revoke insert, update on public.bookings from anon, authenticated;
grant update (status) on public.bookings to authenticated;

create extension if not exists btree_gist with schema extensions;

alter table public.bookings
  add constraint bookings_end_after_start check (end_time > start_time),
  add constraint bookings_no_overlap exclude using gist (
    car_id with =,
    tstzrange(start_time, end_time) with &&
  ) where (status in ('confirmed', 'active'));

-- Price: full days at the daily rate, the rest by the hour but never more
-- than another day (same as the booking flow shows)
create function public.request_booking(car_id uuid, start_time timestamptz, end_time timestamptz)
returns public.bookings
language plpgsql security definer set search_path = ''
as $$
declare
  car public.cars;
  hours numeric;
  days integer;
  total numeric(10, 2);
  fee numeric(10, 2);
  booking public.bookings;
begin
  select * into car from public.cars c
  where c.id = request_booking.car_id and c.is_available;
  if not found then
    raise exception 'Car % is not available', request_booking.car_id;
  end if;

  hours := extract(epoch from request_booking.end_time - request_booking.start_time) / 3600;
  days := floor(hours / 24);
  total := days * car.price_per_day
    + least((hours - days * 24) * car.price_per_hour, car.price_per_day);
  fee := total * 0.15;

  insert into public.bookings (type, car_id, renter_id, owner_id, start_time, end_time,
                               total_price, platform_fee, owner_payout)
  values ('carshare', car.id, auth.uid(), car.owner_id,
          request_booking.start_time, request_booking.end_time,
          total, fee, total - fee)
  returning * into booking;

  return booking;
end;
$$;

revoke execute on function public.request_booking from public, anon;
grant execute on function public.request_booking to authenticated;

-- The owner answers a request and confirms the return once the rental has
-- started. Server roles (service_role, postgres) are not restricted.
create function public.check_booking_status()
returns trigger language plpgsql set search_path = ''
as $$
begin
  if current_user <> 'authenticated' then
    return new;
  end if;

  if auth.uid() = old.owner_id and (
    (old.status = 'pending' and new.status in ('confirmed', 'rejected')) or
    (old.status = 'confirmed' and new.status = 'completed' and old.start_time <= now())
  ) then
    return new;
  end if;

  raise exception 'Status change from % to % is not allowed', old.status, new.status;
end;
$$;

create trigger check_booking_status before update of status on public.bookings
  for each row execute procedure public.check_booking_status();

-- ============================================================
-- DAMAGE REPORTS / REVIEWS: only parties of the booking
-- ============================================================
drop policy "Parties can insert damage reports" on public.damage_reports;

create policy "Parties can insert damage reports"
  on public.damage_reports for insert
  with check (
    auth.uid() = reporter_id and
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
  );

drop policy "Users can create one review per booking" on public.reviews;

create policy "Parties review each other after a completed booking"
  on public.reviews for insert
  with check (
    auth.uid() = reviewer_id and
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and b.status = 'completed'
        and (
          (b.renter_id = reviewer_id and b.owner_id = reviewee_id) or
          (b.owner_id = reviewer_id and b.renter_id = reviewee_id)
        )
    )
  );
