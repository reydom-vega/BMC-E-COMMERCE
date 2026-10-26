begin;

-- Register the authenticated device and persist its preference atomically.
create or replace function public.tk_set_push_enabled(p_enabled boolean,p_token text default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if p_enabled is null then raise exception 'Choose a notification preference.'; end if;
 if p_enabled and (p_token is null or length(p_token) not between 20 and 4096) then
  raise exception 'A registered Android push token is required.';
 end if;
 if p_enabled then perform public.tk_register_device(p_token,true);
 else update public.tk_device_tokens set active=false where user_id=auth.uid(); end if;
 insert into public.tk_notification_preferences(user_id,push_enabled) values(auth.uid(),p_enabled)
 on conflict(user_id) do update set push_enabled=excluded.push_enabled;
end $$;
revoke all on function public.tk_set_push_enabled(boolean,text) from public,anon;
grant execute on function public.tk_set_push_enabled(boolean,text) to authenticated;

-- Legacy delivered COD orders already marked PAID by admin fulfillment have
-- collection evidence. Retain the recorded update time as their legacy date.
-- No unpaid COD or unverified Xendit invoice is declared paid.
update public.tk_orders set paid_at=coalesce(paid_at,updated_at),
 payment_reference=coalesce(payment_reference,'COD-'||id)
where payment_method='COD' and status='DELIVERED' and payment_status='PAID'
 and (paid_at is null or payment_reference is null);
insert into public.tk_receipts(order_id,snapshot)
select id,to_jsonb(o) from public.tk_orders o
where payment_method='COD' and status='DELIVERED' and payment_status='PAID'
 and paid_at is not null
on conflict(order_id) do nothing;

commit;
