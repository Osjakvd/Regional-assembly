-- BORRA todo lo de la app (tablas, funciones, datos). Útil si quieres volver a ejecutar 01_esquema.sql.
drop trigger if exists on_auth_user_created on auth.users;
drop table if exists public.letter_access, public.change_log, public.letter_status, public.dept_presence, public.assignments,
  public.people, public.invites, public.members, public.event_header, public.events,
  public.profiles, public.departments, public.areas cascade;
drop function if exists public.trg_new_user(), public.trg_touch(), public.trg_header_log(), public.trg_header_touch(),
  public.trg_members_capacity(), public.trg_members_admin_leave(), public.trg_people_bu(), public.trg_people_log_upd(), public.trg_people_log_ins(),
  public.trg_people_log_del(), public.trg_assignments_biu(), public.trg_assignments_log(), public.trg_dept_presence_aiu(),
  public.trg_letter_biu(), public.trg_letter_log_ins(), public.trg_letter_log_upd(),
  public.member_role(uuid), public.member_area(uuid), public.is_member(uuid), public.is_admin(uuid),
  public.slot_dept(text), public.slot_area(text), public.slot_valid(text), public.can_edit_slot(uuid, text),
  public.can_edit_dept(uuid, text), public.slot_label(text), public.letter_state_label(text),
  public.letter_state_plural(text), public.app_log(uuid, text), public.create_event(text, text),
  public.create_invite(uuid, text, int, int), public.accept_invite(text), public.list_members(uuid), public.ping(),
  public.is_superadmin(), public.can_read_event(uuid), public.transfer_event_admin(uuid, uuid),
  public.admin_events(), public.admin_list_users(), public.admin_set_can_create(uuid, boolean),
  public.has_letters_access(uuid), public.request_letters_access(uuid), public.decide_letters_access(uuid, uuid, boolean);
