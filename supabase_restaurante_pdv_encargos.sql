-- PDV avulso do Restaurante, fotos e encargos de mesa
alter table public.produtos
  add column if not exists venda_rapida_restaurante boolean not null default false;

alter table public.rest_produtos
  add column if not exists venda_rapida_restaurante boolean not null default false,
  add column if not exists foto_url text null;

alter table public.vendas
  add column if not exists restaurante_cover numeric(12,2) not null default 0,
  add column if not exists restaurante_servico numeric(12,2) not null default 0;

create index if not exists produtos_pdv_restaurante_idx
  on public.produtos(workspace_id, venda_rapida_restaurante)
  where venda_rapida_restaurante = true;

create index if not exists rest_produtos_pdv_restaurante_idx
  on public.rest_produtos(workspace_id, venda_rapida_restaurante)
  where venda_rapida_restaurante = true;
