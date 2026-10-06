-- Exclusão de empresas pela Central SaaS
-- Execute depois de supabase_saas_admin.sql no SQL Editor do Supabase.
-- A exclusão respeita as chaves estrangeiras com ON DELETE CASCADE.

create or replace function public.admin_saas_excluir_workspace(
  p_workspace_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_nome text;
  v_total_usuarios bigint;
  v_total_vendas bigint;
begin
  if not public.is_saas_admin() then
    raise exception 'Acesso restrito à administração SaaS';
  end if;

  select w.nome,
         (select count(*) from public.usuarios u where u.workspace_id=w.id),
         (select count(*) from public.vendas v where v.workspace_id=w.id)
    into v_nome, v_total_usuarios, v_total_vendas
    from public.workspaces w
   where w.id=p_workspace_id;

  if v_nome is null then
    raise exception 'Empresa não encontrada';
  end if;

  -- Evita que o administrador exclua acidentalmente a própria empresa.
  if exists (
    select 1 from public.usuarios u
     where u.workspace_id=p_workspace_id
       and u.auth_id=auth.uid()
  ) then
    raise exception 'Não é permitido excluir a empresa do usuário administrador atual';
  end if;

  delete from public.workspaces where id=p_workspace_id;

  return jsonb_build_object(
    'id', p_workspace_id,
    'nome', v_nome,
    'usuarios_excluidos', v_total_usuarios,
    'vendas_excluidas', v_total_vendas
  );
end;
$$;

revoke all on function public.admin_saas_excluir_workspace(uuid) from public;
grant execute on function public.admin_saas_excluir_workspace(uuid) to authenticated;
