CREATE TABLE IF NOT EXISTS sage.invoices (
  invoice_id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_ref           text NOT NULL UNIQUE,
  trip_id               bigint NOT NULL UNIQUE REFERENCES tmw.trips(trip_id),
  customer_code         text NOT NULL,
  amount                numeric(12,2) NOT NULL CHECK (amount >= 0),
  currency              char(3) NOT NULL DEFAULT 'USD' CHECK (currency IN ('USD','MXN')),
  status                text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','issued','paid','void')),
  reconciliation_status text NOT NULL DEFAULT 'pending'
                        CHECK (reconciliation_status IN ('pending','matched','partial','ambiguous','unmatched')),
  is_synthetic          boolean NOT NULL DEFAULT true,
  created_at            timestamptz NOT NULL DEFAULT now(),
  reconciled_at         timestamptz
);

CREATE TABLE IF NOT EXISTS sage.receivables (
  receivable_id  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  receivable_ref text NOT NULL,
  customer_code  text NOT NULL,
  amount_due     numeric(12,2) NOT NULL CHECK (amount_due >= 0),
  amount_paid    numeric(12,2) NOT NULL DEFAULT 0 CHECK (amount_paid >= 0),
  currency       char(3) NOT NULL DEFAULT 'USD' CHECK (currency IN ('USD','MXN')),
  status         text NOT NULL DEFAULT 'open' CHECK (status IN ('open','partial','paid')),
  invoice_id     bigint REFERENCES sage.invoices(invoice_id),
  due_date       date,
  is_synthetic   boolean NOT NULL DEFAULT true,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CHECK (amount_paid <= amount_due)
);

CREATE INDEX IF NOT EXISTS receivables_ref_idx ON sage.receivables(receivable_ref);
CREATE INDEX IF NOT EXISTS receivables_invoice_idx ON sage.receivables(invoice_id);
