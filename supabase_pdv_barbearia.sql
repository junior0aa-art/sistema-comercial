-- Agendamentos concluídos disponíveis no PDV da Barbearia
alter table public.agenda_agendamentos
  add column if not exists pdv_faturado_at timestamptz null;

alter table public.vendas
  add column if not exists agendamento_id uuid null;

create index if not exists agenda_pdv_concluidos_idx
  on public.agenda_agendamentos(workspace_id, status, pdv_faturado_at, data);

create index if not exists vendas_agendamento_idx
  on public.vendas(workspace_id, agendamento_id);
