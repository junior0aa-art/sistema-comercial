-- Endurecimento de segurança (RLS, cadastro e colunas sensíveis)
-- Execute no Supabase SQL Editor DEPOIS dos demais arquivos supabase_*.sql.
-- Pode ser executado mais de uma vez. Leia os comentários antes de rodar.

-- ============================================================
-- 0) DIAGNÓSTICO (rode estas consultas primeiro e confira o resultado)
-- ============================================================
-- Tabelas sem RLS (o resultado deve ser VAZIO):
--   select tablename from pg_tables
--   where schemaname='public' and not rowsecurity;
--
-- Políticas existentes em usuarios e workspaces (confira se um usuário comum
-- consegue alterar o próprio "role" ou os campos de cobrança):
--   select tablename, policyname, cmd, roles, qual, with_check
--   from pg_policies where schemaname='public'
--   and tablename in ('usuarios','workspaces') order by 1,2;

-- ============================================================
-- 1) Cadastro: não aceitar auth_id de terceiros nem escolher plano
-- ============================================================
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
  v_auth_email text;
begin
  -- Quem está logado só pode criar empresa para si mesmo.
  if auth.uid() is not null and auth.uid() <> p_auth_id then
    raise exception 'Operação não permitida';
  end if;

  -- O usuário precisa existir no Auth, com o mesmo e-mail informado.
  select email into v_auth_email from auth.users where id = p_auth_id;
  if v_auth_email is null or lower(v_auth_email) <> lower(coalesce(p_email,'')) then
    raise exception 'Operação não permitida';
  end if;

  -- Cada usuário do Auth só pode ter um cadastro inicial.
  if exists (select 1 from public.usuarios where auth_id = p_auth_id) then
    raise exception 'Usuário já cadastrado';
  end if;

  if length(trim(coalesce(p_nome_empresa,''))) < 2 then
    raise exception 'Informe o nome da empresa';
  end if;

  if v_segmento not in (
    'comercial', 'restaurante', 'clinica', 'barbearia',
    'comercial_restaurante', 'comercial_clinica', 'comercial_barbearia'
  ) then
    v_segmento := 'comercial';
  end if;

  -- O plano inicial é sempre "free", independente do que o navegador enviar.
  -- Sinaliza ao trigger de usuarios que este é o cadastro inicial legítimo.
  perform set_config('app.cadastro_inicial', '1', true);

  insert into public.workspaces (nome, plano, segmento, trial_started_at, trial_days, status)
  values (trim(p_nome_empresa), 'free', v_segmento, now(), 14, 'ativo')
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

revoke all on function public.criar_workspace_e_usuario_segmento(text,text,uuid,text,text,text) from public;
grant execute on function public.criar_workspace_e_usuario_segmento(text,text,uuid,text,text,text)
  to anon, authenticated;

-- ============================================================
-- 2) workspaces: só a administração SaaS altera cobrança/bloqueio/trial
--    (sem isso, um cliente poderia se desbloquear pelo console do navegador)
-- ============================================================
create or replace function public.proteger_colunas_workspaces()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- auth.uid() nulo = SQL Editor / service role: liberado.
  if auth.uid() is null or public.is_saas_admin() then
    return new;
  end if;
  if new.status            is distinct from old.status
  or new.vencimento        is distinct from old.vencimento
  or new.ultimo_pagamento  is distinct from old.ultimo_pagamento
  or new.bloqueado_em      is distinct from old.bloqueado_em
  or new.motivo_bloqueio   is distinct from old.motivo_bloqueio
  or new.valor_mensal      is distinct from old.valor_mensal
  or new.observacoes_saas  is distinct from old.observacoes_saas
  or new.trial_started_at  is distinct from old.trial_started_at
  or new.trial_days        is distinct from old.trial_days then
    raise exception 'Campo reservado à administração do sistema';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_colunas_workspaces on public.workspaces;
create trigger trg_proteger_colunas_workspaces
  before update on public.workspaces
  for each row execute function public.proteger_colunas_workspaces();

-- ============================================================
-- 3) usuarios: impedir escalada de privilégio
-- ============================================================
create or replace function public.proteger_colunas_usuarios()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_role text;
begin
  if auth.uid() is null or public.is_saas_admin()
     or current_setting('app.cadastro_inicial', true) = '1' then
    return new;
  end if;

  -- Ninguém além da administração SaaS cria ou vira "superadmin".
  if new.role = 'superadmin' then
    raise exception 'Perfil reservado à administração do sistema';
  end if;

  if tg_op = 'INSERT' then
    -- Convites só podem ser feitos por admin da mesma empresa.
    select u.role into v_role from public.usuarios u
     where u.auth_id = auth.uid() and u.workspace_id = new.workspace_id
       and u.status = 'ativo' limit 1;
    if v_role is null or v_role <> 'admin' then
      raise exception 'Somente administradores podem convidar usuários';
    end if;
    return new;
  end if;

  -- UPDATE
  if new.auth_id is distinct from old.auth_id
  or new.workspace_id is distinct from old.workspace_id then
    raise exception 'Não é permitido mover usuário entre empresas';
  end if;

  if new.role is distinct from old.role or new.status is distinct from old.status then
    select u.role into v_role from public.usuarios u
     where u.auth_id = auth.uid() and u.workspace_id = old.workspace_id
       and u.status = 'ativo' limit 1;
    if v_role is null or v_role <> 'admin' then
      raise exception 'Somente administradores podem alterar perfil ou status';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_proteger_colunas_usuarios on public.usuarios;
create trigger trg_proteger_colunas_usuarios
  before insert or update on public.usuarios
  for each row execute function public.proteger_colunas_usuarios();
