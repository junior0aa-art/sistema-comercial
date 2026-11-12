-- Ativação dos métodos Boleto e Link de pagamento por workspace.
alter table public.workspaces
  add column if not exists boleto_ativo boolean not null default false,
  add column if not exists link_pagamento_ativo boolean not null default false;
