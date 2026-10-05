-- Cadastro de produtos: tabela base + foto e campos complementares
-- Execute este arquivo inteiro no Supabase SQL Editor.
-- Pode ser executado mais de uma vez com segurança.

create table if not exists public.produtos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null,
  codigo text,
  categoria text,
  marca text,
  codigo_barras text,
  unidade text not null default 'un',
  preco numeric(12,2) not null default 0,
  custo numeric(12,2) not null default 0,
  estoque integer not null default 0,
  estoque_min integer not null default 5,
  estoque_max integer not null default 100,
  fornecedor_id uuid,
  aplicacao text,
  localizacao text,
  foto_url text,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Complementa instalações antigas que já tinham a tabela produtos.
alter table public.produtos
  add column if not exists codigo text,
  add column if not exists categoria text,
  add column if not exists marca text,
  add column if not exists codigo_barras text,
  add column if not exists unidade text default 'un',
  add column if not exists preco numeric(12,2) default 0,
  add column if not exists custo numeric(12,2) default 0,
  add column if not exists estoque integer default 0,
  add column if not exists estoque_min integer default 5,
  add column if not exists estoque_max integer default 100,
  add column if not exists fornecedor_id uuid,
  add column if not exists aplicacao text,
  add column if not exists localizacao text,
  add column if not exists foto_url text,
  add column if not exists observacoes text,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now();

-- Corrige valores nulos antes de aplicar padrões obrigatórios.
update public.produtos set unidade='un' where unidade is null;
update public.produtos set preco=0 where preco is null;
update public.produtos set custo=0 where custo is null;
update public.produtos set estoque=0 where estoque is null;
update public.produtos set estoque_min=5 where estoque_min is null;
update public.produtos set estoque_max=100 where estoque_max is null;
update public.produtos set created_at=now() where created_at is null;
update public.produtos set updated_at=now() where updated_at is null;

create index if not exists produtos_workspace_idx
  on public.produtos(workspace_id);

create index if not exists produtos_codigo_barras_idx
  on public.produtos(workspace_id, codigo_barras);

create index if not exists produtos_localizacao_idx
  on public.produtos(workspace_id, localizacao);

-- Segurança por empresa.
alter table public.produtos enable row level security;

drop policy if exists produtos_workspace_access on public.produtos;
create policy produtos_workspace_access
  on public.produtos
  for all
  to authenticated
  using (
    workspace_id in (
      select u.workspace_id
      from public.usuarios u
      where u.auth_id = auth.uid()
    )
  )
  with check (
    workspace_id in (
      select u.workspace_id
      from public.usuarios u
      where u.auth_id = auth.uid()
    )
  );
