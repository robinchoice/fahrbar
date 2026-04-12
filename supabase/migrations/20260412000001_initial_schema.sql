-- Enable PostGIS for geo queries
create extension if not exists postgis;

-- ============================================================
-- PROFILES (extends auth.users)
-- ============================================================
create table public.profiles (
  id                      uuid primary key references auth.users(id) on delete cascade,
  display_name            text,
  phone                   text,
  avatar_url              text,
  driver_license_verified boolean not null default false,
  driver_license_url      text,
  stripe_customer_id      text,
  stripe_account_id       text,   -- for payouts via Stripe Connect
  rating_avg              numeric(3, 2) not null default 0,
  rating_count            integer not null default 0,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view all profiles"
  on public.profiles for select using (true);

create policy "Users can update own profile"
  on public.profiles for update using (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- CARS
-- ============================================================
create table public.cars (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references public.profiles(id) on delete cascade,
  make            text not null,
  model           text not null,
  year            integer not null,
  license_plate   text not null,
  color           text,
  seats           integer not null default 5,
  fuel_type       text not null default 'gasoline', -- gasoline | diesel | electric | hybrid
  transmission    text not null default 'manual',   -- manual | automatic
  price_per_hour  numeric(10, 2) not null,
  price_per_day   numeric(10, 2) not null,
  currency        text not null default 'EUR',
  location        geography(Point, 4326),
  address         text,
  is_available    boolean not null default true,
  photos          text[] not null default '{}',
  features        text[] not null default '{}',
  rating_avg      numeric(3, 2) not null default 0,
  rating_count    integer not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

alter table public.cars enable row level security;

create policy "Anyone can view available cars"
  on public.cars for select using (true);

create policy "Owners can insert their cars"
  on public.cars for insert with check (auth.uid() = owner_id);

create policy "Owners can update their cars"
  on public.cars for update using (auth.uid() = owner_id);

create policy "Owners can delete their cars"
  on public.cars for delete using (auth.uid() = owner_id);

-- Spatial index for nearby queries
create index cars_location_idx on public.cars using gist(location);

-- ============================================================
-- DRIVER PROFILES
-- ============================================================
create table public.driver_profiles (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null unique references public.profiles(id) on delete cascade,
  is_available     boolean not null default false,
  current_location geography(Point, 4326),
  hourly_rate      numeric(10, 2) not null,
  bio              text,
  service_radius_km integer not null default 20,
  rating_avg       numeric(3, 2) not null default 0,
  rating_count     integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

alter table public.driver_profiles enable row level security;

create policy "Anyone can view driver profiles"
  on public.driver_profiles for select using (true);

create policy "Users can manage own driver profile"
  on public.driver_profiles for all using (auth.uid() = user_id);

create index driver_profiles_location_idx on public.driver_profiles using gist(current_location);

-- ============================================================
-- BOOKINGS
-- ============================================================
create type booking_type as enum ('carshare', 'driver');
create type booking_status as enum (
  'pending', 'confirmed', 'active', 'completed',
  'rejected', 'cancelled', 'dispute'
);

create table public.bookings (
  id                       uuid primary key default gen_random_uuid(),
  type                     booking_type not null,
  car_id                   uuid references public.cars(id),        -- null for driver bookings
  driver_id                uuid references public.driver_profiles(id), -- null for carshare
  renter_id                uuid not null references public.profiles(id),
  owner_id                 uuid not null references public.profiles(id),
  status                   booking_status not null default 'pending',
  start_time               timestamptz not null,
  end_time                 timestamptz not null,
  total_price              numeric(10, 2) not null,
  platform_fee             numeric(10, 2) not null,
  owner_payout             numeric(10, 2) not null,
  stripe_payment_intent_id text,
  key_handover_at          timestamptz,
  key_return_at            timestamptz,
  created_at               timestamptz not null default now(),
  updated_at               timestamptz not null default now(),

  constraint booking_type_check check (
    (type = 'carshare' and car_id is not null) or
    (type = 'driver' and driver_id is not null)
  )
);

alter table public.bookings enable row level security;

create policy "Parties can view their bookings"
  on public.bookings for select
  using (auth.uid() = renter_id or auth.uid() = owner_id);

create policy "Renters can create bookings"
  on public.bookings for insert with check (auth.uid() = renter_id);

create policy "Parties can update their bookings"
  on public.bookings for update
  using (auth.uid() = renter_id or auth.uid() = owner_id);

-- ============================================================
-- PAYMENTS (ledger)
-- ============================================================
create table public.payments (
  id                       uuid primary key default gen_random_uuid(),
  booking_id               uuid not null references public.bookings(id),
  payer_id                 uuid not null references public.profiles(id),
  amount                   numeric(10, 2) not null,
  currency                 text not null default 'EUR',
  stripe_payment_intent_id text,
  status                   text not null default 'pending', -- pending | captured | refunded | failed
  created_at               timestamptz not null default now()
);

alter table public.payments enable row level security;

create policy "Parties can view their payments"
  on public.payments for select
  using (auth.uid() = payer_id);

-- ============================================================
-- DAMAGE REPORTS
-- ============================================================
create table public.damage_reports (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references public.bookings(id),
  reporter_id uuid not null references public.profiles(id),
  phase       text not null, -- pre_trip | post_trip
  photos      text[] not null default '{}',
  description text,
  created_at  timestamptz not null default now()
);

alter table public.damage_reports enable row level security;

create policy "Parties can view damage reports for their bookings"
  on public.damage_reports for select
  using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
  );

create policy "Parties can insert damage reports"
  on public.damage_reports for insert
  with check (auth.uid() = reporter_id);

-- ============================================================
-- MESSAGES
-- ============================================================
create table public.messages (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references public.bookings(id),
  sender_id   uuid not null references public.profiles(id),
  body        text not null,
  created_at  timestamptz not null default now()
);

alter table public.messages enable row level security;

create policy "Parties can view messages for their bookings"
  on public.messages for select
  using (
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
  );

create policy "Parties can send messages"
  on public.messages for insert
  with check (
    auth.uid() = sender_id and
    exists (
      select 1 from public.bookings b
      where b.id = booking_id
        and (b.renter_id = auth.uid() or b.owner_id = auth.uid())
    )
  );

-- ============================================================
-- REVIEWS
-- ============================================================
create table public.reviews (
  id          uuid primary key default gen_random_uuid(),
  booking_id  uuid not null references public.bookings(id),
  reviewer_id uuid not null references public.profiles(id),
  reviewee_id uuid not null references public.profiles(id),
  rating      integer not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now(),

  unique (booking_id, reviewer_id)
);

alter table public.reviews enable row level security;

create policy "Anyone can view reviews"
  on public.reviews for select using (true);

create policy "Users can create one review per booking"
  on public.reviews for insert with check (auth.uid() = reviewer_id);

-- ============================================================
-- HELPER: update updated_at on row change
-- ============================================================
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_updated_at before update on public.profiles
  for each row execute procedure public.set_updated_at();
create trigger set_updated_at before update on public.cars
  for each row execute procedure public.set_updated_at();
create trigger set_updated_at before update on public.driver_profiles
  for each row execute procedure public.set_updated_at();
create trigger set_updated_at before update on public.bookings
  for each row execute procedure public.set_updated_at();
