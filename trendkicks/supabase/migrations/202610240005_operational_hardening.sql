begin;
alter table public.tk_review_images add column purged_at timestamptz;
create unique index tk_promotion_once on public.tk_notifications(user_id,category,target_id) where category='promotions' and target_id is not null;
create function public.tk_promote_voucher(p_voucher uuid) returns integer language plpgsql security definer set search_path='' as $$
declare v public.tk_vouchers;n integer;
begin
 if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
 select * into v from public.tk_vouchers where id=p_voucher;
 if v.id is null or not v.active or v.ends_at<=now() then raise exception 'Choose an active voucher.'; end if;
 insert into public.tk_notifications(user_id,title,message,category,target_id)
 select user_id,'A new voucher is available','Use code '||v.code||' at checkout. Eligibility and expiry apply.','promotions',v.id
 from public.tk_notification_preferences where promotions on conflict do nothing;
 get diagnostics n=row_count;return n;
end $$;
create function public.tk_deactivate_devices() returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 update public.tk_device_tokens set active=false where user_id=auth.uid();
end $$;
-- Full settled refunds prevent further fulfillment. Existing status machine stays intact.
alter function public.tk_advance_order(uuid,text) rename to tk_advance_order_legacy;
create function public.tk_advance_order(p_order uuid,p_status text) returns void language plpgsql security definer set search_path='' as $$
declare o public.tk_orders;
begin
 if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
 select * into o from public.tk_orders where id=p_order for update;
 if exists(select 1 from public.tk_refund_settlements where order_id=o.id) and (select sum(amount_cents) from public.tk_refund_settlements where order_id=o.id)>=o.total_cents then raise exception 'A fully refunded order cannot be fulfilled.'; end if;
 perform public.tk_advance_order_legacy(p_order,p_status);
end $$;
revoke all on function public.tk_advance_order_legacy(uuid,text) from public,anon,authenticated;
revoke all on function public.tk_promote_voucher(uuid),public.tk_deactivate_devices(),public.tk_advance_order(uuid,text) from public,anon;
grant execute on function public.tk_promote_voucher(uuid),public.tk_deactivate_devices(),public.tk_advance_order(uuid,text) to authenticated;
commit;
