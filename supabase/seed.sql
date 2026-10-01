-- Seed: Test-Anbieter + Autos in München
DO $$
DECLARE
  owner_id UUID := '00000000-0000-0000-0000-000000000001';
BEGIN
  -- Auth-User anlegen (Passwort: fahrbar123)
  INSERT INTO auth.users (
    id, instance_id, email, encrypted_password,
    email_confirmed_at, created_at, updated_at,
    raw_app_meta_data, raw_user_meta_data, aud, role,
    confirmation_token, recovery_token, email_change_token_new, email_change
  ) VALUES (
    owner_id,
    '00000000-0000-0000-0000-000000000000',
    'anbieter@fahrbar.dev',
    crypt('fahrbar123', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{"display_name":"Max Mustermann"}',
    'authenticated', 'authenticated',
    '', '', '', ''
  ) ON CONFLICT (id) DO NOTHING;

  -- Profil: Trigger handle_new_user() legt es an, wir updaten nur Stripe
  UPDATE public.profiles
  SET display_name = 'Max Mustermann', stripe_account_id = 'acct_seed_test'
  WHERE id = owner_id;

  -- Autos rund um Freiburg im Breisgau
  INSERT INTO public.cars (
    owner_id, make, model, year, license_plate, color, seats,
    fuel_type, transmission, price_per_hour, price_per_day, currency,
    location, address, is_available, features
  ) VALUES
    (owner_id, 'Volkswagen', 'Golf 8', 2022, 'FR-VW 1234', 'Silber', 5,
     'gasoline', 'automatic', 8.50, 55.00, 'EUR',
     ST_SetSRID(ST_MakePoint(7.8521, 47.9960), 4326)::geography,
     'Münsterplatz, Freiburg', true,
     ARRAY['Klimaanlage', 'Sitzheizung', 'Navigation']),

    (owner_id, 'BMW', '3er', 2021, 'FR-BM 5678', 'Schwarz', 5,
     'diesel', 'automatic', 15.00, 95.00, 'EUR',
     ST_SetSRID(ST_MakePoint(7.8350, 48.0020), 4326)::geography,
     'Güterbahnhof, Freiburg', true,
     ARRAY['Klimaautomatik', 'Sitzheizung', 'Navigation', 'Parkassistent']),

    (owner_id, 'Tesla', 'Model 3', 2023, 'FR-TS 9012', 'Weiß', 5,
     'electric', 'automatic', 22.00, 140.00, 'EUR',
     ST_SetSRID(ST_MakePoint(7.8650, 47.9890), 4326)::geography,
     'Wiehre, Freiburg', true,
     ARRAY['Autopilot', 'Wärmepumpe', 'Supercharger-Zugang']),

    (owner_id, 'Opel', 'Corsa', 2020, 'FR-OP 3456', 'Rot', 5,
     'gasoline', 'manual', 6.00, 39.00, 'EUR',
     ST_SetSRID(ST_MakePoint(7.8420, 48.0080), 4326)::geography,
     'Zähringen, Freiburg', true,
     ARRAY['Klimaanlage']),

    (owner_id, 'Mercedes-Benz', 'C-Klasse', 2022, 'FR-MB 7890', 'Silber', 5,
     'diesel', 'automatic', 18.00, 115.00, 'EUR',
     ST_SetSRID(ST_MakePoint(7.8600, 48.0010), 4326)::geography,
     'Stühlinger, Freiburg', true,
     ARRAY['Klimaautomatik', 'Sitzheizung', 'Einparkhilfe', 'Navigation'])
  ON CONFLICT DO NOTHING;
END;
$$;
