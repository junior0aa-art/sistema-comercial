-- Foto e melhorias do cadastro de produtos
-- Execute no Supabase SQL Editor.

alter table public.produtos
  add column if not exists foto_url text;

alter table public.produtos
  add column if not exists estoque_min integer not null default 5;

alter table public.produtos
  add column if not exists estoque_max integer not null default 100;

alter table public.produtos
  add column if not exists aplicacao text;

alter table public.produtos
  add column if not exists localizacao text;

create index if not exists produtos_codigo_barras_idx
  on public.produtos(workspace_id, codigo_barras);

create index if not exists produtos_localizacao_idx
  on public.produtos(workspace_id, localizacao);
