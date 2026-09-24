-- Módulo opcional de agendamento para clínicas e barbearias
-- Execute no Supabase SQL Editor antes de ativar o segmento.

alter table public.workspaces
  add column if not exists segmento text not null default 'comercial';

create table if not exists public.agenda_profissionais (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null,
  especialidade text,
  telefone text,
  status text not null default 'ativo' check (status in ('ativo','inativo')),
  created_at timestamptz not null default now()
);

create table if not exists public.agenda_servicos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  nome text not null,
  categoria text,
  descricao text,
  tipo text not null default 'servico' check (tipo in ('servico','produto')),
  preco numeric(12,2) not null default 0,
  duracao integer not null default 30,
  status text not null default 'ativo' check (status in ('ativo','inativo')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.agenda_agendamentos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  cliente_id uuid references public.clientes(id) on delete set null,
  cliente_nome text not null,
  telefone text,
  servico_id uuid not null references public.agenda_servicos(id) on delete restrict,
  profissional_id uuid not null references public.agenda_profissionais(id) on delete restrict,
  data date not null,
  hora time not null,
  status text not null default 'agendado' check (status in ('agendado','confirmado','concluido','cancelado')),
  observacoes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists agenda_profissionais_workspace_idx on public.agenda_profissionais(workspace_id,status);
create index if not exists agenda_servicos_workspace_idx on public.agenda_servicos(workspace_id,status);
create index if not exists agenda_agendamentos_workspace_data_idx on public.agenda_agendamentos(workspace_id,data,hora);
create index if not exists agenda_agendamentos_profissional_idx on public.agenda_agendamentos(profissional_id,data);

alter table public.agenda_profissionais enable row level security;
alter table public.agenda_servicos enable row level security;
alter table public.agenda_agendamentos enable row level security;

drop policy if exists agenda_profissionais_workspace_access on public.agenda_profissionais;
create policy agenda_profissionais_workspace_access on public.agenda_profissionais for all to authenticated using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid())) with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid()));
drop policy if exists agenda_servicos_workspace_access on public.agenda_servicos;
create policy agenda_servicos_workspace_access on public.agenda_servicos for all to authenticated using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid())) with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid()));
drop policy if exists agenda_agendamentos_workspace_access on public.agenda_agendamentos;
create policy agenda_agendamentos_workspace_access on public.agenda_agendamentos for all to authenticated using (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid())) with check (workspace_id in (select u.workspace_id from public.usuarios u where u.auth_id=auth.uid()));
