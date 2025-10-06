-- Adds patient_email column to appointments for emailing receipts and updates
ALTER TABLE IF EXISTS appointments
  ADD COLUMN IF NOT EXISTS patient_email text;

-- Optional: indexes for quick lookup by order/payment
CREATE INDEX IF NOT EXISTS idx_appointments_order_id ON appointments(order_id);
CREATE INDEX IF NOT EXISTS idx_appointments_payment_id ON appointments(payment_id);
