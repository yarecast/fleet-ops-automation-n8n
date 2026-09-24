CREATE TABLE IF NOT EXISTS ops.inbound_events (
  event_id     text PRIMARY KEY,
  event_type   text NOT NULL,
  source       text NOT NULL DEFAULT 'samsara_mock',
  payload      jsonb NOT NULL,
  status       text NOT NULL DEFAULT 'received' CHECK (status IN ('received','processed','rejected','failed')),
  trip_id      bigint REFERENCES tmw.trips(trip_id),
  received_at  timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  is_synthetic boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS ops.review_queue (
  review_id    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source       text NOT NULL CHECK (source IN ('reconciliation','ai_low_confidence','schema_validation')),
  ref_type     text NOT NULL,
  ref_id       text NOT NULL,
  reason       text NOT NULL,
  details      jsonb NOT NULL DEFAULT '{}'::jsonb,
  status       text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','resolved','dismissed')),
  created_at   timestamptz NOT NULL DEFAULT now(),
  resolved_at  timestamptz,
  is_synthetic boolean NOT NULL DEFAULT true
);

CREATE TABLE IF NOT EXISTS ops.logs (
  log_id       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  logged_at    timestamptz NOT NULL DEFAULT now(),
  level        text NOT NULL CHECK (level IN ('debug','info','warn','error')),
  workflow     text NOT NULL,
  event_code   text NOT NULL,
  execution_id text,
  is_synthetic boolean NOT NULL DEFAULT true
);

CREATE INDEX IF NOT EXISTS review_queue_status_idx ON ops.review_queue(status);
CREATE INDEX IF NOT EXISTS inbound_events_status_idx ON ops.inbound_events(status);
