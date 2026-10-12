-- Pagamento parcial de mesas divididas
-- Execute depois de supabase_restaurante_submesas.sql.

alter table public.rest_pedidos
  add column if not exists valor_original numeric(12,2),
  add column if not exists valor_pago numeric(12,2) not null default 0;

update public.rest_pedidos
   set valor_original = coalesce(valor_original, total)
 where valor_original is null;

create index if not exists rest_pedidos_saldo_idx
  on public.rest_pedidos(workspace_id, mesa_id, status, total);
