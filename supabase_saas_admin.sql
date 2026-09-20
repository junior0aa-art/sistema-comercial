-- Controle SaaS: assinaturas, bloqueio/liberação e pagamentos
-- Execute este arquivo no Supabase SQL Editor antes de usar a Central SaaS.

alter table public.workspaces
  add column if not exists status text not null default 'ativo'
    check (status in ('ativo','bloqueado','pendente')),
  add column if not exists vencimento date,
  add column if not exists ultimo_pagamento date,
  add column if not exists bloqueado_em timestamptz,
  add column if not exists motivo_bloqueio text,
  add column if not exists valor_mensal numeric(12,2) not null default 0,
  add column if not exists observacoes_saas text;

create table if not exists public.saas_pagamentos (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id) on delete cascade,
  valor numeric(12,2) not null check (valor >= 0),
  data_pagamento date not null default current_date,
  vencimento date,
  metodo text not null default 'PIX',
  referencia text,
  observacoes text,
  criado_por uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create index if not exists saas_pagamentos_workspace_idx on public.saas_pagamentos(workspace_id);
create index if not exists workspaces_status_idx on public.workspaces(status);
create index if not exists workspaces_vencimento_idx on public.workspaces(vencimento);

alter table public.saas_pagamentos enable row level security;

-- Somente administradores SaaS podem listar ou alterar todos os workspaces.
create or replace function public.is_saas_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.usuarios u
    where u.auth_id = auth.uid()
      and u.role = 'superadmin'
      and u.status = 'ativo'
  );
$$;

revoke all on function public.is_saas_admin() from public;
grant execute on function public.is_saas_admin() to authenticated;

create policy "saas admins read payments" on public.saas_pagamentos
  for select to authenticated using (public.is_saas_admin());
create policy "saas admins insert payments" on public.saas_pagamentos
  for insert to authenticated with check (public.is_saas_admin());

create or replace function public.admin_saas_listar_workspaces()
returns table (
  id uuid, nome text, plano text, status text, vencimento date,
  ultimo_pagamento date, bloqueado_em timestamptz, motivo_bloqueio text,
  valor_mensal numeric, total_usuarios bigint, total_vendas bigint,
  receita_total numeric
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_saas_admin() then
    raise exception 'Acesso restrito à administração SaaS';
  end if;
  return query
    select w.id, w.nome, w.plano, w.status, w.vencimento, w.ultimo_pagamento,
           w.bloqueado_em, w.motivo_bloqueio, w.valor_mensal,
           (select count(*) from public.usuarios u where u.workspace_id = w.id),
           (select count(*) from public.vendas v where v.workspace_id = w.id),
           coalesce((select sum(v.total) from public.vendas v where v.workspace_id = w.id),0)
    from public.workspaces w
    order by case w.status when 'bloqueado' then 1 when 'pendente' then 2 else 0 end,
             w.nome;
end;
$$;

create or replace function public.admin_saas_atualizar_workspace(
  p_workspace_id uuid,
  p_status text,
  p_plano text default null,
  p_vencimento date default null,
  p_valor_mensal numeric default null,
  p_motivo text default null
)
returns public.workspaces
language plpgsql
security definer
set search_path = public
as $$
declare result public.workspaces;
begin
  if not public.is_saas_admin() then
    raise exception 'Acesso restrito à administração SaaS';
  end if;
  if p_status not in ('ativo','bloqueado','pendente') then
    raise exception 'Status inválido';
  end if;
  update public.workspaces
  set status = p_status,
      plano = coalesce(p_plano, plano),
      vencimento = p_vencimento,
      valor_mensal = coalesce(p_valor_mensal, valor_mensal),
      motivo_bloqueio = case when p_status = 'bloqueado' then p_motivo else null end,
      bloqueado_em = case when p_status = 'bloqueado' then coalesce(bloqueado_em, now()) else null end
  where id = p_workspace_id
  returning * into result;
  if result.id is null then raise exception 'Workspace não encontrado'; end if;
  return result;
end;
$$;

create or replace function public.admin_saas_registrar_pagamento(
  p_workspace_id uuid,
  p_valor numeric,
  p_data_pagamento date,
  p_vencimento date,
  p_metodo text,
  p_referencia text default null,
  p_observacoes text default null
)
returns public.saas_pagamentos
language plpgsql
security definer
set search_path = public
as $$
declare result public.saas_pagamentos;
begin
  if not public.is_saas_admin() then
    raise exception 'Acesso restrito à administração SaaS';
  end if;
  insert into public.saas_pagamentos(workspace_id,valor,data_pagamento,vencimento,metodo,referencia,observacoes,criado_por)
  values(p_workspace_id,p_valor,coalesce(p_data_pagamento,current_date),p_vencimento,coalesce(p_metodo,'PIX'),p_referencia,p_observacoes,auth.uid())
  returning * into result;
  update public.workspaces
  set ultimo_pagamento = result.data_pagamento,
      vencimento = coalesce(result.vencimento, vencimento),
      status = 'ativo', bloqueado_em = null, motivo_bloqueio = null
  where id = p_workspace_id;
  return result;
end;
$$;

revoke all on function public.admin_saas_listar_workspaces() from public;
revoke all on function public.admin_saas_atualizar_workspace(uuid,text,text,date,numeric,text) from public;
revoke all on function public.admin_saas_registrar_pagamento(uuid,numeric,date,date,text,text,text) from public;
grant execute on function public.admin_saas_listar_workspaces() to authenticated;
grant execute on function public.admin_saas_atualizar_workspace(uuid,text,text,date,numeric,text) to authenticated;
grant execute on function public.admin_saas_registrar_pagamento(uuid,numeric,date,date,text,text,text) to authenticated;

-- Depois de executar a migração, promova seu usuário de administração SaaS:
-- update public.usuarios set role = 'superadmin' where email = 'SEU_EMAIL_ADMIN';
