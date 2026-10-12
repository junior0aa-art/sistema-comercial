-- Submesas e fechamento dividido de mesas
-- Execute depois de supabase_restaurante.sql no SQL Editor do Supabase.

alter table public.rest_pedidos
  add column if not exists submesa text;

create index if not exists rest_pedidos_mesa_submesa_idx
  on public.rest_pedidos(workspace_id, mesa_id, submesa, status);

comment on column public.rest_pedidos.submesa is
  'Identificação da conta/pessoa dentro da mesa, por exemplo A, B, 1 ou João';
