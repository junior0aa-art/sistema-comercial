-- Filiais dentro do mesmo workspace e clientes separados por segmento
-- Execute no SQL Editor do Supabase.

create table if not exists public.filiais (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null,
  codigo text,
  segmento text not null default 'comercial',
  compartilhar_clientes_segmentos boolean not null default false,
  status text not null default 'ativa' check (status in ('ativa','inativa')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.filiais
  add column if not exists codigo text,
  add column if not exists segmento text not null default 'comercial',
  add column if not exists compartilhar_clientes_segmentos boolean not null default false,
  add column if not exists status text not null default 'ativa',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

alter table public.clientes
  add column if not exists filial_id uuid references public.filiais(id) on delete set null,
  add column if not exists segmento text;

-- Registros antigos recebem o segmento atual da empresa e continuam visíveis como legado.
update public.clientes c
   set segmento = coalesce(nullif(c.segmento,''), lower(coalesce(w.segmento,'comercial')))
  from public.workspaces w
 where w.id=c.workspace_id and (c.segmento is null or c.segmento='');

create index if not exists filiais_workspace_idx on public.filiais(workspace_id,status);
create index if not exists clientes_filial_idx on public.clientes(workspace_id,filial_id);
create index if not exists clientes_segmento_idx on public.clientes(workspace_id,segmento);

alter table public.filiais enable row level security;
drop policy if exists filiais_workspace_access on public.filiais;
create policy filiais_workspace_access on public.filiais
  for all to authenticated
  using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid() and u.status='ativo'))
  with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid() and u.status='ativo'));

-- Atualiza a política de clientes para manter o isolamento por workspace.
alter table public.clientes enable row level security;
drop policy if exists clientes_workspace_access on public.clientes;
create policy clientes_workspace_access on public.clientes
  for all to authenticated
  using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid() and u.status='ativo'))
  with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid() and u.status='ativo'));
