-- PIX configurável e pagamentos divididos no PDV
-- Execute no Supabase SQL Editor antes de usar os novos recursos.

alter table public.workspaces
  add column if not exists pix_tipo text default 'CNPJ',
  add column if not exists pix_chave text,
  add column if not exists pix_nome text,
  add column if not exists pix_cidade text;

create table if not exists public.venda_pagamentos (
  id uuid primary key default gen_random_uuid(),
  venda_id uuid not null references public.vendas(id) on delete cascade,
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  metodo text not null,
  valor numeric(12,2) not null check (valor >= 0),
  valor_recebido numeric(12,2),
  troco numeric(12,2) not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists venda_pagamentos_venda_idx on public.venda_pagamentos(venda_id);
create index if not exists venda_pagamentos_workspace_idx on public.venda_pagamentos(workspace_id);

alter table public.venda_pagamentos enable row level security;

-- A política segue o mesmo isolamento por workspace usado no sistema.
drop policy if exists "workspace users manage sale payments" on public.venda_pagamentos;
create policy "workspace users manage sale payments" on public.venda_pagamentos
  for all to authenticated
  using (exists (
    select 1 from public.usuarios u
    where u.auth_id = auth.uid()
      and u.workspace_id = venda_pagamentos.workspace_id
      and u.status = 'ativo'
  ))
  with check (exists (
    select 1 from public.usuarios u
    where u.auth_id = auth.uid()
      and u.workspace_id = venda_pagamentos.workspace_id
      and u.status = 'ativo'
  ));
