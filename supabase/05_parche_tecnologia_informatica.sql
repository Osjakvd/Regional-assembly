-- =====================================================================
-- PARCHE 05 · Bloque «Tecnología informática y técnicos» (dentro de Audio y Video)
-- Ya está incluido en 01_esquema.sql. Ejecútalo SOLO si ya habías corrido
-- 01_esquema.sql antes de este cambio. No borra datos y se puede repetir.
--
-- Es un departamento opcional (apagado por defecto) del área del superintendente
-- del programa, con los 4 puestos de siempre:
--   tinf:0  Superintendente de Tecnología informática
--   tinf:1..3  Técnico de Audio y Video   (suelen ser 2; máximo 3)
-- La app lo muestra como fila propia solo en Dir. dptos. y agrupado dentro de
-- Audio y Video en Asignación, organigrama, directorios y cartas.
-- =====================================================================
insert into public.departments (id, area_id, name, optional, coordinator, av, sort) values
  ('tinf', 'AP', 'Tecnología informática y técnicos', true, false, false, 2)
on conflict (id) do nothing;
update public.departments set sort = 3 where id = 'bau';
update public.departments set sort = 4 where id = 'it';

create or replace function public.slot_label(p_slot text) returns text
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

-- Eventos que ya existían: fila de presencia apagada (igual al valor por defecto; no genera registro)
insert into public.dept_presence (event_id, dept_id, present)
select e.id, 'tinf', false from public.events e
on conflict (event_id, dept_id) do nothing;
