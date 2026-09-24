CREATE SCHEMA IF NOT EXISTS tmw;
CREATE SCHEMA IF NOT EXISTS sage;
CREATE SCHEMA IF NOT EXISTS ops;

CREATE TABLE IF NOT EXISTS tmw.operators (
  operator_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  operator_code text NOT NULL UNIQUE,
  display_alias text NOT NULL,
  status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active','inactive')),
  is_synthetic  boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tmw.equipment (
  equipment_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  unit_code          text NOT NULL UNIQUE,
  equipment_type     text NOT NULL CHECK (equipment_type IN ('tractor','trailer')),
  samsara_vehicle_id text UNIQUE,
  status             text NOT NULL DEFAULT 'active' CHECK (status IN ('active','maintenance','inactive')),
  is_synthetic       boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tmw.orders (
  order_id      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  order_ref     text NOT NULL UNIQUE,
  customer_code text NOT NULL,
  origin        text NOT NULL,
  destination   text NOT NULL,
  agreed_amount numeric(12,2) NOT NULL CHECK (agreed_amount >= 0),
  currency      char(3) NOT NULL DEFAULT 'USD' CHECK (currency IN ('USD','MXN')),
  delivery_due  timestamptz NOT NULL,
  is_synthetic  boolean NOT NULL DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tmw.trips (
  trip_id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  trip_ref          text NOT NULL UNIQUE,
  order_id          bigint NOT NULL REFERENCES tmw.orders(order_id),
  operator_id       bigint REFERENCES tmw.operators(operator_id),
  equipment_id      bigint REFERENCES tmw.equipment(equipment_id),
  status            text NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','dispatched','in_transit','delayed','delivered','cancelled')),
  planned_eta       timestamptz,
  current_eta       timestamptz,
  delivered_at      timestamptz,
  wait_minutes      integer NOT NULL DEFAULT 0 CHECK (wait_minutes >= 0),
  eta_deviation_min integer,
  is_synthetic      boolean NOT NULL DEFAULT true,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (status <> 'delivered' OR delivered_at IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS trips_status_idx ON tmw.trips(status);
CREATE INDEX IF NOT EXISTS trips_order_idx ON tmw.trips(order_id);
CREATE INDEX IF NOT EXISTS trips_equipment_idx ON tmw.trips(equipment_id);
