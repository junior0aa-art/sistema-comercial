create table if not exists public.compras_entradas (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  fornecedor_id uuid null references public.fornecedores(id) on delete set null,
  fornecedor_nome text,
  numero_nota text,
  serie text,
  chave_nfe text,
  pedido text,
  data_emissao date,
  data_entrada date not null default current_date,
  valor_produtos numeric(12,2) not null default 0,
  valor_frete numeric(12,2) not null default 0,
  outras_despesas numeric(12,2) not null default 0,
  valor_impostos numeric(12,2) not null default 0,
  valor_total numeric(12,2) not null default 0,
  origem text not null default 'manual' check (origem in ('manual','xml')),
  status text not null default 'confirmada' check (status in ('rascunho','confirmada','cancelada')),
  conta_pagar_id uuid null references public.contas_pagar(id) on delete set null,
  observacoes text,
  created_at timestamptz not null default now()
);
create index if not exists compras_entradas_workspace_data_idx on public.compras_entradas(workspace_id,data_entrada);
create table if not exists public.compras_itens (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  entrada_id uuid not null references public.compras_entradas(id) on delete cascade,
  produto_id uuid null references public.produtos(id) on delete set null,
  codigo_barras text,
  codigo_fornecedor text,
  descricao text not null,
  quantidade numeric(12,3) not null default 1,
  custo_unitario numeric(12,4) not null default 0,
  impostos numeric(12,2) not null default 0,
  frete numeric(12,2) not null default 0,
  outras_despesas numeric(12,2) not null default 0,
  subtotal numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists compras_itens_entrada_idx on public.compras_itens(entrada_id);
create index if not exists compras_itens_produto_idx on public.compras_itens(produto_id);

alter table public.compras_entradas enable row level security;
alter table public.compras_itens enable row level security;
drop policy if exists compras_entradas_workspace on public.compras_entradas;
drop policy if exists compras_itens_workspace on public.compras_itens;
create policy compras_entradas_workspace on public.compras_entradas for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));
create policy compras_itens_workspace on public.compras_itens for all using (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid())) with check (workspace_id in (select workspace_id from public.usuarios where auth_id=auth.uid()));

-- Percentual adicional de custo por item.
alter table public.compras_itens add column if not exists custo_percentual numeric(8,4) not null default 0;
