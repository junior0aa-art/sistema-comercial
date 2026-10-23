-- Comissões por vendedor/profissional e snapshots históricos
alter table public.usuarios
  add column if not exists comissao_percentual numeric(6,2) not null default 0;

alter table public.vendas
  add column if not exists vendedor_id uuid,
  add column if not exists comissao_percentual numeric(6,2) not null default 0,
  add column if not exists comissao_valor numeric(12,2) not null default 0;

alter table public.agenda_profissionais
  add column if not exists comissao_percentual numeric(6,2) not null default 0;

alter table public.agenda_agendamentos
  add column if not exists comissao_percentual numeric(6,2) not null default 0,
  add column if not exists comissao_valor numeric(12,2) not null default 0;

create index if not exists vendas_vendedor_data_idx
  on public.vendas(workspace_id, vendedor_id, data);
create index if not exists agenda_comissao_data_idx
  on public.agenda_agendamentos(workspace_id, profissional_id, data);
