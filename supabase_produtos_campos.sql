-- Novos campos do cadastro de produtos
-- Execute no Supabase SQL Editor.
alter table public.produtos
  add column if not exists codigo_barras text,
  add column if not exists aplicacao text,
  add column if not exists localizacao text;

create index if not exists produtos_codigo_barras_idx
  on public.produtos (workspace_id, codigo_barras);

create index if not exists produtos_localizacao_idx
  on public.produtos (workspace_id, localizacao);
