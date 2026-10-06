-- Período de teste do plano Free e controle pela Central SaaS
-- Execute no SQL Editor do Supabase.

alter table public.workspaces
  add column if not exists trial_started_at timestamptz not null default now(),
  add column if not exists trial_days integer not null default 14;

-- Corrige valores inválidos sem alterar a data inicial já gravada.
update public.workspaces set trial_days = 14 where trial_days is null or trial_days < 0;

alter table public.workspaces
  drop constraint if exists workspaces_trial_days_check;
alter table public.workspaces
  add constraint workspaces_trial_days_check check (trial_days >= 0 and trial_days <= 36500);

-- Novo cadastro já começa com o período padrão de 14 dias.
create or replace function public.criar_workspace_e_usuario_segmento(
  p_nome_empresa text,
  p_plano text,
  p_auth_id uuid,
  p_nome_usuario text,
  p_email text,
  p_segmento text default 'comercial'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_workspace_id uuid;
  v_segmento text := lower(trim(coalesce(p_segmento, 'comercial')));
begin
  if v_segmento not in (
    'comercial', 'restaurante', 'clinica', 'barbearia',
    'comercial_restaurante', 'comercial_clinica', 'comercial_barbearia'
  ) then
    v_segmento := 'comercial';
  end if;

  insert into public.workspaces (nome, plano, segmento, trial_started_at, trial_days, status)
  values (p_nome_empresa, coalesce(nullif(p_plano,''),'free'), v_segmento, now(), 14, 'ativo')
  returning id into v_workspace_id;

  insert into public.usuarios (workspace_id, auth_id, nome, email, role, status)
  values (v_workspace_id, p_auth_id, p_nome_usuario, p_email, 'admin', 'ativo');

  return jsonb_build_object(
    'workspace_id', v_workspace_id,
    'segmento', v_segmento,
    'trial_days', 14
  );
end;
$$;

grant execute on function public.criar_workspace_e_usuario_segmento(text,text,uuid,text,text,text)
to anon, authenticated;

-- Lista a Central SaaS com os dados do teste.
drop function if exists public.admin_saas_listar_workspaces();
create function public.admin_saas_listar_workspaces()
returns table (
  id uuid, nome text, plano text, status text, vencimento date,
  ultimo_pagamento date, bloqueado_em timestamptz, motivo_bloqueio text,
  valor_mensal numeric, total_usuarios bigint, total_vendas bigint,
  receita_total numeric, trial_days integer, trial_started_at timestamptz,
  trial_ends_at date
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
           coalesce((select sum(v.total) from public.vendas v where v.workspace_id = w.id),0),
           coalesce(w.trial_days,14), w.trial_started_at,
           (w.trial_started_at::date + coalesce(w.trial_days,14))::date
    from public.workspaces w
    order by case w.status when 'bloqueado' then 1 when 'pendente' then 2 else 0 end,
             w.nome;
end;
$$;

drop function if exists public.admin_saas_configurar_trial(uuid,integer);
create function public.admin_saas_configurar_trial(
  p_workspace_id uuid,
  p_trial_days integer
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
  if p_trial_days is null or p_trial_days < 0 or p_trial_days > 36500 then
    raise exception 'Informe uma quantidade de dias entre 0 e 36500';
  end if;
  update public.workspaces
     set trial_days = p_trial_days
   where id = p_workspace_id
   returning * into result;
  if result.id is null then raise exception 'Workspace não encontrado'; end if;
  return result;
end;
$$;

revoke all on function public.admin_saas_listar_workspaces() from public;
revoke all on function public.admin_saas_configurar_trial(uuid,integer) from public;
grant execute on function public.admin_saas_listar_workspaces() to authenticated;
grant execute on function public.admin_saas_configurar_trial(uuid,integer) to authenticated;
