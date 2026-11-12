-- Pruebas del esquema en Postgres local (con 00_simulacion_supabase_SOLO_PRUEBAS.sql). NO ejecutar en Supabase.
create schema t;
create table t.res (ok boolean, label text, detail text);
create table t.ctx (k text primary key, v text);

-- ejecuta sql como usuario (rol authenticated) y devuelve null si funcionó o el mensaje de error
create function t.try(uid uuid, q text) returns text language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text, ''), false);
  begin
    execute 'set local role ' || case when uid is null then 'anon' else 'authenticated' end;
    execute q;
    reset role;
    return null;
  exception when others then
    reset role;
    return sqlstate || ': ' || sqlerrm;
  end;
end $$;
create function t.ok(uid uuid, label text, q text) returns void language plpgsql as $$
declare r text := t.try(uid, q);
begin insert into t.res values (r is null, label, r); end $$;
create function t.fail(uid uuid, label text, q text, frag text default '') returns void language plpgsql as $$
declare r text := t.try(uid, q);
begin insert into t.res values (r is not null and r ilike '%' || frag || '%', label, coalesce(r, 'NO falló (debía fallar)')); end $$;
-- cuenta filas visibles para uid
create function t.cnt(uid uuid, q text) returns int language plpgsql as $$
declare n int;
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text, ''), false);
  execute 'set local role ' || case when uid is null then 'anon' else 'authenticated' end;
  begin execute 'select count(*) from (' || q || ') x' into n; exception when others then n := -1; end;
  reset role; return n;
end $$;
create function t.eq(label text, got anyelement, want anyelement) returns void language plpgsql as $$
begin insert into t.res values (got is not distinct from want, label, 'obtuvo ' || coalesce(got::text,'null') || ', esperaba ' || coalesce(want::text,'null')); end $$;
create function t.inv(uid uuid, ev uuid, a text) returns text language plpgsql as $$
declare c text;
begin
  perform set_config('request.jwt.claim.sub', uid::text, false);
  set local role authenticated; select public.create_invite(ev, a) into c; reset role; return c;
end $$;
-- pasa si la sentencia falla O si no afecta ninguna fila (así bloquea RLS en UPDATE/DELETE/INSERT..SELECT)
create function t.noeffect(uid uuid, label text, q text) returns void language plpgsql as $$
declare n bigint := -1; r text;
begin
  perform set_config('request.jwt.claim.sub', coalesce(uid::text, ''), false);
  begin
    execute 'set local role authenticated'; execute q; get diagnostics n = row_count; reset role;
  exception when others then reset role; r := sqlerrm; n := 0; end;
  insert into t.res values (n = 0, label, coalesce(r, 'afectó ' || n || ' filas'));
end $$;
create function t.u(k text) returns uuid language sql as $$ select v::uuid from t.ctx where k = $1 $$;

-- usuarios
insert into auth.users (id, email) values
 ('a0000000-0000-0000-0000-000000000001','admin@x.mx'),   -- administrador de evento (AC)
 ('a0000000-0000-0000-0000-000000000002','edac@x.mx'),    -- editor AC
 ('a0000000-0000-0000-0000-000000000003','edap@x.mx'),    -- editor AP
 ('a0000000-0000-0000-0000-000000000004','edap2@x.mx'),   -- 2.º editor AP
 ('a0000000-0000-0000-0000-000000000005','ajeno@x.mx'),
 ('a0000000-0000-0000-0000-000000000006','super@x.mx'),   -- administrador general
 ('a0000000-0000-0000-0000-000000000007','edaa@x.mx'),    -- editor AA
 ('a0000000-0000-0000-0000-000000000008','edaa2@x.mx'),   -- 2.º editor AA
 ('a0000000-0000-0000-0000-000000000009','extra@x.mx');
insert into t.ctx values ('adm','a0000000-0000-0000-0000-000000000001'),('eac','a0000000-0000-0000-0000-000000000002'),
 ('eap','a0000000-0000-0000-0000-000000000003'),('eap2','a0000000-0000-0000-0000-000000000004'),
 ('out','a0000000-0000-0000-0000-000000000005'),('sup','a0000000-0000-0000-0000-000000000006'),
 ('eaa','a0000000-0000-0000-0000-000000000007'),('eaa2','a0000000-0000-0000-0000-000000000008'),
 ('ext','a0000000-0000-0000-0000-000000000009');
update public.profiles set is_superadmin = true where email = 'super@x.mx';
grant usage on schema t to authenticated, anon;
grant select on t.ctx to authenticated, anon;

do $$
declare adm uuid := t.u('adm'); eac uuid := t.u('eac'); eap uuid := t.u('eap'); eap2 uuid := t.u('eap2');
        o uuid := t.u('out'); sup uuid := t.u('sup'); eaa uuid := t.u('eaa'); eaa2 uuid := t.u('eaa2'); ext uuid := t.u('ext');
        ev uuid; c text;
begin
  -- 1. permisos globales y creación de eventos
  perform t.fail(adm, 'sin permiso de crear no puede crear evento', $q$select public.create_event('X','AC')$q$, 'permiso');
  perform t.fail(adm, 'un usuario no puede darse permiso de crear', format($q$update public.profiles set can_create_events=true where user_id=%L$q$, adm), 'permission');
  perform t.fail(adm, 'un usuario no puede hacerse superadmin', format($q$update public.profiles set is_superadmin=true where user_id=%L$q$, adm), 'permission');
  perform t.fail(adm, 'admin_list_users prohibido a no superadmin', $q$select * from public.admin_list_users()$q$, 'administrador general');
  perform t.fail(adm, 'admin_set_can_create prohibido a no superadmin', format($q$select public.admin_set_can_create(%L,true)$q$, adm), 'administrador general');
  perform t.ok(sup, 'superadmin da permiso de crear', format($q$select public.admin_set_can_create(%L,true)$q$, adm));
  perform t.eq('superadmin lista cuentas (9)', t.cnt(sup, 'select * from public.admin_list_users()'), 9);
  perform t.fail(adm, 'crear evento exige área', $q$select public.create_event('X', null)$q$, 'área');
  perform t.fail(adm, 'área inexistente', $q$select public.create_event('X', 'ZZ')$q$, 'área');
  perform t.fail(null, 'anon no crea evento', $q$select public.create_event('X','AC')$q$);
  perform set_config('request.jwt.claim.sub', adm::text, false);
  set local role authenticated; select public.create_event('Asamblea 27', 'AC') into ev; reset role;
  insert into t.ctx values ('ev', ev::text);
  perform t.eq('creador es admin del evento en AC', (select role||':'||area_id from public.members where event_id=ev and user_id=adm), 'admin:AC');
  perform t.eq('presencia sembrada (15)', (select count(*)::int from public.dept_presence where event_id = ev), 15);
  perform t.eq('opcionales apagados (3)', (select count(*)::int from public.dept_presence where event_id = ev and not present), 3);
  perform t.eq('registro de creación', (select count(*)::int from public.change_log where event_id = ev), 1);

  -- 2. directorio
  perform t.ok(adm, 'admin importa 8 personas', format($q$insert into public.people(event_id,nombre,cong) select %L, 'Persona '||g, 'Cong '||g from generate_series(1,8) g$q$, ev));
  perform t.eq('registro "Importó 8"', (select count(*)::int from public.change_log where msg = 'Importó 8 personas'), 1);
  perform t.eq('ajeno ve 0 eventos', t.cnt(o, 'select * from public.events'), 0);
  perform t.eq('ajeno ve 0 personas', t.cnt(o, 'select * from public.people'), 0);
  perform t.fail(o, 'ajeno no inserta personas', format($q$insert into public.people(event_id,nombre) values (%L,'Z')$q$, ev));
  perform t.eq('anon no lee eventos', t.cnt(null, 'select * from public.events'), -1);
  perform t.ok(null, 'anon puede llamar ping()', 'select public.ping()');

  -- 3. invitaciones y cupo (2 por área, 6 por evento)
  c := t.inv(adm, ev, 'AC');
  perform t.eq('código de 32 caracteres', length(c), 32);
  perform t.fail(o, 'ajeno no crea invitación', format($q$select public.create_invite(%L,'AC')$q$, ev), 'administrador');
  perform t.fail(adm, 'área inválida en invitación', format($q$select public.create_invite(%L,'ZZ')$q$, ev), 'Área no válida');
  perform t.fail(eac, 'código inexistente', $q$select public.accept_invite('nada')$q$, 'no válida');
  perform t.ok(eac, 'editor AC acepta invitación', format($q$select public.accept_invite(%L)$q$, c));
  perform t.eq('rol editor AC', (select role||':'||area_id from public.members where user_id = eac), 'editor:AC');
  perform t.fail(eap, 'invitación de un solo uso', format($q$select public.accept_invite(%L)$q$, c), 'utilizada');
  perform t.ok(eac, 'aceptar de nuevo siendo miembro no falla', format($q$select public.accept_invite(%L)$q$, c));
  perform t.eq('invitación gastada una vez', (select uses from public.invites where code = c), 1);
  perform t.fail(adm, 'AC ya tiene 2 (admin + editor): no más invitaciones', format($q$select public.create_invite(%L,'AC')$q$, ev), '2 usuarios');
  perform t.eq('editor no ve invitaciones', t.cnt(eac, 'select * from public.invites'), 0);
  perform t.fail(eac, 'editor no crea invitaciones', format($q$select public.create_invite(%L,'AP')$q$, ev), 'administrador');
  insert into public.invites(code, event_id, area_id, expires_at) values ('vencida', ev, 'AP', now() - interval '1 day');
  perform t.fail(eap, 'invitación vencida', $q$select public.accept_invite('vencida')$q$, 'caducó');
  c := t.inv(adm, ev, 'AP'); perform t.ok(eap,  'editor AP acepta', format($q$select public.accept_invite(%L)$q$, c));
  c := t.inv(adm, ev, 'AP'); perform t.ok(eap2, 'segundo editor AP acepta', format($q$select public.accept_invite(%L)$q$, c));
  perform t.fail(adm, 'AP lleno', format($q$select public.create_invite(%L,'AP')$q$, ev), '2 usuarios');
  insert into public.invites(code, event_id, area_id, expires_at, max_uses) values ('colada', ev, 'AP', now() + interval '1 day', 5);
  perform t.fail(ext, 'cupo también se impone al aceptar (23514)', $q$select public.accept_invite('colada')$q$, '2 usuarios');
  c := t.inv(adm, ev, 'AA'); perform t.ok(eaa,  'editor AA acepta', format($q$select public.accept_invite(%L)$q$, c));
  c := t.inv(adm, ev, 'AA'); perform t.ok(eaa2, 'segundo editor AA acepta', format($q$select public.accept_invite(%L)$q$, c));
  perform t.eq('evento con 6 miembros', (select count(*)::int from public.members where event_id = ev), 6);
  perform t.fail(adm, 'ya no hay cupo en ningún área', format($q$select public.create_invite(%L,'AA')$q$, ev), '2 usuarios');

  -- 4. asignaciones
  perform t.ok(adm, 'admin asigna presidente', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'PR',id from public.people where event_id=%L and nombre='Persona 1'$q$, ev, ev));
  perform t.ok(adm, 'admin asigna jefe de área AC', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'AC:h',id from public.people where event_id=%L and nombre='Persona 2'$q$, ev, ev));
  perform t.ok(eac, 'editor AC asigna acom:0', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'acom:0',id from public.people where event_id=%L and nombre='Persona 3'$q$, ev, ev));
  perform t.fail(eac, 'editor AC no asigna en AP (av:0)', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'av:0',id from public.people where event_id=%L and nombre='Persona 4'$q$, ev, ev), 'row-level');
  perform t.ok(eap, 'editor AP sí asigna av:0', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'av:0',id from public.people where event_id=%L and nombre='Persona 4'$q$, ev, ev));
  perform t.ok(eap2, 'el 2.º editor AP también edita su área', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'av:1',id from public.people where event_id=%L and nombre='Persona 5'$q$, ev, ev));
  perform t.fail(eac, 'editor no asigna jefe de área', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'AC:x',id from public.people where event_id=%L and nombre='Persona 6'$q$, ev, ev), 'row-level');
  perform t.fail(eac, 'editor no asigna presidente', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'PR',id from public.people where event_id=%L and nombre='Persona 6'$q$, ev, ev), 'row-level');
  perform t.fail(eac, 'una persona, una asignación (23505)', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'cont:0',id from public.people where event_id=%L and nombre='Persona 3'$q$, ev, ev), '23505');
  perform t.fail(adm, 'puesto inválido', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'xx:9',id from public.people where event_id=%L and nombre='Persona 6'$q$, ev, ev));
  perform t.noeffect(o, 'ajeno no asigna', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'cont:0',id from public.people where event_id=%L and nombre='Persona 6'$q$, ev, ev));
  perform t.eq('editor AA ve todas las asignaciones (5)', t.cnt(eaa, 'select * from public.assignments'), 5);
  perform t.eq('editor AA ve directorio completo (8)', t.cnt(eaa, 'select * from public.people'), 8);

  -- 5. presencia de departamentos
  perform t.fail(eac, 'editor AC no cambia presencia de "it" (AP)', format($q$insert into public.dept_presence values (%L,'it',true) on conflict (event_id,dept_id) do update set present=true$q$, ev), 'row-level');
  perform t.ok(eac, 'editor AC apaga "acom" (su área)', format($q$update public.dept_presence set present=false where event_id=%L and dept_id='acom'$q$, ev));
  perform t.eq('asignación de acom queda no vigente', (select live from public.assignments where event_id=ev and slot='acom:0'), false);
  perform t.ok(adm, 'persona liberada se asigna en otro dpto (bau:0)', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'bau:0',id from public.people where event_id=%L and nombre='Persona 3'$q$, ev, ev));
  perform t.fail(eac, 'reactivar acom con conflicto da mensaje claro', format($q$update public.dept_presence set present=true where event_id=%L and dept_id='acom'$q$, ev), 'Libera primero');
  perform t.ok(adm, 'admin quita a Persona 3 de bau:0', format($q$delete from public.assignments where event_id=%L and slot='bau:0'$q$, ev));
  perform t.ok(eac, 'ahora sí reactiva acom', format($q$update public.dept_presence set present=true where event_id=%L and dept_id='acom'$q$, ev));
  perform t.eq('acom vuelve a vigente', (select live from public.assignments where event_id=ev and slot='acom:0'), true);
  perform t.ok(adm, 'admin enciende opcional "ins"', format($q$update public.dept_presence set present=true where event_id=%L and dept_id='ins'$q$, ev));

  -- 6. sin participación
  perform t.ok(eac, 'editor AC marca a una persona libre', format($q$update public.people set no=true where event_id=%L and nombre='Persona 6'$q$, ev));
  perform t.fail(adm, 'no se asigna a quien está sin participación', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'cont:0',id from public.people where event_id=%L and nombre='Persona 6'$q$, ev, ev), 'sin participación');
  perform t.fail(eap, 'editor AP no marca a alguien asignado en AC', format($q$update public.people set no=true where event_id=%L and nombre='Persona 3'$q$, ev), 'fuera de tu área');
  perform t.fail(eac, 'editor AC no marca al presidente', format($q$update public.people set no=true where event_id=%L and nombre='Persona 1'$q$, ev), 'fuera de tu área');
  perform t.fail(eac, 'editor no edita datos de persona', format($q$update public.people set nombre='Otro' where event_id=%L and nombre='Persona 7'$q$, ev), 'administrador');
  perform t.noeffect(eac, 'editor no borra personas', format($q$delete from public.people where event_id=%L and nombre='Persona 7'$q$, ev));
  perform t.ok(adm, 'admin edita datos de persona', format($q$update public.people set tel='771' where event_id=%L and nombre='Persona 7'$q$, ev));
  perform t.ok(eac, 'editor AC marca a su asignado Persona 3', format($q$update public.people set no=true where event_id=%L and nombre='Persona 3'$q$, ev));
  perform t.eq('su asignación se quitó', (select count(*)::int from public.assignments where slot='acom:0'), 0);
  perform t.ok(eac, 'editor quita la marca', format($q$update public.people set no=false where event_id=%L and nombre='Persona 3'$q$, ev));
  perform t.ok(eac, 'reasigna a Persona 3 en acom:0', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'acom:0',id from public.people where event_id=%L and nombre='Persona 3'$q$, ev, ev));

  -- 7. cartas
  perform t.ok(eac, 'editor AC marca carta enviada (acom:0)', format($q$insert into public.letter_status(event_id,slot,state) values (%L,'acom:0','e')$q$, ev));
  perform t.eq('person_id fijado por la BD', (select person_id from public.letter_status where slot='acom:0'), (select id from public.people where event_id=ev and nombre='Persona 3'));
  perform t.noeffect(eac, 'editor AC no marca carta de AP', format($q$insert into public.letter_status(event_id,slot,state) values (%L,'av:0','e')$q$, ev));
  perform t.fail(adm, 'carta de puesto vacío', format($q$insert into public.letter_status(event_id,slot,state) values (%L,'lim:0','e')$q$, ev), 'nadie asignado');
  perform t.fail(adm, 'estado inválido', format($q$update public.letter_status set state='z' where event_id=%L$q$, ev));
  perform t.fail(adm, 'cartas solo para puestos de dpto', format($q$insert into public.letter_status(event_id,slot,state) values (%L,'PR','e')$q$, ev));
  perform t.eq('editor AP no ve cartas de AC', t.cnt(eap, 'select * from public.letter_status'), 0);
  perform t.eq('admin ve cartas', t.cnt(adm, 'select * from public.letter_status'), 1);
  perform t.eq('superadmin ve cartas (solo lectura)', t.cnt(sup, 'select * from public.letter_status'), 1);
  perform t.noeffect(sup, 'superadmin no edita cartas', format($q$update public.letter_status set state='a' where event_id=%L$q$, ev));
  perform t.ok(eac, 'editor cambia a Aceptó', format($q$update public.letter_status set state='a' where event_id=%L and slot='acom:0'$q$, ev));
  perform t.ok(adm, 'cambiar la persona del puesto', format($q$update public.assignments set person_id=(select id from public.people where event_id=%L and nombre='Persona 7') where event_id=%L and slot='acom:0'$q$, ev, ev));
  perform t.eq('estado de carta se reinicia', (select count(*)::int from public.letter_status), 0);
  perform t.ok(adm, 'asignaciones para carta masiva', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'lim:'||(row_number() over ())-1,id from public.people where event_id=%L and nombre in ('Persona 3','Persona 8')$q$, ev, ev));
  perform t.ok(adm, 'marcar 2 cartas enviadas de golpe', format($q$insert into public.letter_status(event_id,slot,state) values (%L,'lim:0','e'),(%L,'lim:1','e')$q$, ev, ev));
  perform t.eq('registro resumen de cartas', (select count(*)::int from public.change_log where msg = 'Marcó 2 cartas como enviadas'), 1);

  -- 8. registro
  perform t.eq('registro con quién real', (select user_name from public.change_log where msg like 'Asignó a Persona 3: Superintendente · Acomodadores' order by id limit 1), 'edac');
  perform t.eq('etiqueta de puesto', (select count(*)::int from public.change_log where msg = 'Asignó a Persona 1: Presidente de la asamblea'), 1);
  perform t.eq('editor ve el registro', (t.cnt(eaa, 'select * from public.change_log') > 5)::text, 'true');
  perform t.eq('ajeno no ve registro', t.cnt(o, 'select * from public.change_log'), 0);
  perform t.fail(adm, 'no se escribe el registro a mano', format($q$insert into public.change_log(event_id,msg) values (%L,'falso')$q$, ev));

  -- 9. miembros y cargo de administrador
  perform t.eq('editor solo ve su fila de miembros', t.cnt(eac, 'select * from public.members'), 1);
  perform t.eq('admin ve a los 6 miembros', t.cnt(adm, 'select * from public.members'), 6);
  perform t.fail(adm, 'el cargo no se cambia por UPDATE directo', format($q$update public.members set role='admin' where event_id=%L and user_id=%L$q$, ev, eac), 'permission');
  perform t.noeffect(eac, 'editor no cambia áreas de miembros', format($q$update public.members set area_id='AA' where event_id=%L and user_id=%L$q$, ev, eap));
  perform t.fail(adm, 'no se puede mover a un área llena', format($q$update public.members set area_id='AA' where event_id=%L and user_id=%L$q$, ev, eap), '2 usuarios');
  perform t.fail(adm, 'no se inserta miembro directo', format($q$insert into public.members(event_id,user_id,role,area_id) values (%L,%L,'editor','AC')$q$, ev, o));
  perform t.eq('list_members para admin', (select count(*)::int from public.list_members(ev)), 6);
  perform t.fail(eac, 'list_members prohibido a editor', format($q$select * from public.list_members(%L)$q$, ev), 'administrador');
  perform t.eq('superadmin usa list_members', t.cnt(sup, format($q$select * from public.list_members(%L)$q$, ev)), 6);
  perform t.fail(adm, 'el admin no puede salirse sin transferir', format($q$delete from public.members where event_id=%L and user_id=%L$q$, ev, adm), 'transferir');
  perform t.fail(eac, 'editor no transfiere el cargo', format($q$select public.transfer_event_admin(%L,%L)$q$, ev, eac), 'administrador');
  perform t.fail(adm, 'transferir a quien no es miembro', format($q$select public.transfer_event_admin(%L,%L)$q$, ev, o), 'no es miembro');
  perform t.ok(adm, 'admin transfiere el cargo a edac', format($q$select public.transfer_event_admin(%L,%L)$q$, ev, eac));
  perform t.eq('ahora edac es admin', (select role from public.members where event_id=ev and user_id=eac), 'admin');
  perform t.eq('adm quedó como editor en su área', (select role||':'||area_id from public.members where event_id=ev and user_id=adm), 'editor:AC');
  perform t.eq('un solo admin', (select count(*)::int from public.members where event_id=ev and role='admin'), 1);
  perform t.ok(eac, 'nuevo admin puede invitar/gestionar', format($q$select count(*) from public.list_members(%L)$q$, ev));
  perform t.noeffect(adm, 'ex-admin ya no edita datos del evento', format($q$update public.events set nombre='X' where id=%L$q$, ev));
  perform t.ok(sup, 'superadmin devuelve el cargo', format($q$select public.transfer_event_admin(%L,%L)$q$, ev, adm));
  perform t.ok(eac, 'un editor puede salirse', format($q$delete from public.members where event_id=%L and user_id=%L$q$, ev, eac));
  perform t.eq('quien salió ya no ve el evento', t.cnt(eac, 'select * from public.events'), 0);
  perform t.ok(adm, 'liberado el cupo: se invita de nuevo a AC', format($q$select public.create_invite(%L,'AC')$q$, ev));

  -- 10. datos del evento y encabezado
  perform t.noeffect(eap, 'editor no actualiza datos del evento', format($q$update public.events set nombre='X' where id=%L$q$, ev));
  perform t.ok(adm, 'admin actualiza datos del evento', format($q$update public.events set nombre='Felices', hmode='imagen', orgp='oficio' where id=%L$q$, ev));
  perform t.noeffect(sup, 'superadmin no edita datos del evento', format($q$update public.events set nombre='Y' where id=%L$q$, ev));
  perform t.fail(adm, 'no se cambia el id del evento', format($q$update public.events set id=gen_random_uuid() where id=%L$q$, ev), 'permission');
  perform t.fail(adm, 'hmode inválido', format($q$update public.events set hmode='x' where id=%L$q$, ev));
  perform t.ok(adm, 'admin sube encabezado', format($q$insert into public.event_header(event_id,image) values (%L,'data:image/png;base64,AAAA')$q$, ev));
  perform t.noeffect(eap, 'editor no cambia encabezado', format($q$update public.event_header set image='x' where event_id=%L$q$, ev));

  -- 11. administrador general
  perform t.eq('superadmin ve el evento', t.cnt(sup, 'select * from public.events'), 1);
  perform t.eq('superadmin ve personas', t.cnt(sup, 'select * from public.people'), 8);
  perform t.eq('superadmin ve asignaciones', (t.cnt(sup, 'select * from public.assignments') > 0)::text, 'true');
  perform t.noeffect(sup, 'superadmin no edita personas', format($q$update public.people set tel='999' where event_id=%L$q$, ev));
  perform t.fail(sup, 'superadmin no asigna (solo lectura)', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'cont:0',id from public.people where event_id=%L and nombre='Persona 8'$q$, ev, ev), 'row-level');
  perform t.eq('admin_events: 1 fila con 6 miembros', (select count(*)::int from public.admin_events() where members = 5 or members = 6), 1);
  perform t.fail(adm, 'admin_events prohibido a no superadmin', $q$select * from public.admin_events()$q$, 'administrador general');
  perform t.noeffect(adm, 'el admin del evento no puede borrar el evento', format($q$delete from public.events where id=%L$q$, ev));
  perform t.ok(sup, 'superadmin ve invitaciones', format($q$select count(*) from public.invites where event_id=%L$q$, ev));

  -- 12. perfiles
  perform t.ok(eap, 'usuario cambia su nombre', format($q$update public.profiles set display_name='Editor AP' where user_id=%L$q$, eap));
  perform t.eq('usuario ve solo su perfil', t.cnt(eap, 'select * from public.profiles'), 1);

  -- 13. borrar persona y borrar evento (cascadas sin errores)
  perform t.ok(adm, 'admin borra una persona asignada', format($q$delete from public.people where event_id=%L and nombre='Persona 2'$q$, ev));
  perform t.eq('su asignación desapareció', (select count(*)::int from public.assignments where slot='AC:h'), 0);
  perform t.ok(sup, 'superadmin elimina el evento completo', format($q$delete from public.events where id=%L$q$, ev));
  perform t.eq('cascada: personas', (select count(*)::int from public.people), 0);
  perform t.eq('cascada: miembros', (select count(*)::int from public.members), 0);
  perform t.eq('cascada: registro', (select count(*)::int from public.change_log), 0);
end $$;

do $$
declare sup uuid := t.u('sup'); adm uuid := t.u('adm'); ext uuid := t.u('ext'); o uuid := t.u('out');
        ev2 uuid; ev3 uuid; c text;
begin
  -- SQL Editor (sin sesión) sí puede administrar permisos; un usuario normal o anon no
  perform set_config('request.jwt.claim.sub', '', false);
  perform public.admin_set_can_create(sup, true);
  perform t.eq('SQL Editor dio permiso de crear al superadmin', (select can_create_events from public.profiles where user_id = sup), true);
  perform t.fail(o, 'usuario normal sigue sin poder', format($q$select public.admin_set_can_create(%L,true)$q$, o), 'administrador general');
  perform t.fail(null, 'anon no puede ejecutarla (sin EXECUTE)', format($q$select public.admin_set_can_create(%L,true)$q$, o), 'permission denied');

  -- el superadmin también crea y administra su propio evento
  perform set_config('request.jwt.claim.sub', sup::text, false);
  set local role authenticated; select public.create_event('Evento del superadmin', 'AA') into ev2; reset role;
  perform t.eq('superadmin es admin de su evento (AA)', (select role||':'||area_id from public.members where event_id=ev2 and user_id=sup), 'admin:AA');
  perform t.ok(sup, 'superadmin-admin edita su directorio', format($q$insert into public.people(event_id,nombre) values (%L,'Hermano X')$q$, ev2));
  perform t.ok(sup, 'superadmin-admin asigna', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'PR',id from public.people where event_id=%L$q$, ev2, ev2));

  -- y puede ser invitado como editor de área en el evento de otro
  perform set_config('request.jwt.claim.sub', adm::text, false);
  set local role authenticated; select public.create_event('Evento de otro admin', 'AC') into ev3; reset role;
  perform t.ok(adm, 'otro admin carga personas', format($q$insert into public.people(event_id,nombre) select %L,'P'||g from generate_series(1,3) g$q$, ev3));
  c := t.inv(adm, ev3, 'AP');
  perform t.ok(sup, 'superadmin acepta ser editor AP en ese evento', format($q$select public.accept_invite(%L)$q$, c));
  perform t.ok(sup, 'como editor AP asigna av:0', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'av:0',id from public.people where event_id=%L and nombre='P1'$q$, ev3, ev3));
  perform t.fail(sup, 'como editor AP no asigna en AC (acom:0)', format($q$insert into public.assignments(event_id,slot,person_id) select %L,'acom:0',id from public.people where event_id=%L and nombre='P2'$q$, ev3, ev3), 'row-level');
  perform t.eq('superadmin sigue viendo todos los eventos (2)', t.cnt(sup, 'select * from public.events'), 2);
  perform t.eq('el otro admin solo ve el suyo', t.cnt(adm, 'select * from public.events'), 1);
  perform t.ok(sup, 'superadmin elimina el evento ajeno donde es editor', format($q$delete from public.events where id=%L$q$, ev3));
  perform t.eq('evento ajeno eliminado', (select count(*)::int from public.events where id = ev3), 0);
  perform t.ok(sup, 'superadmin elimina su propio evento', format($q$delete from public.events where id=%L$q$, ev2));
end $$;

do $$
declare adm uuid := t.u('adm'); eac uuid := t.u('eac'); eap uuid := t.u('eap'); eap2 uuid := t.u('eap2');
        o uuid := t.u('out'); sup uuid := t.u('sup'); ev uuid; c text; n int;
begin
  -- escenario: evento con admin (AC), eac (AC), eap (AP), eap2 (AP)
  perform set_config('request.jwt.claim.sub', adm::text, false);
  set local role authenticated; select public.create_event('Evento cartas', 'AC') into ev; reset role;
  c := t.inv(adm, ev, 'AC'); perform t.ok(eac,  'eac se une', format($q$select public.accept_invite(%L)$q$, c));
  c := t.inv(adm, ev, 'AP'); perform t.ok(eap,  'eap se une', format($q$select public.accept_invite(%L)$q$, c));
  c := t.inv(adm, ev, 'AP'); perform t.ok(eap2, 'eap2 se une', format($q$select public.accept_invite(%L)$q$, c));
  perform t.ok(adm, 'personas', format($q$insert into public.people(event_id,nombre) select %L,'P'||g from generate_series(1,4) g$q$, ev));
  perform t.ok(adm, 'asigna acom:0 (AC) y av:0 (AP)', format($q$insert into public.assignments(event_id,slot,person_id) select %L, case nombre when 'P1' then 'acom:0' else 'av:0' end, id from public.people where event_id=%L and nombre in ('P1','P2')$q$, ev, ev));
  perform t.ok(adm, 'cartas de ambas áreas', format($q$insert into public.letter_status(event_id,slot,state) values (%L,'acom:0','e'),(%L,'av:0','p')$q$, ev, ev));

  -- antes de pedir permiso
  perform t.eq('editor AP ve solo las cartas de su área', t.cnt(eap, 'select * from public.letter_status'), 1);
  perform t.eq('editor AC ve solo las de su área', t.cnt(eac, 'select * from public.letter_status'), 1);

  -- solicitud
  perform t.fail(o, 'ajeno no puede pedir acceso', format($q$select public.request_letters_access(%L)$q$, ev), 'No eres miembro');
  perform t.fail(adm, 'el admin no necesita pedirlo', format($q$select public.request_letters_access(%L)$q$, ev), 'ya ves todas');
  perform t.ok(eap, 'editor AP solicita acceso', format($q$select public.request_letters_access(%L)$q$, ev));
  perform t.eq('estado pendiente', (select status from public.letter_access where user_id = eap), 'pending');
  perform t.eq('pendiente no da acceso aún', t.cnt(eap, 'select * from public.letter_status'), 1);
  perform t.ok(eap, 'pedir dos veces no falla ni duplica', format($q$select public.request_letters_access(%L)$q$, ev));
  perform t.eq('una sola fila', (select count(*)::int from public.letter_access), 1);
  perform t.eq('el solicitante ve su propia solicitud', t.cnt(eap, 'select * from public.letter_access'), 1);
  perform t.eq('otro editor no ve solicitudes ajenas', t.cnt(eac, 'select * from public.letter_access'), 0);
  perform t.eq('el compañero de área tampoco', t.cnt(eap2, 'select * from public.letter_access'), 0);
  perform t.eq('admin ve la solicitud', t.cnt(adm, 'select * from public.letter_access'), 1);
  perform t.eq('superadmin ve la solicitud', t.cnt(sup, 'select * from public.letter_access'), 1);
  perform t.eq('la solicitud no se registra', (select count(*)::int from public.change_log where msg ilike '%solicit%' or msg ilike '%acceso%'), 0);

  -- nadie se autoriza solo ni escribe directo
  perform t.fail(eap, 'el editor no se aprueba a sí mismo', format($q$select public.decide_letters_access(%L,%L,true)$q$, ev, eap), 'administrador');
  perform t.fail(eap, 'sin escritura directa (insert)', format($q$insert into public.letter_access(event_id,user_id,status) values (%L,%L,'approved')$q$, ev, eap2), 'permission');
  perform t.fail(eap, 'sin escritura directa (update)', format($q$update public.letter_access set status='approved' where user_id=%L$q$, eap), 'permission');
  perform t.fail(o, 'ajeno no decide', format($q$select public.decide_letters_access(%L,%L,true)$q$, ev, eap), 'administrador');
  perform t.fail(adm, 'decidir sobre quien no es miembro', format($q$select public.decide_letters_access(%L,%L,true)$q$, ev, o), 'no es miembro');

  -- aprobación
  perform t.ok(adm, 'admin aprueba', format($q$select public.decide_letters_access(%L,%L,true)$q$, ev, eap));
  perform t.eq('estado aprobado', (select status from public.letter_access where user_id = eap), 'approved');
  perform t.eq('ahora ve las cartas de todas las áreas', t.cnt(eap, 'select * from public.letter_status'), 2);
  perform t.eq('su compañero de área NO hereda el permiso', t.cnt(eap2, 'select * from public.letter_status'), 1);
  perform t.noeffect(eap, 'con acceso sigue sin poder cambiar cartas de otra área', format($q$update public.letter_status set state='a' where event_id=%L and slot='acom:0'$q$, ev));
  perform t.noeffect(eap, 'ni borrarlas', format($q$delete from public.letter_status where event_id=%L and slot='acom:0'$q$, ev));
  perform t.ok(eap, 'sí cambia las de su propia área', format($q$update public.letter_status set state='e' where event_id=%L and slot='av:0'$q$, ev));
  perform t.eq('el registro anota la aprobación', (select count(*)::int from public.change_log where msg like 'Dio acceso a % para ver las cartas de todas las áreas'), 1);
  perform t.ok(eap, 'pedir de nuevo con acceso aprobado no rompe', format($q$select public.request_letters_access(%L)$q$, ev));
  perform t.eq('sigue aprobado', (select status from public.letter_access where user_id = eap), 'approved');

  -- revocación por el administrador general (respaldo)
  perform t.ok(sup, 'superadmin revoca', format($q$select public.decide_letters_access(%L,%L,false)$q$, ev, eap));
  perform t.eq('vuelve a ver solo su área', t.cnt(eap, 'select * from public.letter_status'), 1);
  perform t.eq('el registro anota la revocación', (select count(*)::int from public.change_log where msg like 'Quitó a % el acceso a las cartas de todas las áreas'), 1);

  -- volver a pedir tras denegación, y denegar una solicitud pendiente (no se registra)
  perform t.ok(eap, 'puede volver a pedir tras la negativa', format($q$select public.request_letters_access(%L)$q$, ev));
  perform t.eq('de nuevo pendiente', (select status from public.letter_access where user_id = eap), 'pending');
  perform t.ok(adm, 'admin deniega la solicitud pendiente', format($q$select public.decide_letters_access(%L,%L,false)$q$, ev, eap));
  perform t.eq('denegar una solicitud no se registra', (select count(*)::int from public.change_log where msg like 'Quitó a % el acceso a las cartas de todas las áreas'), 1);
  perform t.eq('estado denegado', (select status from public.letter_access where user_id = eap), 'denied');

  -- concesión proactiva sin solicitud
  perform t.ok(adm, 'admin concede a eac sin solicitud previa', format($q$select public.decide_letters_access(%L,%L,true)$q$, ev, eac));
  perform t.eq('eac ve ambas áreas', t.cnt(eac, 'select * from public.letter_status'), 2);

  -- salir del evento borra el permiso
  perform t.ok(eac, 'eac sale del evento', format($q$delete from public.members where event_id=%L and user_id=%L$q$, ev, eac));
  perform t.eq('su permiso se borró en cascada', (select count(*)::int from public.letter_access where user_id = eac), 0);

  -- el traspaso del cargo conserva los permisos aprobados
  perform t.ok(adm, 'admin aprueba a eap otra vez', format($q$select public.decide_letters_access(%L,%L,true)$q$, ev, eap));
  perform t.ok(adm, 'transfiere el cargo a eap2', format($q$select public.transfer_event_admin(%L,%L)$q$, ev, eap2));
  perform t.eq('eap conserva su acceso', t.cnt(eap, 'select * from public.letter_status'), 2);
  perform t.ok(eap2, 'el nuevo admin puede decidir', format($q$select public.decide_letters_access(%L,%L,false)$q$, ev, eap));
  perform t.eq('el antiguo admin ya no puede decidir (editor)', (t.try(adm, format($q$select public.decide_letters_access(%L,%L,true)$q$, ev, eap)) is not null)::text, 'true');

  -- tiempo real y SQL Editor
  perform t.eq('letter_access publicada en Realtime', (select count(*)::int from pg_publication_tables where pubname='supabase_realtime' and tablename='letter_access'), 1);
  perform set_config('request.jwt.claim.sub', '', false);
  perform t.eq('SQL Editor puede decidir', (select public.decide_letters_access(ev, eap, true)), 'approved');
  perform t.ok(sup, 'limpieza: superadmin elimina el evento', format($q$delete from public.events where id=%L$q$, ev));
  perform t.eq('cascada: permisos', (select count(*)::int from public.letter_access), 0);
end $$;

select case when ok then 'PASA ' else 'FALLA' end as r, label, case when ok then '' else detail end as detalle from t.res order by ok, label;
select count(*) filter (where ok) as pasan, count(*) filter (where not ok) as fallan from t.res;
