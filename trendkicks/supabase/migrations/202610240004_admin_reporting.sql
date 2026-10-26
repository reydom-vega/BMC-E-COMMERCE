begin;
-- Provider approval and settlement are distinct. Financial completion remains service-only.
alter table public.tk_refunds add column processing_status text not null default 'NOT_STARTED'
 check(processing_status in ('NOT_STARTED','PROCESSING','FAILED','COMPLETED'));
create function public.tk_refund_processing(p_refund uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.tk_is_admin() or p_status not in ('PROCESSING','FAILED') then raise exception 'Administrator access required.'; end if;
 update public.tk_refunds set processing_status=p_status where id=p_refund and status='APPROVED' and processing_status<>'COMPLETED';
 if not found then raise exception 'An approved, unsettled refund is required.'; end if;
end $$;
create function public.tk_confirm_refund(p_order uuid,p_reference text,p_amount integer) returns void language plpgsql security definer set search_path='' as $$
declare o public.tk_orders;total_refund bigint;earned integer;reversed integer;deduct integer;available integer;remaining integer;
begin
 select * into o from public.tk_orders where id=p_order for update;
 if exists(select 1 from public.tk_refund_settlements where provider_reference=p_reference) then
  if not exists(select 1 from public.tk_refund_settlements where provider_reference=p_reference and order_id=p_order and amount_cents=p_amount) then raise exception 'Refund reference mismatch.'; end if;
  return;
 end if;
 if o.id is null or o.payment_status not in ('PAID','REFUND_REQUIRED') or p_amount is null or p_amount<=0 or length(trim(p_reference)) not between 3 and 200 then raise exception 'Invalid verified refund.'; end if;
 select coalesce(sum(amount_cents),0)+p_amount into total_refund from public.tk_refund_settlements where order_id=p_order;
 if total_refund>o.total_cents then raise exception 'Refund exceeds the collected amount.'; end if;
 insert into public.tk_refund_settlements(order_id,provider_reference,amount_cents) values(p_order,p_reference,p_amount);
 select coalesce(sum(points),0) into earned from public.tk_loyalty_ledger where order_id=p_order and kind='EARN';
 select -coalesce(sum(points),0) into reversed from public.tk_loyalty_ledger where order_id=p_order and kind='REVERSE';
 deduct:=greatest(0,(earned::bigint*total_refund/greatest(1,o.total_cents))::integer-reversed);
 insert into public.tk_loyalty_accounts(user_id) values(o.user_id) on conflict do nothing;
 select balance into available from public.tk_loyalty_accounts where user_id=o.user_id for update;
 remaining:=greatest(0,deduct-available);
 update public.tk_loyalty_accounts set balance=greatest(0,balance-deduct),debt=debt+remaining where user_id=o.user_id;
 if deduct>0 then insert into public.tk_loyalty_ledger(user_id,order_id,kind,points,source) values(o.user_id,o.id,'REVERSE',-deduct,'refund:'||p_reference); end if;
 if total_refund=o.total_cents then
  update public.tk_voucher_redemptions set status='REFUNDED' where order_id=o.id and status='CONFIRMED';
  if o.redeemed_points>0 and not exists(select 1 from public.tk_loyalty_ledger where source='release:'||o.id) then
   insert into public.tk_loyalty_ledger(user_id,order_id,kind,points,source) values(o.user_id,o.id,'RELEASE',o.redeemed_points,'release:'||o.id);
   update public.tk_loyalty_accounts set balance=balance+greatest(0,o.redeemed_points-tk_loyalty_accounts.debt),debt=greatest(0,tk_loyalty_accounts.debt-o.redeemed_points) where user_id=o.user_id;
  end if;
  update public.tk_refunds set processing_status='COMPLETED' where order_id=o.id and status='APPROVED';
 end if;
 insert into public.tk_notifications(user_id,order_id,title,message) values(o.user_id,o.id,'Refund verified','A refund settlement has been verified. View your order for details.');
end $$;

create function public.tk_sales_report(p_start date,p_end date) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;from_time timestamptz;to_time timestamptz;
begin
 if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
 if p_start is null or p_end is null or p_end<p_start or p_end-p_start>730 then raise exception 'Choose a date range of up to two years.'; end if;
 from_time:=p_start::timestamp at time zone 'Asia/Manila';to_time:=(p_end+1)::timestamp at time zone 'Asia/Manila';
 with collected as (select * from public.tk_orders where payment_status in ('PAID','REFUND_REQUIRED') and coalesce(paid_at,updated_at)>=from_time and coalesce(paid_at,updated_at)<to_time),
 refunds as(select coalesce(sum(amount_cents),0) amount from public.tk_refund_settlements where verified_at>=from_time and verified_at<to_time),
 placed as(select * from public.tk_orders where created_at>=from_time and created_at<to_time),
 daily as(select (coalesce(paid_at,updated_at) at time zone 'Asia/Manila')::date as sale_day,sum(total_cents) cents from collected group by 1),
 monthly as(select to_char(coalesce(paid_at,updated_at) at time zone 'Asia/Manila','YYYY-MM') as sale_month,sum(total_cents) cents from collected group by 1),
 performance as(select x->>'product_id' product_id,x->>'name' name,sum((x->>'quantity')::integer) quantity,sum((x->>'quantity')::bigint*(x->>'unit_price_cents')::integer) gross_cents from collected c cross join lateral jsonb_array_elements(c.items) x group by 1,2),
 statuses as(select status,count(*) count from placed group by status),methods as(select payment_method,count(*) count,sum(total_cents) cents from collected group by payment_method)
 select jsonb_build_object('start',p_start,'end',p_end,'timezone','Asia/Manila',
  'orders',(select count(*) from placed),'paid_orders',(select count(*) from placed where payment_status='PAID'),
  'pending_orders',(select count(*) from placed where payment_status in ('PENDING','DUE') and status<>'CANCELLED'),'cancelled_orders',(select count(*) from placed where status='CANCELLED'),
  'gross_cents',coalesce(sum(subtotal_cents::bigint+shipping_cents),0),'voucher_cents',coalesce(sum(voucher_discount_cents),0),'loyalty_cents',coalesce(sum(loyalty_discount_cents),0),
  'collected_cents',coalesce(sum(total_cents),0),'refund_cents',(select amount from refunds),'net_cents',coalesce(sum(total_cents),0)-(select amount from refunds),
  'average_cents',coalesce(round(avg(total_cents)),0),'legacy_payment_dates',count(*) filter(where paid_at is null),
  'voucher_uses',count(*) filter(where voucher_discount_cents>0),'redeemed_points',coalesce(sum(redeemed_points),0),
  'daily',coalesce((select jsonb_agg(to_jsonb(d) order by sale_day) from daily d),'[]'),
  'monthly',coalesce((select jsonb_agg(to_jsonb(m) order by sale_month) from monthly m),'[]'),
  'products',coalesce((select jsonb_agg(to_jsonb(p) order by quantity desc) from performance p),'[]'),
  'statuses',coalesce((select jsonb_agg(to_jsonb(s)) from statuses s),'[]'),
  'methods',coalesce((select jsonb_agg(to_jsonb(m)) from methods m),'[]'),
  'low_stock',(select count(*) from public.tk_variants v join public.tk_products p on p.id=v.product_id where p.active and v.stock between 1 and 5),
  'out_of_stock',(select count(*) from public.tk_variants v join public.tk_products p on p.id=v.product_id where p.active and v.stock=0),
  'today_cents',(select coalesce(sum(total_cents),0) from public.tk_orders where payment_status in ('PAID','REFUND_REQUIRED') and coalesce(paid_at,updated_at)>=(now() at time zone 'Asia/Manila')::date::timestamp at time zone 'Asia/Manila'),
  'week_cents',(select coalesce(sum(total_cents),0) from public.tk_orders where payment_status in ('PAID','REFUND_REQUIRED') and coalesce(paid_at,updated_at)>=((now() at time zone 'Asia/Manila')::date-6)::timestamp at time zone 'Asia/Manila'),
  'month_cents',(select coalesce(sum(total_cents),0) from public.tk_orders where payment_status in ('PAID','REFUND_REQUIRED') and coalesce(paid_at,updated_at)>=date_trunc('month',now() at time zone 'Asia/Manila') at time zone 'Asia/Manila'),
  'all_time_cents',(select coalesce(sum(total_cents),0) from public.tk_orders where payment_status in ('PAID','REFUND_REQUIRED'))
 ) into result from collected;
 return result;
end $$;

create function public.tk_reward_notification() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.kind='EARN' and new.points>0 then insert into public.tk_notifications(user_id,order_id,title,message,category) values(new.user_id,new.order_id,'Rewards earned','Your delivered purchase earned reward points.','rewards'); end if;
 return new;
end $$;
create trigger tk_reward_notification after insert on public.tk_loyalty_ledger for each row execute function public.tk_reward_notification();
revoke all on function public.tk_reward_notification(),public.tk_confirm_refund(uuid,text,integer),public.tk_refund_processing(uuid,text),public.tk_sales_report(date,date) from public,anon,authenticated;
grant execute on function public.tk_confirm_refund(uuid,text,integer) to service_role;
grant execute on function public.tk_refund_processing(uuid,text),public.tk_sales_report(date,date) to authenticated;
create index on public.tk_orders(paid_at) where paid_at is not null;
create index on public.tk_refund_settlements(verified_at);
commit;
