-- Módulo opcional Assistência Técnica. Execute no SQL Editor do Supabase.
alter table public.workspaces
  add column if not exists modulo_assistencia_tecnica boolean not null default false;

create table if not exists public.assistencia_ordens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  cliente_id uuid null references public.clientes(id) on delete set null,
  cliente_nome text not null,
  telefone text,
  equipamento text not null,
  marca text,
  modelo text,
  numero_serie text,
  acessorios text,
  senha_acesso text,
  tecnico text,
  data_entrada date not null default current_date,
  data_previsao date,
  data_entrega date,
  status text not null default 'recebido' check (status in ('recebido','em_diagnostico','aguardando_aprovacao','aguardando_peca','em_manutencao','pronto','entregue','cancelado')),
  garantia_dias integer not null default 90,
  problema text,
  diagnostico text,
  observacoes text,
  subtotal_servicos numeric(12,2) not null default 0,
  subtotal_pecas numeric(12,2) not null default 0,
  desconto numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists assist_ordens_workspace_status_idx on public.assistencia_ordens(workspace_id,status,data_entrada);

create table if not exists public.assistencia_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  ordem_id uuid not null references public.assistencia_ordens(id) on delete cascade,
  tipo text not null default 'servico' check (tipo in ('servico','peca')),
  descricao text not null,
  quantidade numeric(12,2) not null default 1,
  preco numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists assist_itens_ordem_idx on public.assistencia_itens(ordem_id);

create table if not exists public.assistencia_historico (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  ordem_id uuid not null references public.assistencia_ordens(id) on delete cascade,
  status_anterior text,
  status_novo text not null,
  observacao text,
  usuario_nome text,
  created_at timestamptz not null default now()
);
create index if not exists assist_historico_ordem_idx on public.assistencia_historico(ordem_id,created_at desc);

alter table public.assistencia_ordens enable row level security;
alter table public.assistencia_itens enable row level security;
alter table public.assistencia_historico enable row level security;
drop policy if exists assist_ordens_workspace on public.assistencia_ordens;
drop policy if exists assist_itens_workspace on public.assistencia_itens;
drop policy if exists assist_historico_workspace on public.assistencia_historico;
create policy assist_ordens_workspace on public.assistencia_ordens for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));
create policy assist_itens_workspace on public.assistencia_itens for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));
create policy assist_historico_workspace on public.assistencia_historico for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));
