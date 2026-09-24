-- Módulo opcional de restaurante
-- Execute no Supabase SQL Editor antes de ativar o segmento Restaurante.

alter table public.workspaces
  add column if not exists segmento text not null default 'comercial';

update public.workspaces set segmento='comercial' where segmento is null;

create table if not exists public.rest_mesas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  numero text not null,
  capacidade integer not null default 4,
  status text not null default 'livre' check (status in ('livre','ocupada','reservada')),
  created_at timestamptz not null default now()
);

alter table public.rest_mesas
  add column if not exists observacao text;

create table if not exists public.rest_pedidos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  mesa_id uuid not null references public.rest_mesas(id) on delete restrict,
  cliente_nome text,
  status text not null default 'aberto' check (status in ('aberto','em_preparo','pronto','encerrado','cancelado')),
  total numeric(12,2) not null default 0,
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.rest_pedido_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  pedido_id uuid not null references public.rest_pedidos(id) on delete cascade,
  produto_id uuid references public.produtos(id) on delete set null,
  nome text not null,
  quantidade numeric(12,3) not null default 1,
  preco_unitario numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists rest_mesas_workspace_idx on public.rest_mesas(workspace_id);
create index if not exists rest_pedidos_workspace_status_idx on public.rest_pedidos(workspace_id,status);
create index if not exists rest_pedidos_mesa_idx on public.rest_pedidos(mesa_id,status);
create index if not exists rest_pedido_itens_pedido_idx on public.rest_pedido_itens(pedido_id);

alter table public.rest_mesas enable row level security;
alter table public.rest_pedidos enable row level security;
alter table public.rest_pedido_itens enable row level security;

drop policy if exists rest_mesas_workspace_access on public.rest_mesas;
create policy rest_mesas_workspace_access on public.rest_mesas for all to authenticated using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid())) with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid()));
drop policy if exists rest_pedidos_workspace_access on public.rest_pedidos;
create policy rest_pedidos_workspace_access on public.rest_pedidos for all to authenticated using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid())) with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid()));
drop policy if exists rest_pedido_itens_workspace_access on public.rest_pedido_itens;
create policy rest_pedido_itens_workspace_access on public.rest_pedido_itens for all to authenticated using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid())) with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid()));
