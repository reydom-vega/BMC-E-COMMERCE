begin;
-- Legacy checkout remains callable during the PHP rollout. All new money is centavos.
alter table public.tk_orders drop constraint tk_orders_check;
alter table public.tk_orders
 add column voucher_discount_cents integer not null default 0 check(voucher_discount_cents>=0),
 add column loyalty_discount_cents integer not null default 0 check(loyalty_discount_cents>=0),
 add column voucher_snapshot jsonb,
 add column redeemed_points integer not null default 0 check(redeemed_points>=0),
 add column paid_at timestamptz,
 add column payment_reference text,
 add constraint tk_discount_total check(total_cents=subtotal_cents+shipping_cents-voucher_discount_cents-loyalty_discount_cents
   and voucher_discount_cents+loyalty_discount_cents<=subtotal_cents);
alter table public.tk_notifications alter column order_id drop not null;

create table public.tk_customer_addresses(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id) on delete cascade,
 recipient text not null check(length(trim(recipient)) between 2 and 120),mobile text not null check(mobile ~ '^\+?[0-9 ()-]{7,25}$'),
 label text not null default 'Home' check(label in ('Home','School','Office','Other')),
 street text not null check(length(trim(street)) between 2 and 200),barangay text not null check(length(barangay) between 1 and 100),
 city text not null check(length(city) between 1 and 100),province text not null check(length(province) between 1 and 100),
 postal_code text not null check(postal_code ~ '^[0-9]{4}$'),instructions text not null default '' check(length(instructions)<=300),
 is_default boolean not null default false,created_at timestamptz not null default now());
create unique index tk_address_default on public.tk_customer_addresses(user_id) where is_default;
create index on public.tk_customer_addresses(user_id);

create table public.tk_vouchers(
 id uuid primary key default gen_random_uuid(),code text not null unique check(code=upper(trim(code)) and code ~ '^[A-Z0-9_-]{3,40}$'),
 kind text not null check(kind in ('PERCENT','FIXED')),value integer not null check(value>0),
 minimum_cents integer not null default 0 check(minimum_cents>=0),cap_cents integer check(cap_cents>0),
 starts_at timestamptz not null default now(),ends_at timestamptz not null,
 usage_limit integer check(usage_limit>0),per_user_limit integer not null default 1 check(per_user_limit>0),
 product_ids uuid[] not null default '{}',categories text[] not null default '{}',first_purchase boolean not null default false,
 active boolean not null default true,check(ends_at>starts_at),check(kind<>'PERCENT' or value<=100));
create table public.tk_voucher_redemptions(
 order_id uuid primary key references public.tk_orders(id),voucher_id uuid not null references public.tk_vouchers(id),
 user_id uuid not null references auth.users(id),status text not null check(status in ('RESERVED','CONFIRMED','RELEASED','REFUNDED')),
 discount_cents integer not null check(discount_cents>=0),created_at timestamptz not null default now());
create index on public.tk_voucher_redemptions(voucher_id,user_id,status);
create table public.tk_loyalty_rules(
 id integer primary key check(id=1),active boolean not null default true,
 earn_spend_cents integer not null default 10000 check(earn_spend_cents>0),
 redeem_points integer not null default 100 check(redeem_points>0),redeem_value_cents integer not null default 5000 check(redeem_value_cents>0),
 minimum_points integer not null default 100 check(minimum_points>0),max_discount_cents integer not null default 50000 check(max_discount_cents>0));
insert into public.tk_loyalty_rules(id) values(1);
create table public.tk_loyalty_accounts(user_id uuid primary key references auth.users(id),balance integer not null default 0 check(balance>=0),debt integer not null default 0 check(debt>=0));
create table public.tk_loyalty_ledger(
 id uuid primary key default gen_random_uuid(),user_id uuid not null references auth.users(id),order_id uuid not null references public.tk_orders(id),
 kind text not null check(kind in ('RESERVE','RELEASE','REDEEM','EARN','REVERSE')),points integer not null,source text not null unique,
 created_at timestamptz not null default now());
create index on public.tk_loyalty_ledger(user_id,created_at desc);
create table public.tk_payment_events(
 event_key text primary key,order_id uuid not null references public.tk_orders(id),invoice_id text not null,status text not null,
 amount_cents bigint not null,currency text not null check(currency='PHP'),created_at timestamptz not null default now());
create index on public.tk_payment_events(order_id);
create table public.tk_receipts(
 order_id uuid primary key references public.tk_orders(id),reference text not null unique default ('TKR-'||gen_random_uuid()::text),
 snapshot jsonb not null,created_at timestamptz not null default now());
create table public.tk_refund_settlements(
 id uuid primary key default gen_random_uuid(),order_id uuid not null references public.tk_orders(id),
 provider_reference text not null unique,amount_cents integer not null check(amount_cents>0),verified_at timestamptz not null default now());
-- Approval of tk_refunds never inserts a settlement. Only a trusted reconciliation adapter may do so.

create function public.tk_save_address(p_data jsonb,p_id uuid default null) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 perform pg_advisory_xact_lock(hashtextextended('address:'||auth.uid()::text,0));
 if p_id is not null and not exists(select 1 from public.tk_customer_addresses where id=p_id and user_id=auth.uid()) then raise exception 'Address not found.'; end if;
 if coalesce((p_data->>'is_default')::boolean,false) then update public.tk_customer_addresses set is_default=false where user_id=auth.uid(); end if;
 insert into public.tk_customer_addresses(id,user_id,recipient,mobile,label,street,barangay,city,province,postal_code,instructions,is_default)
 values(coalesce(p_id,gen_random_uuid()),auth.uid(),p_data->>'recipient',p_data->>'mobile',p_data->>'label',p_data->>'street',p_data->>'barangay',p_data->>'city',p_data->>'province',p_data->>'postal_code',coalesce(p_data->>'instructions',''),coalesce((p_data->>'is_default')::boolean,false))
 on conflict(id) do update set recipient=excluded.recipient,mobile=excluded.mobile,label=excluded.label,street=excluded.street,barangay=excluded.barangay,city=excluded.city,province=excluded.province,postal_code=excluded.postal_code,instructions=excluded.instructions,is_default=excluded.is_default returning id into result;
 return result;
end $$;

-- Same quote primitive is used within the checkout transaction, under voucher/account locks.
create function public.tk_quote(p_items jsonb,p_code text default '',p_points integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
begin return public.tk_quote_order_internal(p_items,p_code,p_points,null); end $$;

create function public.tk_checkout_v2(p_items jsonb,p_delivery jsonb,p_method text,p_request_key uuid,p_code text default '',p_points integer default 0,p_address uuid default null,p_expected_total_cents integer default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare result_id uuid;q jsonb;a public.tk_customer_addresses;d jsonb:=p_delivery;
begin
 if auth.uid() is null then raise exception 'Please sign in before checkout.'; end if;
 perform pg_advisory_xact_lock(hashtextextended('checkout:'||auth.uid()::text,0));
 select o.id into result_id from public.tk_orders o where user_id=auth.uid() and request_key=p_request_key;
 if result_id is not null then return result_id; end if;
 insert into public.tk_loyalty_accounts(user_id) values(auth.uid()) on conflict do nothing;
 perform 1 from public.tk_loyalty_accounts where user_id=auth.uid() for update;
 perform 1 from public.tk_vouchers where code=upper(trim(p_code)) for update;
 perform 1 from public.tk_settings where id=1 for share;
 if p_address is not null then
  select * into a from public.tk_customer_addresses where tk_customer_addresses.id=p_address and user_id=auth.uid();
  if a.id is null then raise exception 'Address not found.'; end if;
  d:=jsonb_build_object('name',a.recipient,'phone',a.mobile,'address',concat_ws(', ',a.street,a.barangay,a.city,a.province,a.postal_code),'instructions',a.instructions);
 end if;
 -- Legacy primitive locks variants in a stable order and stores immutable prices.
 result_id:=public.tk_create_order(p_items,d,p_method,p_request_key,null);
 q:=public.tk_quote_order_internal(p_items,p_code,p_points,result_id);
 if p_expected_total_cents is not null and p_expected_total_cents<>(q->>'total_cents')::integer then raise exception 'Prices or discounts changed. Review the new total.'; end if;
 if p_method='XENDIT' and (q->>'total_cents')::integer<100 then raise exception 'Online payment requires at least PHP 1.00; choose COD.'; end if;
 update public.tk_orders set delivery=d,voucher_discount_cents=(q->>'voucher_discount_cents')::integer,loyalty_discount_cents=(q->>'loyalty_discount_cents')::integer,total_cents=(q->>'total_cents')::integer,voucher_snapshot=q->'voucher_snapshot',redeemed_points=p_points where tk_orders.id=result_id;
 if q->>'voucher_id' is not null then insert into public.tk_voucher_redemptions values(result_id,(q->>'voucher_id')::uuid,auth.uid(),'RESERVED',(q->>'voucher_discount_cents')::integer,now()); end if;
 if p_points>0 then
  update public.tk_loyalty_accounts set balance=balance-p_points where user_id=auth.uid();
  insert into public.tk_loyalty_ledger(user_id,order_id,kind,points,source) values(auth.uid(),result_id,'RESERVE',-p_points,'reserve:'||result_id);
 end if;
 return result_id;
end $$;

-- Quote variant used only after the locked legacy reservation: first-purchase is
-- checked by the caller against all other orders. No session flag can bypass it.
-- Both preview and the locked checkout delegate to this single calculation.
create function public.tk_quote_order_internal(p_items jsonb,p_code text,p_points integer,p_exclude uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare subtotal bigint;eligible bigint;shipping integer;v public.tk_vouchers;r public.tk_loyalty_rules;vd integer:=0;ld integer:=0;balance integer;
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 50 then raise exception 'Your bag is invalid.'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) x where coalesce(x->>'quantity','') !~ '^[1-9][0-9]?$') then raise exception 'Invalid quantity.'; end if;
 select sum(p.price_cents::bigint*(x->>'quantity')::integer) into subtotal from jsonb_array_elements(p_items) x join public.tk_variants s on s.id=(x->>'variant_id')::uuid join public.tk_products p on p.id=s.product_id and p.active;
 if subtotal is null or subtotal>2000000000 or (select count(*) from jsonb_array_elements(p_items))<>(select count(*) from jsonb_array_elements(p_items) x join public.tk_variants s on s.id=(x->>'variant_id')::uuid join public.tk_products p on p.id=s.product_id and p.active) then raise exception 'A product is unavailable.'; end if;
 select shipping_cents into shipping from public.tk_settings where id=1;
 if length(trim(coalesce(p_code,'')))>0 then
  select * into v from public.tk_vouchers where code=upper(trim(p_code));
  if v.id is null or not v.active then raise exception 'This voucher is invalid or disabled.'; end if;
  if v.starts_at>now() then raise exception 'This voucher is not active yet.'; end if;
  if v.ends_at<=now() then raise exception 'This voucher has expired.'; end if;
  if subtotal<v.minimum_cents then raise exception 'Your order does not meet the minimum purchase amount.'; end if;
  if v.usage_limit is not null and (select count(*) from public.tk_voucher_redemptions where voucher_id=v.id and status in ('RESERVED','CONFIRMED','REFUNDED'))>=v.usage_limit then raise exception 'This voucher is fully redeemed.'; end if;
  if (select count(*) from public.tk_voucher_redemptions where voucher_id=v.id and user_id=auth.uid() and status in ('RESERVED','CONFIRMED','REFUNDED'))>=v.per_user_limit then raise exception 'You have already used this voucher.'; end if;
  if v.first_purchase and exists(select 1 from public.tk_orders where user_id=auth.uid() and (p_exclude is null or id<>p_exclude) and status<>'CANCELLED') then raise exception 'This voucher is for your first purchase.'; end if;
  select coalesce(sum(p.price_cents::bigint*(x->>'quantity')::integer),0) into eligible from jsonb_array_elements(p_items) x join public.tk_variants s on s.id=(x->>'variant_id')::uuid join public.tk_products p on p.id=s.product_id
   where (cardinality(v.product_ids)=0 or p.id=any(v.product_ids)) and (cardinality(v.categories)=0 or p.category=any(v.categories));
  if eligible=0 then raise exception 'This voucher does not apply to these products.'; end if;
  vd:=least(eligible,coalesce(v.cap_cents,2000000000),case when v.kind='PERCENT' then eligible*v.value/100 else v.value end);
 end if;
 if p_points is null or p_points<0 then raise exception 'Choose valid reward points.'; end if;
 if p_points>0 then
  select * into r from public.tk_loyalty_rules where id=1;
  select a.balance into balance from public.tk_loyalty_accounts a where user_id=auth.uid();
  if not r.active or p_points<r.minimum_points or p_points%r.redeem_points<>0 then raise exception 'Choose a valid rewards redemption.'; end if;
  if p_points>coalesce(balance,0) then raise exception 'You do not have enough available points.'; end if;
  ld:=(p_points::bigint/r.redeem_points)*r.redeem_value_cents;
  if ld>r.max_discount_cents or ld>subtotal-vd then raise exception 'Reward redemption exceeds this order limit.'; end if;
 end if;
 return jsonb_build_object('subtotal_cents',subtotal,'shipping_cents',shipping,'voucher_discount_cents',vd,'loyalty_discount_cents',ld,'total_cents',subtotal+shipping-vd-ld,'voucher_id',v.id,'voucher_snapshot',case when v.id is not null then to_jsonb(v) end,'redeemed_points',p_points);
end $$;


create function public.tk_financial_lifecycle() returns trigger language plpgsql security definer set search_path='' as $$
declare earned integer;adjusted integer;settled bigint;credited integer;available integer;debt integer;r public.tk_loyalty_rules;
begin
 if new.payment_status in ('PAID','REFUND_REQUIRED') and new.paid_at is null and old.payment_status not in ('PAID','REFUND_REQUIRED') then
  new.paid_at:=now(); new.payment_reference:=coalesce(new.invoice_id,'COD-'||new.id);
 end if;
 if new.status='CANCELLED' and old.status<>'CANCELLED' then
  update public.tk_voucher_redemptions set status=case when status='CONFIRMED' then 'CONFIRMED' else 'RELEASED' end where order_id=new.id and status in ('RESERVED','CONFIRMED');
  if old.payment_status not in ('PAID','REFUND_REQUIRED') and new.redeemed_points>0 and not exists(select 1 from public.tk_loyalty_ledger where source='release:'||new.id) then
   insert into public.tk_loyalty_ledger(user_id,order_id,kind,points,source) values(new.user_id,new.id,'RELEASE',new.redeemed_points,'release:'||new.id);
   update public.tk_loyalty_accounts set balance=balance+greatest(0,new.redeemed_points-tk_loyalty_accounts.debt),debt=greatest(0,tk_loyalty_accounts.debt-new.redeemed_points) where user_id=new.user_id;
  end if;
 elsif new.payment_status='PAID' and old.payment_status<>'PAID' then
  update public.tk_voucher_redemptions set status='CONFIRMED' where order_id=new.id and status='RESERVED';
  if new.redeemed_points>0 then insert into public.tk_loyalty_ledger(user_id,order_id,kind,points,source) values(new.user_id,new.id,'REDEEM',0,'redeem:'||new.id) on conflict do nothing; end if;
 end if;
 if new.payment_status='PAID' and new.status='DELIVERED' and (old.payment_status<>'PAID' or old.status<>'DELIVERED') then
  select * into r from public.tk_loyalty_rules where id=1;
  earned:=case when r.active then (new.subtotal_cents-new.voucher_discount_cents-new.loyalty_discount_cents)/r.earn_spend_cents else 0 end;
  select coalesce(sum(amount_cents),0) into settled from public.tk_refund_settlements where order_id=new.id;
  adjusted:=greatest(0,earned-(earned::bigint*settled/greatest(1,new.total_cents))::integer);
  insert into public.tk_loyalty_accounts(user_id) values(new.user_id) on conflict do nothing;
  select a.balance,a.debt into available,debt from public.tk_loyalty_accounts a where user_id=new.user_id for update;
  credited:=greatest(0,adjusted-debt);
  insert into public.tk_loyalty_ledger(user_id,order_id,kind,points,source) values(new.user_id,new.id,'EARN',earned,'earn:'||new.id) on conflict do nothing;
  if found then
   update public.tk_loyalty_accounts set balance=balance+credited,debt=greatest(0,tk_loyalty_accounts.debt-adjusted) where user_id=new.user_id;
   if earned>adjusted then insert into public.tk_loyalty_ledger(user_id,order_id,kind,points,source) values(new.user_id,new.id,'REVERSE',adjusted-earned,'refund-before-earn:'||new.id); end if;
  end if;
 end if;
 return new;
end $$;
create trigger tk_financial_lifecycle before update on public.tk_orders for each row execute function public.tk_financial_lifecycle();
create function public.tk_receipt_lifecycle() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.payment_status='PAID' and new.paid_at is not null then
  insert into public.tk_receipts(order_id,snapshot) values(new.id,to_jsonb(new)) on conflict do nothing;
 end if; return new;
end $$;
create trigger tk_receipt_lifecycle after update on public.tk_orders for each row execute function public.tk_receipt_lifecycle();
-- Historical PAID rows are preserved but not retroactively declared provider-verified.

create function public.tk_record_payment(p_order uuid,p_invoice text,p_status text,p_amount_cents bigint,p_currency text) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform public.tk_apply_payment(p_order,p_invoice,p_status,p_amount_cents,p_currency);
 if p_status in ('PAID','SETTLED') then
  update public.tk_orders set paid_at=now(),payment_reference=p_invoice where id=p_order and paid_at is null and payment_status in ('PAID','REFUND_REQUIRED');
 end if;
 insert into public.tk_payment_events(event_key,order_id,invoice_id,status,amount_cents,currency)
 values(p_invoice||':'||case when p_status='SETTLED' then 'PAID' else p_status end,p_order,p_invoice,p_status,p_amount_cents,p_currency) on conflict do nothing;
end $$;

create function public.tk_no_ledger_edit() returns trigger language plpgsql set search_path='' as $$ begin raise exception 'The rewards ledger is immutable.'; end $$;
create trigger tk_ledger_immutable before update or delete on public.tk_loyalty_ledger for each row execute function public.tk_no_ledger_edit();

-- Owner-scoped reads; financial changes occur exclusively in guarded functions.
do $$ declare t text; begin
 foreach t in array array['tk_customer_addresses','tk_vouchers','tk_voucher_redemptions','tk_loyalty_rules','tk_loyalty_accounts','tk_loyalty_ledger','tk_payment_events','tk_receipts','tk_refund_settlements'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from anon,authenticated',t);
  execute format('grant all on public.%I to service_role',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create policy tk_address_read on public.tk_customer_addresses for select to authenticated using(user_id=auth.uid());
create policy tk_address_delete on public.tk_customer_addresses for delete to authenticated using(user_id=auth.uid());
grant delete on public.tk_customer_addresses to authenticated;
create policy tk_voucher_admin on public.tk_vouchers to authenticated using(public.tk_is_admin()) with check(public.tk_is_admin());
grant insert,update on public.tk_vouchers to authenticated;
create policy tk_redemption_read on public.tk_voucher_redemptions for select to authenticated using(user_id=auth.uid() or public.tk_is_admin());
create policy tk_rules_read on public.tk_loyalty_rules for select to authenticated using(true);
create policy tk_rules_edit on public.tk_loyalty_rules for update to authenticated using(public.tk_is_admin()) with check(public.tk_is_admin());
grant update on public.tk_loyalty_rules to authenticated;
create policy tk_balance_read on public.tk_loyalty_accounts for select to authenticated using(user_id=auth.uid() or public.tk_is_admin());
create policy tk_ledger_read on public.tk_loyalty_ledger for select to authenticated using(user_id=auth.uid() or public.tk_is_admin());
create policy tk_payment_read on public.tk_payment_events for select to authenticated using(exists(select 1 from public.tk_orders o where o.id=order_id and (o.user_id=auth.uid() or public.tk_is_admin())));
create policy tk_receipt_read on public.tk_receipts for select to authenticated using(exists(select 1 from public.tk_orders o where o.id=order_id and (o.user_id=auth.uid() or public.tk_is_admin())));
create policy tk_settlement_read on public.tk_refund_settlements for select to authenticated using(exists(select 1 from public.tk_orders o where o.id=order_id and (o.user_id=auth.uid() or public.tk_is_admin())));
revoke all on function public.tk_save_address(jsonb,uuid),public.tk_quote(jsonb,text,integer),public.tk_checkout_v2(jsonb,jsonb,text,uuid,text,integer,uuid,integer) from public,anon;
grant execute on function public.tk_save_address(jsonb,uuid),public.tk_quote(jsonb,text,integer),public.tk_checkout_v2(jsonb,jsonb,text,uuid,text,integer,uuid,integer) to authenticated;
revoke all on function public.tk_quote_order_internal(jsonb,text,integer,uuid),public.tk_financial_lifecycle(),public.tk_receipt_lifecycle(),public.tk_no_ledger_edit(),public.tk_record_payment(uuid,text,text,bigint,text) from public,anon,authenticated;
grant execute on function public.tk_record_payment(uuid,text,text,bigint,text) to service_role;
commit;
