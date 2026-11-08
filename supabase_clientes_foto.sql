-- Foto do cliente.
alter table public.clientes
  add column if not exists foto_url text null;
