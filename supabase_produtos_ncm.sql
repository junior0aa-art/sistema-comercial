-- Campo NCM no cadastro de produtos.
alter table public.produtos
  add column if not exists ncm text;
