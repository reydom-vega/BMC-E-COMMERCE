begin;
create table public.tk_restock_subscriptions(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 variant_id uuid not null references public.tk_variants(id),active boolean not null default true,
 created_at timestamptz not null default now(),notified_at timestamptz,unique(user_id,variant_id));
create index on public.tk_restock_subscriptions(variant_id) where active;
create table public.tk_shipments(order_id uuid primary key references public.tk_orders(id),courier text not null check(length(courier) between 1 and 100),
 tracking_number text not null check(length(tracking_number) between 1 and 100),tracking_url text not null default '' check(tracking_url='' or tracking_url ~ '^https://[a-zA-Z0-9][a-zA-Z0-9.-]+(/[^\s]*)?$'),updated_at timestamptz not null default now());
create table public.tk_tracking_events(id uuid primary key default gen_random_uuid(),order_id uuid not null references public.tk_orders(id),
 status text not null,message text not null check(length(message) between 1 and 500),created_by uuid not null references auth.users(id),created_at timestamptz not null default now());
create index on public.tk_tracking_events(order_id,created_at);
create table public.tk_support_tickets(id uuid primary key default gen_random_uuid(),number bigint generated always as identity unique,
 user_id uuid not null references auth.users(id),order_id uuid references public.tk_orders(id),
 category text not null check(category in ('Order','Payment','Delivery','Refund','Product','Technical','Other')),
 subject text not null check(length(subject) between 3 and 150),status text not null default 'OPEN' check(status in ('OPEN','IN_PROGRESS','WAITING_FOR_CUSTOMER','RESOLVED','CLOSED')),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now());
create index on public.tk_support_tickets(user_id,updated_at desc);
create index on public.tk_support_tickets(status,number);
create table public.tk_support_messages(id uuid primary key default gen_random_uuid(),ticket_id uuid not null references public.tk_support_tickets(id),
 user_id uuid not null references auth.users(id),staff boolean not null,message text not null check(length(trim(message)) between 1 and 4000),created_at timestamptz not null default now());
create index on public.tk_support_messages(ticket_id,created_at);
create table public.tk_support_events(id uuid primary key default gen_random_uuid(),ticket_id uuid not null references public.tk_support_tickets(id),
 actor_id uuid not null references auth.users(id),previous_status text not null,status text not null,created_at timestamptz not null default now());
create index on public.tk_support_events(ticket_id);
create table public.tk_notification_preferences(user_id uuid primary key references auth.users(id) on delete cascade,
 push_enabled boolean not null default false,order_updates boolean not null default true,restock boolean not null default true,
 rewards boolean not null default true,support boolean not null default true,promotions boolean not null default false);
create table public.tk_device_tokens(token text primary key check(length(token) between 20 and 4096),user_id uuid not null references auth.users(id) on delete cascade,
 active boolean not null default true,updated_at timestamptz not null default now());
create index on public.tk_device_tokens(user_id) where active;
alter table public.tk_notifications add column category text not null default 'order_updates',add column target_id uuid;
create table public.tk_notification_outbox(id uuid primary key default gen_random_uuid(),notification_id uuid not null references public.tk_notifications(id),
 token text not null references public.tk_device_tokens(token),status text not null default 'PENDING' check(status in ('PENDING','SENDING','DELIVERED','FAILED','SKIPPED')),
 attempts integer not null default 0,available_at timestamptz not null default now(),lease_id uuid,last_error text,delivered_at timestamptz,unique(notification_id,token));
create index on public.tk_notification_outbox(status,available_at);

create function public.tk_push_enqueue() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.tk_notification_outbox(notification_id,token)
 select new.id,t.token from public.tk_device_tokens t join public.tk_notification_preferences p on p.user_id=t.user_id
 where t.user_id=new.user_id and t.active and p.push_enabled and case new.category
 when 'restock' then p.restock when 'rewards' then p.rewards when 'support' then p.support when 'promotions' then p.promotions else p.order_updates end
 on conflict do nothing;
 return new;
end $$;
create trigger tk_push_enqueue after insert on public.tk_notifications for each row execute function public.tk_push_enqueue();
create function public.tk_register_device(p_token text,p_active boolean) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if p_active then
  insert into public.tk_device_tokens(token,user_id) values(p_token,auth.uid()) on conflict(token) do update set user_id=auth.uid(),active=true,updated_at=now();
 else update public.tk_device_tokens set active=false where token=p_token and user_id=auth.uid(); end if;
end $$;
create function public.tk_claim_push(p_limit integer default 50) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 with selected as(select id from public.tk_notification_outbox where status in ('PENDING','SENDING') and available_at<=now() and attempts<5 order by available_at for update skip locked limit least(100,greatest(1,p_limit))),
 claimed as(update public.tk_notification_outbox q set status='SENDING',attempts=attempts+1,available_at=now()+interval '5 minutes',lease_id=gen_random_uuid() from selected s where q.id=s.id returning q.*)
 select coalesce(jsonb_agg(to_jsonb(c)||jsonb_build_object('user_id',n.user_id,'category',n.category,'target_id',coalesce(n.order_id,n.target_id))), '[]') into result from claimed c join public.tk_notifications n on n.id=c.notification_id;
 update public.tk_notification_outbox set status='FAILED',last_error='retry_limit' where attempts>=5 and status='SENDING' and available_at<=now();
 return result;
end $$;
create function public.tk_finish_push(p_id uuid,p_lease uuid,p_status text,p_error text default null) returns void language plpgsql security definer set search_path='' as $$
begin
 if p_status not in ('DELIVERED','FAILED','PENDING','SKIPPED') then raise exception 'Invalid delivery outcome.'; end if;
 update public.tk_notification_outbox set status=case when attempts>=5 and p_status='PENDING' then 'FAILED' else p_status end,
 last_error=left(p_error,80),available_at=now()+interval '5 minutes',delivered_at=case when p_status='DELIVERED' then now() end
 where id=p_id and lease_id=p_lease and status='SENDING';
end $$;
create function public.tk_subscribe_restock(p_variant uuid,p_active boolean) returns void language plpgsql security definer set search_path='' as $$
declare stock_count integer;
begin
 if auth.uid() is null then raise exception 'Sign in for restock alerts.'; end if;
 if p_active=false then
  update public.tk_restock_subscriptions set active=false where user_id=auth.uid() and variant_id=p_variant;
  return;
 end if;
 select stock into stock_count from public.tk_variants v join public.tk_products p on p.id=v.product_id where v.id=p_variant and p.active for update of v;
 if stock_count is null then raise exception 'Variant unavailable.'; end if;
 if p_active and stock_count>0 then raise exception 'This size is already available.'; end if;
 insert into public.tk_restock_subscriptions(user_id,variant_id,active) values(auth.uid(),p_variant,p_active)
 on conflict(user_id,variant_id) do update set active=excluded.active,notified_at=case when excluded.active then null else tk_restock_subscriptions.notified_at end;
end $$;
create function public.tk_restock_transition() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.tk_restock_subscriptions;
begin
 if old.stock=0 and new.stock>0 and exists(select 1 from public.tk_products where id=new.product_id and active) then
  for s in update public.tk_restock_subscriptions set active=false,notified_at=now() where variant_id=new.id and active returning * loop
   insert into public.tk_notifications(user_id,title,message,category,target_id) values(s.user_id,'Your size is available','A pair you followed is back in stock. Availability may change.','restock',new.product_id);
  end loop;
 end if;return new;
end $$;
create trigger tk_restock_transition after update of stock on public.tk_variants for each row execute function public.tk_restock_transition();
create function public.tk_save_shipment(p_order uuid,p_courier text,p_number text,p_url text,p_message text) returns void language plpgsql security definer set search_path='' as $$
declare o public.tk_orders;
begin
 if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
 select * into o from public.tk_orders where id=p_order for update;
 if o.id is null or o.status='CANCELLED' or (o.payment_method='XENDIT' and o.payment_status<>'PAID') then raise exception 'This order is not ready for shipment updates.'; end if;
 insert into public.tk_shipments(order_id,courier,tracking_number,tracking_url) values(o.id,trim(p_courier),trim(p_number),trim(p_url)) on conflict(order_id) do update set courier=excluded.courier,tracking_number=excluded.tracking_number,tracking_url=excluded.tracking_url,updated_at=now();
 insert into public.tk_tracking_events(order_id,status,message,created_by) values(o.id,o.status,p_message,auth.uid());
 insert into public.tk_notifications(user_id,order_id,title,message) values(o.user_id,o.id,'Delivery update','The store added a tracking update to your order.');
end $$;
create function public.tk_create_ticket(p_category text,p_subject text,p_message text,p_order uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if p_order is not null and not exists(select 1 from public.tk_orders where id=p_order and user_id=auth.uid()) then raise exception 'Order not found.'; end if;
 insert into public.tk_support_tickets(user_id,order_id,category,subject) values(auth.uid(),p_order,p_category,trim(p_subject)) returning id into result;
 insert into public.tk_support_messages(ticket_id,user_id,staff,message) values(result,auth.uid(),false,trim(p_message));
 return result;
end $$;
create function public.tk_reply_ticket(p_ticket uuid,p_message text,p_status text default null) returns void language plpgsql security definer set search_path='' as $$
declare t public.tk_support_tickets;staff boolean:=public.tk_is_admin();next_status text;
begin
 select * into t from public.tk_support_tickets where id=p_ticket for update;
 if auth.uid() is null or t.id is null or (not staff and t.user_id<>auth.uid()) then raise exception 'Ticket not found.'; end if;
 if not staff and (t.status='CLOSED' or (p_status is not null and not (t.status='RESOLVED' and p_status='OPEN' and t.updated_at>now()-interval '30 days'))) then raise exception 'This ticket cannot be reopened. Create a new ticket.'; end if;
 next_status:=coalesce(p_status,case when not staff and t.status='WAITING_FOR_CUSTOMER' then 'OPEN' else t.status end);
 if staff and t.status='CLOSED' and next_status<>'CLOSED' then raise exception 'Closed tickets are final.'; end if;
 if length(trim(coalesce(p_message,'')))>0 then
  insert into public.tk_support_messages(ticket_id,user_id,staff,message) values(t.id,auth.uid(),staff,trim(p_message));
  if staff then insert into public.tk_notifications(user_id,title,message,category,target_id) values(t.user_id,'Support replied','There is a new reply on your support ticket.','support',t.id); end if;
 elsif p_status is null then raise exception 'Write a reply.'; end if;
 if next_status<>t.status then insert into public.tk_support_events(ticket_id,actor_id,previous_status,status) values(t.id,auth.uid(),t.status,next_status); end if;
 update public.tk_support_tickets set status=next_status,updated_at=now() where id=t.id;
end $$;

do $$ declare t text; begin
 foreach t in array array['tk_restock_subscriptions','tk_shipments','tk_tracking_events','tk_support_tickets','tk_support_messages','tk_support_events','tk_notification_preferences','tk_device_tokens','tk_notification_outbox'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on public.%I from anon,authenticated',t);
 execute format('grant all on public.%I to service_role',t);
 end loop;end $$;
grant select on public.tk_restock_subscriptions,public.tk_shipments,public.tk_tracking_events,public.tk_support_tickets,public.tk_support_messages,public.tk_support_events,public.tk_notification_preferences to authenticated;
create policy tk_restock_read on public.tk_restock_subscriptions for select to authenticated using(user_id=auth.uid() or public.tk_is_admin());
create policy tk_shipment_read on public.tk_shipments for select to authenticated using(exists(select 1 from public.tk_orders where id=order_id and (user_id=auth.uid() or public.tk_is_admin())));
create policy tk_tracking_read on public.tk_tracking_events for select to authenticated using(exists(select 1 from public.tk_orders where id=order_id and (user_id=auth.uid() or public.tk_is_admin())));
create policy tk_ticket_read on public.tk_support_tickets for select to authenticated using(user_id=auth.uid() or public.tk_is_admin());
create policy tk_messages_read on public.tk_support_messages for select to authenticated using(exists(select 1 from public.tk_support_tickets where id=ticket_id and (user_id=auth.uid() or public.tk_is_admin())));
create policy tk_support_event_read on public.tk_support_events for select to authenticated using(exists(select 1 from public.tk_support_tickets where id=ticket_id and (user_id=auth.uid() or public.tk_is_admin())));
create policy tk_preference_owner on public.tk_notification_preferences to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
grant insert,update on public.tk_notification_preferences to authenticated;
revoke all on function public.tk_register_device(text,boolean),public.tk_subscribe_restock(uuid,boolean),public.tk_save_shipment(uuid,text,text,text,text),public.tk_create_ticket(text,text,text,uuid),public.tk_reply_ticket(uuid,text,text) from public,anon;
grant execute on function public.tk_register_device(text,boolean),public.tk_subscribe_restock(uuid,boolean),public.tk_save_shipment(uuid,text,text,text,text),public.tk_create_ticket(text,text,text,uuid),public.tk_reply_ticket(uuid,text,text) to authenticated;
revoke all on function public.tk_push_enqueue(),public.tk_claim_push(integer),public.tk_finish_push(uuid,uuid,text,text),public.tk_restock_transition() from public,anon,authenticated;
grant execute on function public.tk_claim_push(integer),public.tk_finish_push(uuid,uuid,text,text) to service_role;
grant usage,select on sequence public.tk_support_tickets_number_seq to service_role;
commit;
