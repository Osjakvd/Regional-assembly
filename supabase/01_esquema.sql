-- =====================================================================
-- Organización de Asamblea Regional — versión colaborativa (Supabase)
-- Fase 1 (SQL) · esquema v2 (administrador general + 6 usuarios por evento)
--
-- CÓMO EJECUTARLO: Supabase → SQL Editor → pegar TODO este archivo → Run.
-- Ejecútalo una sola vez en un proyecto nuevo. Si necesitas empezar de
-- cero, usa 99_reiniciar_SOLO_PRUEBAS.sql (borra todo lo de la app).
--
-- Nombres de columnas: en `events` y `people` se conservan los nombres
-- que ya usa la app local (nombre, tit2, recinto, ciudad, fechas, fcarta,
-- fauto, codigo, hmode, orgp / nombre, cong, tel, correo, no) para que la
-- capa de datos de la nube sea casi un copiar-y-pegar del objeto `S`.
-- =====================================================================


-- =====================================================================
-- 1. CATÁLOGO FIJO (áreas y departamentos)
-- =====================================================================
create table public.areas (
  id    text primary key,           -- AC, AP, AA
  name  text not null,
  sort  int  not null
);

create table public.departments (
  id          text primary key,     -- acom, cont, est, ...
  area_id     text not null references public.areas(id),
  name        text not null,
  optional    boolean not null default false,  -- opcional: apagado por defecto
  coordinator boolean not null default false,  -- usa "Coordinador" en vez de "Superintendente"
  av          boolean not null default false,  -- auxiliares con puesto (Audio, Video, Plataforma)
  sort        int not null
);

insert into public.areas (id, name, sort) values
  ('AC', 'Coordinador del Comité de Asamblea', 1),
  ('AP', 'Superintendente del programa',       2),
  ('AA', 'Superintendente de Alojamiento',     3);

insert into public.departments (id, area_id, name, optional, coordinator, av, sort) values
  ('acom', 'AC', 'Acomodadores',                                    false, false, false, 1),
  ('cont', 'AC', 'Contabilidad',                                    false, false, false, 2),
  ('est',  'AC', 'Estacionamiento',                                 false, false, false, 3),
  ('pa',   'AC', 'Primeros Auxilios',                               false, false, false, 4),
  ('seg',  'AC', 'Seguridad',                                       false, true,  false, 5),
  ('av',   'AP', 'Audio y Video',                                   false, false, true,  1),
  ('tinf', 'AP', 'Tecnología informática y técnicos',               true,  false, false, 2),
  ('bau',  'AP', 'Bautismo',                                        false, false, false, 3),
  ('it',   'AP', 'Interpretación táctil (solo lengua de señas)',    true,  false, false, 4),
  ('alo',  'AA', 'Alojamiento',                                     false, false, false, 1),
  ('isv',  'AA', 'Información y Servicio Voluntario',               false, false, false, 2),
  ('ins',  'AA', 'Instalación',                                     true,  false, false, 3),
  ('lim',  'AA', 'Limpieza',                                        false, false, false, 4),
  ('ogg',  'AA', 'Objetos Perdidos y Guardarropa',                  false, false, false, 5),
  ('tm',   'AA', 'Transporte y Materiales',                         true,  false, false, 6),
  ('agua', 'AA', 'Agua potable',                                    false, false, false, 7);


-- =====================================================================
-- 2. PERFILES (uno por cuenta de acceso)
-- =====================================================================
create table public.profiles (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  email             text,
  display_name      text not null default '',     -- aparece en el registro de cambios
  can_create_events boolean not null default false, -- solo quien tenga true puede crear eventos (administrador de evento)
  is_superadmin     boolean not null default false, -- administrador general: ve y elimina todos los eventos
  created_at        timestamptz not null default now()
);

-- Al registrarse alguien en Supabase Auth se crea su perfil automáticamente.
create function public.trg_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (user_id, email, display_name)
  values (
    new.id,
    new.email,
    coalesce(nullif(btrim(new.raw_user_meta_data->>'name'), ''), split_part(coalesce(new.email, ''), '@', 1))
  )
  on conflict (user_id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.trg_new_user();

-- Cuentas que ya existieran antes de ejecutar este script.
insert into public.profiles (user_id, email, display_name)
select u.id, u.email, split_part(coalesce(u.email, ''), '@', 1) from auth.users u
on conflict (user_id) do nothing;


-- =====================================================================
-- 3. EVENTOS Y MIEMBROS
-- =====================================================================
create table public.events (
  id         uuid primary key default gen_random_uuid(),
  name       text not null check (length(btrim(name)) between 1 and 200), -- nombre en el selector de eventos
  -- Datos de la asamblea (objeto S.asm de la app local):
  nombre     text not null default '',
  tit2       text not null default '',
  recinto    text not null default '',
  ciudad     text not null default '',
  fechas     text not null default '',
  fcarta     text not null default '',            -- 'DD-MM-AAAA' o vacío (= hoy)
  fauto      boolean not null default true,       -- fecha de carta automática
  codigo     text not null default '',            -- código para nombrar archivos
  hmode      text not null default 'texto' check (hmode in ('texto', 'imagen', 'ninguno')),
  orgp       text not null default 'auto'  check (orgp  in ('auto', 'carta', 'oficio')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Imagen de encabezado de las cartas (data URL), aparte para no engordar `events`.
create table public.event_header (
  event_id   uuid primary key references public.events(id) on delete cascade,
  image      text not null check (octet_length(image) <= 1500000),
  updated_at timestamptz not null default now()
);

create table public.members (
  event_id   uuid not null references public.events(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  role       text not null check (role in ('admin', 'editor')),   -- admin = administrador del evento
  area_id    text not null references public.areas(id),           -- todos pertenecen a un área
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);
create index members_user_idx on public.members (user_id);
-- Un solo administrador por evento (para cambiarlo: transfer_event_admin)
create unique index members_one_admin on public.members (event_id) where role = 'admin';

-- Invitaciones por enlace de WhatsApp (el código viaja en el enlace).
create table public.invites (
  code       text primary key default replace(gen_random_uuid()::text, '-', ''),
  event_id   uuid not null references public.events(id) on delete cascade,
  area_id    text not null references public.areas(id),   -- las invitaciones son siempre de editor de esa área
  expires_at timestamptz not null,
  max_uses   int not null default 1 check (max_uses between 1 and 100),
  uses       int not null default 0,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index invites_event_idx on public.invites (event_id);


-- =====================================================================
-- 4. DIRECTORIO, ASIGNACIONES, PRESENCIA, CARTAS, REGISTRO
-- =====================================================================
create table public.people (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  nombre     text not null check (btrim(nombre) <> ''),
  cong       text not null default '',
  tel        text not null default '',
  correo     text not null default '',
  no         boolean not null default false,       -- «sin participación»
  created_at timestamptz not null default now(),
  unique (id, event_id)                            -- permite claves foráneas compuestas
);
create index people_event_idx on public.people (event_id);

-- Claves de puesto (`slot`), igual que en la app local:
--   AC:h AC:x AP:h AP:x AA:h AA:x   responsable / auxiliar de área
--   PR                              presidente de la asamblea
--   <dept>:0 .. <dept>:3            departamento (0 = superintendente/coordinador)
create table public.assignments (
  event_id   uuid not null references public.events(id) on delete cascade,
  slot       text not null,
  person_id  uuid not null,
  live       boolean not null default true,   -- false si su departamento está "no presente" (lo calcula la BD)
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (event_id, slot),
  foreign key (person_id, event_id) references public.people (id, event_id) on delete cascade
);
-- Una persona no puede tener dos asignaciones vigentes en el mismo evento.
create unique index assignments_one_per_person on public.assignments (event_id, person_id) where live;

create table public.dept_presence (
  event_id uuid not null references public.events(id) on delete cascade,
  dept_id  text not null references public.departments(id),
  present  boolean not null,
  primary key (event_id, dept_id)
);

create table public.letter_status (
  event_id   uuid not null,
  slot       text not null check (slot ~ '^[a-z]+:[0-3]$'),   -- solo puestos de departamento
  state      text not null check (state in ('p', 'e', 'a', 'd')), -- Pendiente/Enviada/Aceptó/Declinó
  person_id  uuid not null,       -- la fija la BD a partir de la asignación
  updated_at timestamptz not null default now(),
  updated_by uuid,
  primary key (event_id, slot),
  foreign key (event_id, slot) references public.assignments (event_id, slot) on delete cascade,
  foreign key (person_id, event_id) references public.people (id, event_id) on delete cascade
);

create table public.change_log (
  id        bigint generated always as identity primary key,
  event_id  uuid not null references public.events(id) on delete cascade,
  at        timestamptz not null default now(),
  user_id   uuid,
  user_name text not null default '',
  msg       text not null
);
create index change_log_event_idx on public.change_log (event_id, at desc);


-- =====================================================================
-- 5. FUNCIONES AUXILIARES (rol, puestos, etiquetas)
-- =====================================================================
create function public.member_role(ev uuid) returns text
language sql stable security definer set search_path = '' as $$
  select m.role from public.members m where m.event_id = ev and m.user_id = auth.uid()
$$;

create function public.member_area(ev uuid) returns text
language sql stable security definer set search_path = '' as $$
  select m.area_id from public.members m where m.event_id = ev and m.user_id = auth.uid()
$$;

create function public.is_member(ev uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.members m where m.event_id = ev and m.user_id = auth.uid())
$$;

create function public.is_admin(ev uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.members m
                 where m.event_id = ev and m.user_id = auth.uid() and m.role = 'admin')
$$;

create function public.is_superadmin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((select p.is_superadmin from public.profiles p where p.user_id = auth.uid()), false)
$$;

-- ver los datos de un evento: sus miembros o el administrador general
create function public.can_read_event(ev uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.is_superadmin()
      or exists (select 1 from public.members m where m.event_id = ev and m.user_id = auth.uid())
$$;

-- id del departamento si el puesto es de departamento (…:0..3); si no, null
create function public.slot_dept(p_slot text) returns text
language sql immutable set search_path = '' as $$
  select case when p_slot ~ '^[a-z]+:[0-3]$' then split_part(p_slot, ':', 1) end
$$;

-- área a la que pertenece el puesto (null para PR o puestos inexistentes)
create function public.slot_area(p_slot text) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when p_slot ~ '^A[CPA]:[hx]$' then left(p_slot, 2)
    when p_slot ~ '^[a-z]+:[0-3]$' then
      (select d.area_id from public.departments d where d.id = split_part(p_slot, ':', 1))
  end
$$;

create function public.slot_valid(p_slot text) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_slot = 'PR' or public.slot_area(p_slot) is not null
$$;

-- ¿Puede la persona conectada asignar / quitar / ver carta de este puesto?
--   admin  → cualquier puesto válido
--   editor → solo puestos de DEPARTAMENTOS de su área (no jefes de área ni presidente)
create function public.can_edit_slot(ev uuid, p_slot text) returns boolean
language sql stable security definer set search_path = '' as $$
  select case public.member_role(ev)
    when 'admin'  then public.slot_valid(p_slot)
    when 'editor' then coalesce(public.slot_dept(p_slot) is not null
                                and public.slot_area(p_slot) = public.member_area(ev), false)
    else false
  end
$$;

create function public.can_edit_dept(ev uuid, p_dept text) returns boolean
language sql stable security definer set search_path = '' as $$
  select case public.member_role(ev)
    when 'admin'  then exists (select 1 from public.departments d where d.id = p_dept)
    when 'editor' then coalesce((select d.area_id from public.departments d where d.id = p_dept)
                                = public.member_area(ev), false)
    else false
  end
$$;

-- Texto del puesto, igual que kl() en la app: «Auxiliar · Limpieza», «Presidente de la asamblea»…
create function public.slot_label(p_slot text) returns text
language sql stable security definer set search_path = '' as $$
  select case
    when p_slot = 'PR' then 'Presidente de la asamblea'
    when p_slot ~ '^A[CPA]:[hx]$' then
      (select case when right(p_slot, 1) = 'h' then a.name else 'Auxiliar de ' || a.name end
         from public.areas a where a.id = left(p_slot, 2))
    -- bloque «Tecnología informática y técnicos»: se muestra dentro de Audio y Video
    when p_slot ~ '^tinf:[0-3]$' then
      case when right(p_slot, 1) = '0' then 'Superintendente de Tecnología informática' else 'Técnico de Audio y Video' end
    when p_slot ~ '^[a-z]+:[0-3]$' then
      (select (case
                 when split_part(p_slot, ':', 2) = '0' then (case when d.coordinator then 'Coordinador' else 'Superintendente' end)
                 when d.av then (array['Auxiliar Audio', 'Auxiliar Video', 'Auxiliar Plataforma'])[split_part(p_slot, ':', 2)::int]
                 else 'Auxiliar'
               end) || ' · ' || d.name
         from public.departments d where d.id = split_part(p_slot, ':', 1))
    else '—'
  end
$$;

create function public.letter_state_label(s text) returns text
language sql immutable set search_path = '' as $$
  select case s when 'p' then 'Pendiente' when 'e' then 'Enviada' when 'a' then 'Aceptó' when 'd' then 'Declinó' else s end
$$;

create function public.letter_state_plural(s text) returns text
language sql immutable set search_path = '' as $$
  select case s when 'p' then 'pendientes' when 'e' then 'enviadas' when 'a' then 'aceptadas' when 'd' then 'declinadas' else s end
$$;

-- Escribe en el registro con el usuario REAL. Solo la usan los triggers (no es llamable desde la API).
create function public.app_log(ev uuid, p_msg text) returns void
language plpgsql security definer set search_path = '' as $$
declare uname text;
begin
  -- si el evento ya no existe (borrado en cascada) no se registra nada
  if not exists (select 1 from public.events e where e.id = ev) then return; end if;
  select coalesce(nullif(p.display_name, ''), split_part(coalesce(p.email, ''), '@', 1))
    into uname from public.profiles p where p.user_id = auth.uid();
  insert into public.change_log (event_id, user_id, user_name, msg)
  values (ev, auth.uid(), coalesce(uname, 'Sistema'), p_msg);
end $$;


-- =====================================================================
-- 6. TRIGGERS
-- =====================================================================

-- 6.1 events: fecha de modificación
create function public.trg_touch() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

create trigger events_touch before update on public.events
  for each row execute function public.trg_touch();

-- 6.2 event_header: registro
create function public.trg_header_log() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    perform public.app_log(old.event_id, 'Quitó el encabezado de imagen');
  else
    perform public.app_log(new.event_id, 'Cargó el encabezado de imagen');
  end if;
  return null;
end $$;
create function public.trg_header_touch() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;
create trigger header_touch before insert or update on public.event_header
  for each row execute function public.trg_header_touch();
create trigger header_log after insert or update or delete on public.event_header
  for each row execute function public.trg_header_log();

-- 6.3 members
-- (a) Cupo: máximo 2 usuarios por área (3 áreas = 6 por evento)
create function public.trg_members_capacity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from public.members m
       where m.event_id = new.event_id and m.area_id = new.area_id and m.user_id <> new.user_id) >= 2 then
    raise exception 'Esa área ya tiene 2 usuarios en este evento' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger members_capacity before insert or update of area_id on public.members
  for each row execute function public.trg_members_capacity();

-- (b) El administrador del evento no puede salirse sin transferir el cargo (el general sí puede quitarlo)
create function public.trg_members_admin_leave() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.role = 'admin' and auth.uid() is not null and not public.is_superadmin()
     and exists (select 1 from public.events e where e.id = old.event_id) then
    raise exception 'El administrador del evento no puede salir sin transferir antes el cargo' using errcode = '23514';
  end if;
  return old;
end $$;
create trigger members_admin_leave before delete on public.members
  for each row execute function public.trg_members_admin_leave();

-- 6.4 people
-- (a) Permisos finos y efecto de «sin participación».
create function public.trg_people_bu() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.id <> old.id or new.event_id <> old.event_id then
    raise exception 'No se puede cambiar el identificador de una persona' using errcode = '42501';
  end if;

  -- auth.uid() nulo = operación de confianza (SQL Editor / service_role): sin restricciones.
  if auth.uid() is not null and not public.is_admin(new.event_id) then
    -- editor de área: solo puede cambiar «sin participación»…
    if (new.nombre, new.cong, new.tel, new.correo) is distinct from (old.nombre, old.cong, old.tel, old.correo) then
      raise exception 'Solo un administrador puede editar los datos de una persona' using errcode = '42501';
    end if;
    if new.no is distinct from old.no then
      if public.member_role(new.event_id) is distinct from 'editor' then
        raise exception 'No tienes permiso para marcar «sin participación»' using errcode = '42501';
      end if;
      -- …a libres y a quienes estén en su área (no a quien tenga una asignación fuera de ella)
      if exists (select 1 from public.assignments a
                 where a.event_id = old.event_id and a.person_id = old.id
                   and not public.can_edit_slot(a.event_id, a.slot)) then
        raise exception 'La persona tiene una asignación fuera de tu área' using errcode = '42501';
      end if;
    end if;
  end if;

  -- Marcar «sin participación» quita todas sus asignaciones (cada una queda en el registro)
  if new.no and not old.no then
    delete from public.assignments a where a.event_id = new.event_id and a.person_id = new.id;
  end if;
  return new;
end $$;
create trigger people_bu before update on public.people
  for each row execute function public.trg_people_bu();

-- (b) Registro
create function public.trg_people_log_upd() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.app_log(new.event_id,
    (case when new.no then 'Marcó sin participación a ' else 'Quitó la marca de sin participación a ' end) || new.nombre);
  return null;
end $$;
create trigger people_log_upd after update of no on public.people
  for each row when (old.no is distinct from new.no)
  execute function public.trg_people_log_upd();

create function public.trg_people_log_ins() returns trigger
language plpgsql security definer set search_path = '' as $$
declare g record; one text;
begin
  for g in select event_id, count(*) as n from new_rows group by event_id loop
    if g.n = 1 then
      select r.nombre into one from new_rows r where r.event_id = g.event_id;
      perform public.app_log(g.event_id, 'Agregó a ' || one || ' al directorio');
    else
      perform public.app_log(g.event_id, 'Importó ' || g.n || ' personas');
    end if;
  end loop;
  return null;
end $$;
create trigger people_log_ins after insert on public.people
  referencing new table as new_rows
  for each statement execute function public.trg_people_log_ins();

create function public.trg_people_log_del() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform public.app_log(old.event_id, 'Quitó a ' || old.nombre || ' del directorio');
  return null;
end $$;
create trigger people_log_del after delete on public.people
  for each row execute function public.trg_people_log_del();

-- 6.5 assignments
create function public.trg_assignments_biu() returns trigger
language plpgsql security definer set search_path = '' as $$
declare pno boolean; dept text; pres boolean;
begin
  if tg_op = 'UPDATE' and (new.event_id <> old.event_id or new.slot <> old.slot) then
    raise exception 'No se puede cambiar el puesto de una asignación; quítala y crea otra' using errcode = '23514';
  end if;
  if not public.slot_valid(new.slot) then
    raise exception 'Puesto no válido: %', new.slot using errcode = '23514';
  end if;
  select p.no into pno from public.people p where p.id = new.person_id and p.event_id = new.event_id;
  if pno then
    raise exception 'La persona está marcada «sin participación»' using errcode = '23514';
  end if;

  -- «vigente» = su departamento está presente (los puestos de área y el presidente siempre lo están)
  dept := public.slot_dept(new.slot);
  if dept is null then
    new.live := true;
  else
    select dp.present into pres from public.dept_presence dp
     where dp.event_id = new.event_id and dp.dept_id = dept;
    if pres is null then
      select not d.optional into pres from public.departments d where d.id = dept;
    end if;
    new.live := coalesce(pres, true);
  end if;
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;
create trigger assignments_biu before insert or update on public.assignments
  for each row execute function public.trg_assignments_biu();

create function public.trg_assignments_log() returns trigger
language plpgsql security definer set search_path = '' as $$
declare pn text;
begin
  if tg_op in ('UPDATE', 'DELETE') and (tg_op = 'DELETE' or old.person_id <> new.person_id) then
    select p.nombre into pn from public.people p where p.id = old.person_id;
    if pn is not null then  -- si la persona ya no existe (borrada del directorio) no se repite el aviso
      perform public.app_log(old.event_id, 'Quitó a ' || pn || ' de ' || public.slot_label(old.slot));
    end if;
  end if;
  if tg_op in ('INSERT', 'UPDATE') and (tg_op = 'INSERT' or old.person_id <> new.person_id) then
    select p.nombre into pn from public.people p where p.id = new.person_id;
    perform public.app_log(new.event_id, 'Asignó a ' || pn || ': ' || public.slot_label(new.slot));
  end if;
  -- el estado de la carta se reinicia si cambia la persona del puesto
  if tg_op = 'UPDATE' and old.person_id <> new.person_id then
    delete from public.letter_status l where l.event_id = new.event_id and l.slot = new.slot;
  end if;
  return null;
end $$;
create trigger assignments_log after insert or delete or update of person_id on public.assignments
  for each row execute function public.trg_assignments_log();

-- 6.6 dept_presence: recalcula qué asignaciones están vigentes y registra
create function public.trg_dept_presence_aiu() returns trigger
language plpgsql security definer set search_path = '' as $$
declare dname text; def boolean; prev boolean;
begin
  select d.name, not d.optional into dname, def from public.departments d where d.id = new.dept_id;
  prev := case when tg_op = 'UPDATE' then old.present else def end;
  if new.present = prev then return null; end if;   -- sin cambio real (p. ej. al sembrar el evento)

  begin
    update public.assignments a set live = new.present
     where a.event_id = new.event_id and split_part(a.slot, ':', 1) = new.dept_id
       and a.live is distinct from new.present;
  exception when unique_violation then
    raise exception 'No se puede marcar presente este departamento: alguien de sus puestos ya tiene otra asignación. Libera primero a esa persona.'
      using errcode = '23505';
  end;
  perform public.app_log(new.event_id, (case when new.present then 'Marcó presente: ' else 'Marcó no presente: ' end) || dname);
  return null;
end $$;
create trigger dept_presence_aiu after insert or update of present on public.dept_presence
  for each row execute function public.trg_dept_presence_aiu();

-- 6.7 letter_status
create function public.trg_letter_biu() returns trigger
language plpgsql security definer set search_path = '' as $$
declare pid uuid;
begin
  select a.person_id into pid from public.assignments a
   where a.event_id = new.event_id and a.slot = new.slot;
  if pid is null then
    raise exception 'Ese puesto no tiene a nadie asignado' using errcode = '23503';
  end if;
  new.person_id := pid;
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end $$;
create trigger letter_biu before insert or update on public.letter_status
  for each row execute function public.trg_letter_biu();

-- Registro de cartas: una línea por carta; si cambian varias a la vez, una sola línea resumen.
create function public.trg_letter_log_ins() returns trigger
language plpgsql security definer set search_path = '' as $$
declare g record; r record;
begin
  for g in select event_id, count(*) as n, min(state) as s1, max(state) as s2 from new_rows group by event_id loop
    if g.n = 1 then
      select nr.state, nr.slot, p.nombre into r
        from new_rows nr join public.people p on p.id = nr.person_id where nr.event_id = g.event_id;
      perform public.app_log(g.event_id, 'Carta de ' || r.nombre || ' (' || public.slot_label(r.slot) || '): ' || public.letter_state_label(r.state));
    elsif g.s1 = g.s2 then
      perform public.app_log(g.event_id, 'Marcó ' || g.n || ' cartas como ' || public.letter_state_plural(g.s1));
    else
      perform public.app_log(g.event_id, 'Actualizó ' || g.n || ' cartas');
    end if;
  end loop;
  return null;
end $$;
create trigger letter_log_ins after insert on public.letter_status
  referencing new table as new_rows
  for each statement execute function public.trg_letter_log_ins();

create function public.trg_letter_log_upd() returns trigger
language plpgsql security definer set search_path = '' as $$
declare g record; r record;
begin
  for g in select nr.event_id, count(*) as n, min(nr.state) as s1, max(nr.state) as s2
             from new_rows nr join old_rows o on o.event_id = nr.event_id and o.slot = nr.slot
            where o.state <> nr.state group by nr.event_id loop
    if g.n = 1 then
      select nr.state, nr.slot, p.nombre into r
        from new_rows nr join old_rows o on o.event_id = nr.event_id and o.slot = nr.slot
        join public.people p on p.id = nr.person_id
       where nr.event_id = g.event_id and o.state <> nr.state;
      perform public.app_log(g.event_id, 'Carta de ' || r.nombre || ' (' || public.slot_label(r.slot) || '): ' || public.letter_state_label(r.state));
    elsif g.s1 = g.s2 then
      perform public.app_log(g.event_id, 'Marcó ' || g.n || ' cartas como ' || public.letter_state_plural(g.s1));
    else
      perform public.app_log(g.event_id, 'Actualizó ' || g.n || ' cartas');
    end if;
  end loop;
  return null;
end $$;
create trigger letter_log_upd after update on public.letter_status
  referencing old table as old_rows new table as new_rows
  for each statement execute function public.trg_letter_log_upd();


-- =====================================================================
-- 7. FUNCIONES PARA LA APP (RPC)
-- =====================================================================

-- Crear un evento (el creador queda como administrador del evento, en el área que elija).
-- Solo cuentas con can_create_events.
create function public.create_event(p_name text, p_area text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); ev uuid; nm text := btrim(coalesce(p_name, ''));
begin
  if uid is null then
    raise exception 'Inicia sesión primero' using errcode = '28000';
  end if;
  if not exists (select 1 from public.profiles p where p.user_id = uid and p.can_create_events) then
    raise exception 'Tu cuenta no tiene permiso para crear eventos' using errcode = '42501';
  end if;
  if nm = '' then
    raise exception 'El evento necesita un nombre' using errcode = '23514';
  end if;
  if p_area is null or not exists (select 1 from public.areas a where a.id = p_area) then
    raise exception 'Elige tu área (AC, AP o AA)' using errcode = '23514';
  end if;
  insert into public.events (name, nombre, created_by) values (nm, nm, uid) returning id into ev;
  insert into public.members (event_id, user_id, role, area_id) values (ev, uid, 'admin', p_area);
  insert into public.dept_presence (event_id, dept_id, present)
    select ev, d.id, not d.optional from public.departments d;   -- los opcionales empiezan apagados
  perform public.app_log(ev, 'Evento creado: ' || nm);
  return ev;
end $$;

-- Código de invitación para un editor de un área (el enlace de WhatsApp lo arma la app con este código).
create function public.create_invite(p_event uuid, p_area text, p_days int default 7, p_max_uses int default 1) returns text
language plpgsql security definer set search_path = '' as $$
declare c text;
begin
  if not (public.is_admin(p_event) or public.is_superadmin()) then
    raise exception 'Solo el administrador del evento puede invitar' using errcode = '42501';
  end if;
  if not exists (select 1 from public.events e where e.id = p_event) then
    raise exception 'Evento no encontrado' using errcode = 'P0002';
  end if;
  if p_area is null or not exists (select 1 from public.areas a where a.id = p_area) then
    raise exception 'Área no válida (AC, AP o AA)' using errcode = '23514';
  end if;
  if (select count(*) from public.members m where m.event_id = p_event and m.area_id = p_area) >= 2 then
    raise exception 'Esa área ya tiene 2 usuarios en este evento' using errcode = '23514';
  end if;
  if p_days not between 1 and 60 then
    raise exception 'La invitación debe durar entre 1 y 60 días' using errcode = '23514';
  end if;
  insert into public.invites (event_id, area_id, expires_at, max_uses, created_by)
  values (p_event, p_area, now() + make_interval(days => p_days), p_max_uses, auth.uid())
  returning code into c;
  return c;
end $$;

-- Aceptar una invitación: te agrega como editor del área indicada (si hay cupo).
create function public.accept_invite(p_code text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); inv public.invites; cur record; ename text; who text;
begin
  if uid is null then
    raise exception 'Inicia sesión para aceptar la invitación' using errcode = '28000';
  end if;
  select * into inv from public.invites i where i.code = btrim(coalesce(p_code, '')) for update;
  if not found then
    raise exception 'Invitación no válida' using errcode = 'P0002';
  end if;

  select m.role, m.area_id into cur from public.members m where m.event_id = inv.event_id and m.user_id = uid;
  if found then   -- ya eras miembro: no se cambia tu rol ni se gasta la invitación
    return jsonb_build_object('event_id', inv.event_id, 'role', cur.role, 'area_id', cur.area_id, 'already_member', true);
  end if;

  if inv.expires_at < now() then
    raise exception 'La invitación caducó; pide una nueva' using errcode = 'P0001';
  end if;
  if inv.uses >= inv.max_uses then
    raise exception 'La invitación ya fue utilizada; pide una nueva' using errcode = 'P0001';
  end if;

  insert into public.members (event_id, user_id, role, area_id) values (inv.event_id, uid, 'editor', inv.area_id);  -- el trigger valida el cupo
  update public.invites set uses = uses + 1 where code = inv.code;

  select e.name into ename from public.events e where e.id = inv.event_id;
  select coalesce(nullif(p.display_name, ''), p.email) into who from public.profiles p where p.user_id = uid;
  perform public.app_log(inv.event_id, 'Se unió: ' || coalesce(who, '—') || ' como editor de ' ||
    (select a.name from public.areas a where a.id = inv.area_id));
  return jsonb_build_object('event_id', inv.event_id, 'event_name', ename, 'role', 'editor',
                            'area_id', inv.area_id, 'already_member', false);
end $$;

-- Pasar el cargo de administrador del evento a otro miembro (lo hace el administrador actual o el general).
create function public.transfer_event_admin(p_event uuid, p_user uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare nm text;
begin
  if not (public.is_admin(p_event) or public.is_superadmin()) then
    raise exception 'Solo el administrador del evento puede transferir el cargo' using errcode = '42501';
  end if;
  if not exists (select 1 from public.members m where m.event_id = p_event and m.user_id = p_user) then
    raise exception 'Esa persona no es miembro del evento' using errcode = '23514';
  end if;
  update public.members set role = 'editor' where event_id = p_event and role = 'admin';
  update public.members set role = 'admin'  where event_id = p_event and user_id = p_user;
  select coalesce(nullif(p.display_name, ''), p.email) into nm from public.profiles p where p.user_id = p_user;
  perform public.app_log(p_event, 'Transfirió el cargo de administrador del evento a ' || coalesce(nm, '—'));
end $$;

-- Miembros del evento con nombre y correo (administrador del evento o general).
create function public.list_members(p_event uuid)
returns table (user_id uuid, display_name text, email text, role text, area_id text, created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not (public.is_admin(p_event) or public.is_superadmin()) then
    raise exception 'Solo el administrador puede ver los miembros' using errcode = '42501';
  end if;
  return query
    select m.user_id, p.display_name, p.email, m.role, m.area_id, m.created_at
      from public.members m left join public.profiles p on p.user_id = m.user_id
     where m.event_id = p_event
     order by m.area_id, m.created_at;
end $$;

-- ---- Panel del administrador general ----
create function public.admin_events()
returns table (id uuid, name text, created_at timestamptz, admin_name text, admin_email text,
               members bigint, people bigint, assignments bigint)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is not null and not public.is_superadmin() then   -- sin sesión = SQL Editor / servicio (de confianza)
    raise exception 'Solo el administrador general' using errcode = '42501';
  end if;
  return query
    select e.id, e.name, e.created_at,
           (select p.display_name from public.members m join public.profiles p on p.user_id = m.user_id
             where m.event_id = e.id and m.role = 'admin'),
           (select p.email from public.members m join public.profiles p on p.user_id = m.user_id
             where m.event_id = e.id and m.role = 'admin'),
           (select count(*) from public.members m where m.event_id = e.id),
           (select count(*) from public.people x where x.event_id = e.id),
           (select count(*) from public.assignments a where a.event_id = e.id and a.live)
      from public.events e order by e.created_at desc;
end $$;

create function public.admin_list_users()
returns table (user_id uuid, email text, display_name text, can_create_events boolean, is_superadmin boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is not null and not public.is_superadmin() then   -- sin sesión = SQL Editor / servicio (de confianza)
    raise exception 'Solo el administrador general' using errcode = '42501';
  end if;
  return query select p.user_id, p.email, p.display_name, p.can_create_events, p.is_superadmin
                 from public.profiles p order by p.email;
end $$;

-- Dar o quitar a una cuenta el permiso de crear eventos (= ser administrador de evento).
create function public.admin_set_can_create(p_user uuid, p_value boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is not null and not public.is_superadmin() then   -- sin sesión = SQL Editor / servicio (de confianza)
    raise exception 'Solo el administrador general' using errcode = '42501';
  end if;
  update public.profiles set can_create_events = p_value where user_id = p_user;
  if not found then raise exception 'Cuenta no encontrada' using errcode = 'P0002'; end if;
end $$;

-- Consulta real a la base para el flujo programado que evita la pausa del proyecto gratuito.
-- Se puede llamar con la llave pública (anon): POST /rest/v1/rpc/ping
create function public.ping() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('ok', true, 'at', now(), 'areas', (select count(*) from public.areas))
$$;


-- =====================================================================
-- 8. SEGURIDAD POR FILAS (RLS)
-- =====================================================================
alter table public.areas         enable row level security;
alter table public.departments   enable row level security;
alter table public.profiles      enable row level security;
alter table public.events        enable row level security;
alter table public.event_header  enable row level security;
alter table public.members       enable row level security;
alter table public.invites       enable row level security;
alter table public.people        enable row level security;
alter table public.assignments   enable row level security;
alter table public.dept_presence enable row level security;
alter table public.letter_status enable row level security;
alter table public.change_log    enable row level security;

-- Catálogo: lectura para cualquier sesión iniciada
create policy areas_sel on public.areas       for select to authenticated using (true);
create policy depts_sel on public.departments for select to authenticated using (true);

-- Perfil: cada quien ve y edita (solo su nombre) el suyo
create policy profiles_sel on public.profiles for select to authenticated using (user_id = auth.uid());
create policy profiles_upd on public.profiles for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Eventos: los miembros y el administrador general ven; el administrador del evento edita; solo el general elimina.
-- (No hay política de INSERT: los eventos se crean con create_event().)
create policy events_sel on public.events for select to authenticated using (public.can_read_event(id));
create policy events_upd on public.events for update to authenticated
  using (public.is_admin(id)) with check (public.is_admin(id));
create policy events_del on public.events for delete to authenticated using (public.is_superadmin());

-- Encabezado de imagen: miembros ven; administradores cambian
create policy header_sel on public.event_header for select to authenticated using (public.can_read_event(event_id));
create policy header_ins on public.event_header for insert to authenticated with check (public.is_admin(event_id));
create policy header_upd on public.event_header for update to authenticated
  using (public.is_admin(event_id)) with check (public.is_admin(event_id));
create policy header_del on public.event_header for delete to authenticated using (public.is_admin(event_id));

-- Miembros: ves tu propia fila; el administrador ve y gestiona todas. Altas solo por invitación.
create policy members_sel on public.members for select to authenticated
  using (user_id = auth.uid() or public.is_admin(event_id) or public.is_superadmin());
create policy members_upd on public.members for update to authenticated   -- solo cambia el área (el cargo: transfer_event_admin)
  using (public.is_admin(event_id) or public.is_superadmin())
  with check (public.is_admin(event_id) or public.is_superadmin());
create policy members_del on public.members for delete to authenticated
  using (public.is_admin(event_id) or public.is_superadmin() or user_id = auth.uid());   -- también puedes salirte tú (salvo el administrador)

-- Invitaciones: administrador del evento y general (se crean con create_invite())
create policy invites_sel on public.invites for select to authenticated using (public.is_admin(event_id) or public.is_superadmin());
create policy invites_del on public.invites for delete to authenticated using (public.is_admin(event_id) or public.is_superadmin());

-- Directorio: todos los miembros (y el general) lo ven completo; solo el administrador da de alta/baja/edita datos;
-- el editor de área puede cambiar «sin participación» (lo afina el trigger trg_people_bu).
create policy people_sel on public.people for select to authenticated using (public.can_read_event(event_id));
create policy people_ins on public.people for insert to authenticated with check (public.is_admin(event_id));
create policy people_upd on public.people for update to authenticated
  using (public.member_role(event_id) in ('admin', 'editor'))
  with check (public.member_role(event_id) in ('admin', 'editor'));
create policy people_del on public.people for delete to authenticated using (public.is_admin(event_id));

-- Asignaciones: todos los miembros ven; escribe quien pueda editar ese puesto
create policy asg_sel on public.assignments for select to authenticated using (public.can_read_event(event_id));
create policy asg_ins on public.assignments for insert to authenticated with check (public.can_edit_slot(event_id, slot));
create policy asg_upd on public.assignments for update to authenticated
  using (public.can_edit_slot(event_id, slot)) with check (public.can_edit_slot(event_id, slot));
create policy asg_del on public.assignments for delete to authenticated using (public.can_edit_slot(event_id, slot));

-- Presencia de departamentos: todos ven; el admin y el editor de esa área cambian
create policy dp_sel on public.dept_presence for select to authenticated using (public.can_read_event(event_id));
create policy dp_ins on public.dept_presence for insert to authenticated with check (public.can_edit_dept(event_id, dept_id));
create policy dp_upd on public.dept_presence for update to authenticated
  using (public.can_edit_dept(event_id, dept_id)) with check (public.can_edit_dept(event_id, dept_id));

-- Cartas: el administrador del evento ve/edita todas; el editor solo las de su área; el general solo lee
create policy ls_sel on public.letter_status for select to authenticated using (public.can_edit_slot(event_id, slot) or public.is_superadmin());
create policy ls_ins on public.letter_status for insert to authenticated with check (public.can_edit_slot(event_id, slot));
create policy ls_upd on public.letter_status for update to authenticated
  using (public.can_edit_slot(event_id, slot)) with check (public.can_edit_slot(event_id, slot));
create policy ls_del on public.letter_status for delete to authenticated using (public.can_edit_slot(event_id, slot));

-- Registro: lo ven los miembros; solo se escribe desde los triggers
create policy log_sel on public.change_log for select to authenticated using (public.can_read_event(event_id));


-- =====================================================================
-- 9. PERMISOS (GRANT): solo lo imprescindible, columna por columna
-- =====================================================================
revoke all on all tables    in schema public from anon, authenticated;
revoke all on all sequences in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant usage on schema public to anon, authenticated;

grant select on public.areas, public.departments to authenticated;

grant select on public.profiles to authenticated;
grant update (display_name) on public.profiles to authenticated;

grant select, delete on public.events to authenticated;
grant update (name, nombre, tit2, recinto, ciudad, fechas, fcarta, fauto, codigo, hmode, orgp)
  on public.events to authenticated;

grant select, insert, update, delete on public.event_header to authenticated;

grant select, delete on public.members to authenticated;
grant update (area_id) on public.members to authenticated;

grant select, delete on public.invites to authenticated;

grant select, insert, delete on public.people to authenticated;
grant update (nombre, cong, tel, correo, no) on public.people to authenticated;

grant select, insert, delete on public.assignments to authenticated;
grant update (person_id) on public.assignments to authenticated;

grant select, insert on public.dept_presence to authenticated;
grant update (present) on public.dept_presence to authenticated;

grant select, insert, delete on public.letter_status to authenticated;
grant update (state) on public.letter_status to authenticated;

grant select on public.change_log to authenticated;

-- Funciones que usan las políticas y la app
grant execute on function
  public.member_role(uuid), public.member_area(uuid), public.is_member(uuid), public.is_admin(uuid),
  public.is_superadmin(), public.can_read_event(uuid),
  public.slot_dept(text), public.slot_area(text), public.slot_valid(text),
  public.can_edit_slot(uuid, text), public.can_edit_dept(uuid, text), public.slot_label(text)
  to authenticated;
grant execute on function
  public.create_event(text, text), public.create_invite(uuid, text, int, int),
  public.accept_invite(text), public.list_members(uuid), public.transfer_event_admin(uuid, uuid),
  public.admin_events(), public.admin_list_users(), public.admin_set_can_create(uuid, boolean)
  to authenticated;
grant execute on function public.ping() to anon, authenticated;


-- =====================================================================
-- 10. TIEMPO REAL (Realtime)
-- =====================================================================
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table
      public.events, public.people, public.assignments, public.dept_presence,
      public.letter_status, public.change_log, public.members;
  end if;
end $$;


-- =====================================================================
-- 10b. ACCESO A LAS CARTAS DE OTRAS ÁREAS (solicitud y aprobación)
--      (mismo contenido que 04_parche_acceso_cartas.sql)
-- =====================================================================
create table if not exists public.letter_access (
  event_id     uuid not null,
  user_id      uuid not null,
  status       text not null check (status in ('pending', 'approved', 'denied')),
  requested_at timestamptz not null default now(),
  decided_at   timestamptz,
  decided_by   uuid references auth.users(id) on delete set null,
  primary key (event_id, user_id),
  -- si la persona sale del evento (o se borra el evento) se borra su permiso
  foreign key (event_id, user_id) references public.members (event_id, user_id) on delete cascade
);
alter table public.letter_access enable row level security;

-- ¿Tengo aprobado ver las cartas de todas las áreas? (solo lectura)
create or replace function public.has_letters_access(ev uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.letter_access a
                  where a.event_id = ev and a.user_id = auth.uid() and a.status = 'approved')
$$;

-- El editor pide ver las cartas de las demás áreas.
create or replace function public.request_letters_access(p_event uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); r text; cur text;
begin
  if uid is null then
    raise exception 'Inicia sesión primero' using errcode = '28000';
  end if;
  r := public.member_role(p_event);
  if r is null then
    raise exception 'No eres miembro de este evento' using errcode = '42501';
  end if;
  if r = 'admin' then
    raise exception 'Como administrador del evento ya ves todas las cartas' using errcode = '23514';
  end if;
  select a.status into cur from public.letter_access a where a.event_id = p_event and a.user_id = uid;
  if cur in ('approved', 'pending') then return cur; end if;      -- sin duplicar ni retroceder
  insert into public.letter_access (event_id, user_id, status) values (p_event, uid, 'pending')
  on conflict (event_id, user_id) do update
     set status = 'pending', requested_at = now(), decided_at = null, decided_by = null;
  return 'pending';
end $$;

-- El administrador del evento (o el general) aprueba, deniega o revoca; también puede conceder sin solicitud.
create or replace function public.decide_letters_access(p_event uuid, p_user uuid, p_approve boolean) returns text
language plpgsql security definer set search_path = '' as $$
declare prev text; nm text; ns text := case when p_approve then 'approved' else 'denied' end;
begin
  if auth.uid() is not null and not (public.is_admin(p_event) or public.is_superadmin()) then
    raise exception 'Solo el administrador del evento puede decidir' using errcode = '42501';
  end if;
  if not exists (select 1 from public.members m where m.event_id = p_event and m.user_id = p_user) then
    raise exception 'Esa persona no es miembro del evento' using errcode = '23514';
  end if;
  select a.status into prev from public.letter_access a where a.event_id = p_event and a.user_id = p_user;
  insert into public.letter_access (event_id, user_id, status, decided_at, decided_by)
  values (p_event, p_user, ns, now(), auth.uid())
  on conflict (event_id, user_id) do update set status = ns, decided_at = now(), decided_by = auth.uid();

  -- al registro solo van aprobaciones y revocaciones (no las solicitudes ni las negativas a una solicitud)
  select coalesce(nullif(p.display_name, ''), p.email) into nm from public.profiles p where p.user_id = p_user;
  if p_approve and prev is distinct from 'approved' then
    perform public.app_log(p_event, 'Dio acceso a ' || coalesce(nm, '—') || ' para ver las cartas de todas las áreas');
  elsif not p_approve and prev = 'approved' then
    perform public.app_log(p_event, 'Quitó a ' || coalesce(nm, '—') || ' el acceso a las cartas de todas las áreas');
  end if;
  return ns;
end $$;

-- Solicitudes: las ve quien las hace, el administrador del evento y el general. Se escriben solo con las funciones.
drop policy if exists la_sel on public.letter_access;
create policy la_sel on public.letter_access for select to authenticated
  using (user_id = auth.uid() or public.is_admin(event_id) or public.is_superadmin());

-- Cartas: además de lo anterior, ve todas (solo lectura) quien tenga acceso aprobado.
-- Marcar estados sigue siendo solo del administrador del evento y del editor de esa área.
drop policy if exists ls_sel on public.letter_status;
create policy ls_sel on public.letter_status for select to authenticated
  using (public.can_edit_slot(event_id, slot) or public.is_superadmin() or public.has_letters_access(event_id));

-- Permisos
revoke all on public.letter_access from anon, authenticated;
grant select on public.letter_access to authenticated;
revoke all on function public.has_letters_access(uuid), public.request_letters_access(uuid),
  public.decide_letters_access(uuid, uuid, boolean) from public, anon, authenticated;
grant execute on function public.has_letters_access(uuid), public.request_letters_access(uuid),
  public.decide_letters_access(uuid, uuid, boolean) to authenticated;

-- Tiempo real (la insignia del administrador y el selector del editor aparecen sin recargar)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables
                      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'letter_access') then
    alter publication supabase_realtime add table public.letter_access;
  end if;
end $$;


-- =====================================================================
-- 11. ADMINISTRADOR GENERAL (haz esto DESPUÉS de crear tu cuenta)
--     Reemplaza el correo y ejecuta solo esta línea en el SQL Editor:
-- =====================================================================
-- update public.profiles set is_superadmin = true where email = 'TU_CORREO@ejemplo.com';
--
-- Luego, desde la app (o con SQL) das el permiso de crear eventos a quien será administrador de evento:
-- select public.admin_set_can_create((select user_id from public.profiles where email = 'correo@ejemplo.com'), true);
