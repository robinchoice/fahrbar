-- Returns available cars within radius_m meters of (lat, lng).
-- Extracts lat/lng from PostGIS geography so the Flutter client
-- doesn't need to parse WKB.
create or replace function public.cars_nearby(
  lat double precision,
  lng double precision,
  radius_m integer default 10000
)
returns table (
  id              uuid,
  owner_id        uuid,
  make            text,
  model           text,
  year            integer,
  license_plate   text,
  color           text,
  seats           integer,
  fuel_type       text,
  transmission    text,
  price_per_hour  numeric,
  price_per_day   numeric,
  currency        text,
  latitude        double precision,
  longitude       double precision,
  address         text,
  is_available    boolean,
  photos          text[],
  features        text[],
  rating_avg      numeric,
  rating_count    integer
)
language sql stable
as $$
  select
    c.id,
    c.owner_id,
    c.make,
    c.model,
    c.year,
    c.license_plate,
    c.color,
    c.seats,
    c.fuel_type,
    c.transmission,
    c.price_per_hour,
    c.price_per_day,
    c.currency,
    st_y(c.location::geometry) as latitude,
    st_x(c.location::geometry) as longitude,
    c.address,
    c.is_available,
    c.photos,
    c.features,
    c.rating_avg,
    c.rating_count
  from public.cars c
  where
    c.is_available = true
    and st_dwithin(
      c.location,
      st_makepoint(lng, lat)::geography,
      radius_m
    )
  order by c.location <-> st_makepoint(lng, lat)::geography;
$$;
