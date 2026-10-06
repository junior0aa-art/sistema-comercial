-- Cadastro com segmento escolhido na tela de criação de conta
-- Execute no Supabase SQL Editor antes de usar o cadastro por segmento.

alter table public.workspaces
  add column if not exists segmento text not null default 'comercial';

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

  insert into public.workspaces (nome, plano, segmento)
  values (p_nome_empresa, coalesce(nullif(p_plano,''),'free'), v_segmento)
  returning id into v_workspace_id;

  insert into public.usuarios (workspace_id, auth_id, nome, email, role, status)
  values (v_workspace_id, p_auth_id, p_nome_usuario, p_email, 'admin', 'ativo');

  return jsonb_build_object(
    'workspace_id', v_workspace_id,
    'segmento', v_segmento
  );
end;
$$;

grant execute on function public.criar_workspace_e_usuario_segmento(text,text,uuid,text,text,text)
to anon, authenticated;
