-- Reviews of a car are the renters' reviews of its bookings. Bookings are
-- only visible to their parties, so a join from the client comes back empty
-- for everyone else.
create or replace function public.car_reviews(car_id uuid)
returns setof public.reviews
language sql stable security definer set search_path = ''
as $$
  select r.*
  from public.reviews r
  join public.bookings b on b.id = r.booking_id
  where b.car_id = car_reviews.car_id
    and r.reviewer_id = b.renter_id
  order by r.created_at desc;
$$;

-- Keep rating_avg/rating_count of the reviewed profile and car in sync
create or replace function public.update_ratings()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  booking public.bookings;
begin
  select * into booking from public.bookings where id = new.booking_id;

  update public.profiles
  set (rating_avg, rating_count) = (
    select coalesce(avg(rating), 0), count(*)
    from public.reviews
    where reviewee_id = new.reviewee_id
  )
  where id = new.reviewee_id;

  if booking.car_id is not null and new.reviewer_id = booking.renter_id then
    update public.cars
    set (rating_avg, rating_count) = (
      select coalesce(avg(r.rating), 0), count(*)
      from public.reviews r
      join public.bookings b on b.id = r.booking_id
      where b.car_id = booking.car_id
        and r.reviewer_id = b.renter_id
    )
    where id = booking.car_id;
  end if;

  return new;
end;
$$;

create trigger update_ratings after insert on public.reviews
  for each row execute procedure public.update_ratings();
