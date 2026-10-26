-- Schedule this function every five minutes (see README). Online reservations with
-- attached invoices are released by verified EXPIRED callbacks, never a local timer.
create function public.tk_expire_abandoned() returns integer language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders; n integer := 0;
begin
  for o in select * from public.tk_orders where payment_method='XENDIT' and payment_status='PENDING'
    and status='PENDING' and invoice_id is null and created_at < now()-interval '2 hours'
    and (invoice_claimed_at is null or invoice_claimed_at < now()-interval '5 minutes') for update skip locked loop
    perform public.tk_release_inventory(o.id);
    update public.tk_orders set status='CANCELLED',payment_status='EXPIRED',updated_at=now() where id=o.id;
    insert into public.tk_notifications(user_id,order_id,title,message) values(o.user_id,o.id,'Checkout expired','Your unfinished checkout expired and the reserved inventory was released.');
    n := n+1;
  end loop;
  return n;
end $$;
revoke all on function public.tk_expire_abandoned() from public,anon,authenticated;
grant execute on function public.tk_expire_abandoned() to service_role;
