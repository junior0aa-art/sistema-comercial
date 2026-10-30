-- Módulo opcional Oficina: execute no SQL Editor do Supabase
alter table public.workspaces
  add column if not exists modulo_oficina boolean not null default false;

create table if not exists public.oficina_veiculos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  cliente_id uuid null references public.clientes(id) on delete set null,
  cliente_nome text not null,
  placa text,
  marca text,
  modelo text,
  ano text,
  cor text,
  km numeric(12,1) not null default 0,
  observacoes text,
  created_at timestamptz not null default now()
);
create index if not exists oficina_veiculos_workspace_idx on public.oficina_veiculos(workspace_id);

create table if not exists public.oficina_ordens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  veiculo_id uuid null references public.oficina_veiculos(id) on delete set null,
  cliente_id uuid null references public.clientes(id) on delete set null,
  cliente_nome text not null,
  telefone text,
  placa text,
  marca_modelo text,
  ano text,
  km numeric(12,1) not null default 0,
  tecnico text,
  vendedor_id uuid null,
  data_entrada date not null default current_date,
  data_previsao date,
  status text not null default 'aberta' check (status in ('aberta','em_andamento','aguardando','pronta','entregue','cancelada')),
  problema text,
  observacoes text,
  subtotal_servicos numeric(12,2) not null default 0,
  subtotal_pecas numeric(12,2) not null default 0,
  desconto numeric(12,2) not null default 0,
  despesas numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists oficina_ordens_workspace_status_idx on public.oficina_ordens(workspace_id,status,data_entrada);

create table if not exists public.oficina_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  ordem_id uuid not null references public.oficina_ordens(id) on delete cascade,
  tipo text not null default 'servico' check (tipo in ('servico','peca')),
  descricao text not null,
  quantidade numeric(12,2) not null default 1,
  preco numeric(12,2) not null default 0,
  desconto numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  produto_id uuid null references public.produtos(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists oficina_itens_ordem_idx on public.oficina_itens(ordem_id);

alter table public.oficina_veiculos enable row level security;
alter table public.oficina_ordens enable row level security;
alter table public.oficina_itens enable row level security;
drop policy if exists oficina_veiculos_workspace on public.oficina_veiculos;
drop policy if exists oficina_ordens_workspace on public.oficina_ordens;
drop policy if exists oficina_itens_workspace on public.oficina_itens;
create policy oficina_veiculos_workspace on public.oficina_veiculos for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));
create policy oficina_ordens_workspace on public.oficina_ordens for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));
create policy oficina_itens_workspace on public.oficina_itens for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));

-- Compatibilidade caso a tabela já tenha sido criada antes desta versão
alter table public.oficina_ordens add column if not exists telefone text;
alter table public.oficina_ordens add column if not exists ano text;
