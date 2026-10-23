-- Agendamentos concluídos disponíveis no PDV da Barbearia
alter table public.agenda_agendamentos
  add column if not exists pdv_faturado_at timestamptz null;

create index if not exists agenda_pdv_concluidos_idx
  on public.agenda_agendamentos(workspace_id, status, pdv_faturado_at, data);
