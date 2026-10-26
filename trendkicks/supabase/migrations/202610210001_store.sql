-- Additive migration: the original products/orders prototype tables are untouched.
-- All money is integer centavos. All sensitive mutations go through guarded RPCs.
begin;

create table public.tk_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
create function public.tk_is_admin() returns boolean language sql stable security definer
set search_path = '' as $$ select exists(select 1 from public.tk_admins where user_id = auth.uid()) $$;

create table public.tk_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  first_name text not null default '' check(length(first_name) <= 120),
  last_name text not null default '' check(length(last_name) <= 120),
  phone text not null default '' check(length(phone) <= 120),
  address text not null default '' check(length(address) <= 600),
  created_at timestamptz not null default now()
);
create function public.tk_handle_signup() returns trigger language plpgsql security definer
set search_path = '' as $$
begin
  insert into public.tk_profiles(id, first_name, last_name, phone, address) values (
    new.id, left(coalesce(new.raw_user_meta_data->>'first_name', ''),120),
    left(coalesce(new.raw_user_meta_data->>'last_name', ''),120),
    left(coalesce(new.raw_user_meta_data->>'phone',''),120), left(coalesce(new.raw_user_meta_data->>'address',''),600)
  ); return new;
end $$;
create trigger tk_signup after insert on auth.users for each row execute function public.tk_handle_signup();
insert into public.tk_profiles(id, first_name, last_name, phone, address)
select id, left(coalesce(raw_user_meta_data->>'first_name',''),120), left(coalesce(raw_user_meta_data->>'last_name',''),120),
left(coalesce(raw_user_meta_data->>'phone',''),120), left(coalesce(raw_user_meta_data->>'address',''),600) from auth.users on conflict do nothing;

create table public.tk_products (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(trim(name)) between 2 and 120),
  brand text not null check(length(trim(brand)) between 2 and 120),
  description text not null default '' check(length(description) <= 2000),
  price_cents integer not null check(price_cents between 1 and 100000000),
  images text[] not null default '{}',
  active boolean not null default true,
  rating numeric(3,2) not null default 0,
  review_count integer not null default 0,
  created_at timestamptz not null default now()
);
create table public.tk_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.tk_products(id),
  size text not null check(length(trim(size)) between 1 and 20),
  color text not null check(length(trim(color)) between 1 and 120),
  stock integer not null default 0 check(stock >= 0)
);
create unique index tk_unique_variant on public.tk_variants(product_id, lower(color), lower(size));
create index on public.tk_variants(product_id);
create table public.tk_cart (
  user_id uuid not null references auth.users(id) on delete cascade,
  variant_id uuid not null references public.tk_variants(id),
  quantity integer not null check(quantity between 1 and 99),
  created_at timestamptz not null default now(), primary key(user_id, variant_id)
);
create table public.tk_settings (
  id integer primary key check(id = 1), shipping_cents integer not null check(shipping_cents between 0 and 1000000)
);
insert into public.tk_settings values (1,12000);

create table public.tk_orders (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
  request_key uuid not null, items jsonb not null, delivery jsonb not null,
  subtotal_cents integer not null check(subtotal_cents > 0), shipping_cents integer not null check(shipping_cents >= 0),
  total_cents integer not null check(total_cents = subtotal_cents + shipping_cents),
  status text not null default 'PENDING' check(status in ('PENDING','CONFIRMED','PREPARING','SHIPPED','DELIVERED','CANCELLED')),
  payment_method text not null check(payment_method in ('COD','XENDIT')),
  payment_status text not null check(payment_status in ('DUE','PENDING','PAID','EXPIRED','REFUND_REQUIRED')),
  invoice_id text unique, invoice_url text, invoice_claimed_at timestamptz,
  inventory_released boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(user_id,request_key)
);
create index on public.tk_orders(user_id,created_at desc);
create table public.tk_reviews (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
  product_id uuid not null references public.tk_products(id), order_id uuid not null references public.tk_orders(id),
  item_id uuid not null unique, rating integer not null check(rating between 1 and 5),
  content text not null default '' check(length(content) <= 1500), author_name text not null,
  created_at timestamptz not null default now()
);
create index on public.tk_reviews(product_id,created_at desc);
create table public.tk_refunds (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
  order_id uuid not null references public.tk_orders(id), item_id uuid not null unique,
  product_name text not null, reason text not null,
  status text not null default 'PENDING_REVIEW' check(status in ('PENDING_REVIEW','APPROVED','REJECTED')),
  reviewed_by uuid references auth.users(id), created_at timestamptz not null default now(), reviewed_at timestamptz
);
create index on public.tk_refunds(user_id);
create index on public.tk_refunds(order_id);
create table public.tk_notifications (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  order_id uuid not null references public.tk_orders(id), title text not null, message text not null,
  read boolean not null default false, created_at timestamptz not null default now()
);
create index on public.tk_notifications(user_id,created_at desc);

alter table public.tk_admins enable row level security;
alter table public.tk_profiles enable row level security;
alter table public.tk_products enable row level security;
alter table public.tk_variants enable row level security;
alter table public.tk_cart enable row level security;
alter table public.tk_settings enable row level security;
alter table public.tk_orders enable row level security;
alter table public.tk_reviews enable row level security;
alter table public.tk_refunds enable row level security;
alter table public.tk_notifications enable row level security;

-- Public catalog data is safe to read, including archived products linked to carts.
create policy tk_products_read on public.tk_products for select to anon,authenticated using(true);
create policy tk_variants_read on public.tk_variants for select to anon,authenticated using(true);
create policy tk_settings_read on public.tk_settings for select to anon,authenticated using(true);
create policy tk_reviews_read on public.tk_reviews for select to anon,authenticated using(true);
create policy tk_profile_read on public.tk_profiles for select to authenticated using(id = (select auth.uid()) or (select public.tk_is_admin()));
create policy tk_profile_edit on public.tk_profiles for update to authenticated using(id = (select auth.uid())) with check(id = (select auth.uid()));
create policy tk_cart_read on public.tk_cart for select to authenticated using(user_id = (select auth.uid()));
create policy tk_orders_read on public.tk_orders for select to authenticated using(user_id = (select auth.uid()) or (select public.tk_is_admin()));
create policy tk_refunds_read on public.tk_refunds for select to authenticated using(user_id = (select auth.uid()) or (select public.tk_is_admin()));
create policy tk_notifications_read on public.tk_notifications for select to authenticated using(user_id = (select auth.uid()));

revoke all on public.tk_admins, public.tk_profiles, public.tk_products, public.tk_variants, public.tk_cart, public.tk_settings, public.tk_orders, public.tk_reviews, public.tk_refunds, public.tk_notifications from anon, authenticated;
grant select on public.tk_products,public.tk_variants,public.tk_settings to anon,authenticated;
grant select(id,product_id,rating,content,author_name,created_at) on public.tk_reviews to anon,authenticated;
grant select on public.tk_profiles,public.tk_cart,public.tk_orders,public.tk_refunds,public.tk_notifications to authenticated;
grant update(first_name,last_name,phone,address) on public.tk_profiles to authenticated;
grant all on public.tk_admins, public.tk_profiles, public.tk_products, public.tk_variants, public.tk_cart, public.tk_settings, public.tk_orders, public.tk_reviews, public.tk_refunds, public.tk_notifications to service_role;

create function public.tk_set_cart(p_variant uuid, p_quantity integer) returns void language plpgsql security definer set search_path = '' as $$
declare v public.tk_variants; p public.tk_products;
begin
  if auth.uid() is null then raise exception 'Sign in to use your saved bag.'; end if;
  if p_quantity is null or p_quantity < 0 or p_quantity > 99 then raise exception 'Choose a quantity between 0 and 99.'; end if;
  if p_quantity = 0 then delete from public.tk_cart where user_id=auth.uid() and variant_id=p_variant; return; end if;
  select * into v from public.tk_variants where id=p_variant;
  select * into p from public.tk_products where id=v.product_id;
  if v.id is null or not p.active or v.stock < p_quantity then raise exception 'This size is unavailable or does not have enough stock.'; end if;
  insert into public.tk_cart(user_id,variant_id,quantity) values(auth.uid(),p_variant,p_quantity)
  on conflict(user_id,variant_id) do update set quantity=excluded.quantity;
end $$;

create function public.tk_create_order(p_items jsonb, p_delivery jsonb, p_method text, p_request_key uuid, p_expected_total_cents integer default null) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  existing uuid; order_id uuid := gen_random_uuid(); entry jsonb; v public.tk_variants; p public.tk_products;
  qty integer; subtotal bigint := 0; shipping integer; snapshot jsonb := '[]'::jsonb; n integer;
begin
  if auth.uid() is null then raise exception 'Please sign in before checkout.'; end if;
  if p_request_key is null then raise exception 'A checkout request ID is required.'; end if;
  perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text || p_request_key::text,0));
  select id into existing from public.tk_orders where user_id=auth.uid() and request_key=p_request_key;
  if existing is not null then return existing; end if;
  if p_method is null or p_method not in ('COD','XENDIT') then raise exception 'Choose a supported payment method.'; end if;
  if jsonb_typeof(p_items) is distinct from 'array' then raise exception 'Your bag is invalid.'; end if;
  n := jsonb_array_length(p_items);
  if n < 1 or n > 50 then raise exception 'Choose between 1 and 50 different pairs.'; end if;
  if jsonb_typeof(p_delivery) is distinct from 'object' or length(trim(coalesce(p_delivery->>'name',''))) not between 2 and 120
    or length(trim(coalesce(p_delivery->>'phone',''))) not between 2 and 120
    or length(trim(coalesce(p_delivery->>'address',''))) not between 10 and 600 then raise exception 'Complete your name, phone, and delivery address.'; end if;
  if (select count(distinct x->>'variant_id') from jsonb_array_elements(p_items) x) <> n then raise exception 'Combine duplicate sizes in your bag.'; end if;
  -- A stable lock order prevents two multi-item checkouts deadlocking.
  for entry in select x from jsonb_array_elements(p_items) x order by x->>'variant_id' loop
    if (entry->>'quantity') !~ '^[0-9]{1,2}$' then raise exception 'Invalid quantity.'; end if;
    qty := (entry->>'quantity')::integer;
    if qty is null or qty < 1 or qty > 99 then raise exception 'Choose a quantity from 1 to 99.'; end if;
    select * into v from public.tk_variants where id=(entry->>'variant_id')::uuid for update;
    if v.id is null then raise exception 'One of your selected sizes is no longer available.'; end if;
    select * into p from public.tk_products where id=v.product_id for share;
    if not p.active or v.stock < qty then raise exception 'Not enough stock for % (US %, %).',p.name,v.size,v.color; end if;
    subtotal := subtotal + p.price_cents::bigint * qty;
    if subtotal > 2000000000 then raise exception 'This order exceeds the checkout limit. Please split your order.'; end if;
    snapshot := snapshot || jsonb_build_array(jsonb_build_object('item_id',gen_random_uuid(),'product_id',p.id,'variant_id',v.id,
      'name',p.name,'brand',p.brand,'image',coalesce(p.images[1],''),'size',v.size,'color',v.color,'quantity',qty,'unit_price_cents',p.price_cents));
    update public.tk_variants set stock=stock-qty where id=v.id;
    -- Remove only the purchased quantity, preserving the rest of the saved bag.
    delete from public.tk_cart where user_id=auth.uid() and variant_id=v.id and quantity <= qty;
    update public.tk_cart set quantity=quantity-qty where user_id=auth.uid() and variant_id=v.id;
  end loop;
  select shipping_cents into shipping from public.tk_settings where id=1;
  if shipping is null then raise exception 'Shipping is not configured. Please contact the store.'; end if;
  if p_expected_total_cents is not null and subtotal+shipping <> p_expected_total_cents then
    raise exception 'Prices or shipping changed. Refresh your bag and review the new total before checkout.';
  end if;
  insert into public.tk_orders(id,user_id,request_key,items,delivery,subtotal_cents,shipping_cents,total_cents,payment_method,payment_status)
  values(order_id,auth.uid(),p_request_key,snapshot,jsonb_build_object('name',trim(p_delivery->>'name'),'phone',trim(p_delivery->>'phone'),'address',trim(p_delivery->>'address')),subtotal,shipping,subtotal+shipping,p_method,case when p_method='COD' then 'DUE' else 'PENDING' end);
  insert into public.tk_notifications(user_id,order_id,title,message) values(auth.uid(),order_id,'Order placed','Your pairs are reserved. Follow your order for the next update.');
  return order_id;
end $$;

-- Internal function. Only invoked from guarded cancellation/payment functions.
create function public.tk_release_inventory(p_order uuid) returns void language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders; entry jsonb;
begin
  select * into o from public.tk_orders where id=p_order for update;
  if o.id is null or o.inventory_released then return; end if;
  for entry in select x from jsonb_array_elements(o.items) x order by x->>'variant_id' loop
    update public.tk_variants set stock=stock+(entry->>'quantity')::integer where id=(entry->>'variant_id')::uuid;
  end loop;
  update public.tk_orders set inventory_released=true where id=p_order;
end $$;

create function public.tk_cancel_order(p_order uuid) returns void language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders;
begin
  select * into o from public.tk_orders where id=p_order for update;
  if o.id is null or o.user_id is distinct from auth.uid() then raise exception 'Order not found.'; end if;
  if o.status='CANCELLED' then return; end if;
  if o.status not in ('PENDING','CONFIRMED','PREPARING') then raise exception 'Orders cannot be cancelled after shipping.'; end if;
  if o.invoice_claimed_at > now() - interval '90 seconds' and o.invoice_id is null then raise exception 'Payment is being prepared. Please try cancellation again shortly.'; end if;
  perform public.tk_release_inventory(o.id);
  update public.tk_orders set status='CANCELLED', updated_at=now(), payment_status=case when payment_status='PAID' then 'REFUND_REQUIRED' else payment_status end where id=o.id;
  insert into public.tk_notifications(user_id,order_id,title,message) values(o.user_id,o.id,'Order cancelled',case when o.payment_status='PAID' then 'Your order was cancelled. Contact the store to arrange the payment refund.' else 'Your order was cancelled and its reserved inventory was released.' end);
end $$;

create function public.tk_advance_order(p_order uuid, p_status text) returns void language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders; expected text;
begin
  if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
  select * into o from public.tk_orders where id=p_order for update;
  expected := case o.status when 'PENDING' then 'CONFIRMED' when 'CONFIRMED' then 'PREPARING' when 'PREPARING' then 'SHIPPED' when 'SHIPPED' then 'DELIVERED' end;
  if o.id is null or expected is null or p_status is distinct from expected then raise exception 'This order cannot move to that status.'; end if;
  if o.payment_method='XENDIT' and o.payment_status <> 'PAID' then raise exception 'Online orders must be paid before fulfillment.'; end if;
  update public.tk_orders set status=p_status,updated_at=now(),payment_status=case when payment_method='COD' and p_status='DELIVERED' then 'PAID' else payment_status end where id=o.id;
  insert into public.tk_notifications(user_id,order_id,title,message) values(o.user_id,o.id,'Order ' || lower(p_status),'Your order is now ' || lower(p_status) || '.');
end $$;

create function public.tk_read_notification(p_id uuid) returns void language plpgsql security definer set search_path = '' as $$
begin update public.tk_notifications set read=true where id=p_id and user_id=auth.uid(); end $$;

create function public.tk_my_review(p_order uuid,p_item uuid) returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('rating',rating,'content',content) from public.tk_reviews
  where user_id=auth.uid() and order_id=p_order and item_id=p_item;
$$;
revoke all on function public.tk_my_review(uuid,uuid) from public,anon;
grant execute on function public.tk_my_review(uuid,uuid) to authenticated;

create function public.tk_submit_review(p_order uuid,p_item uuid,p_rating integer,p_content text) returns void language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders; item jsonb; author text;
begin
  select * into o from public.tk_orders where id=p_order;
  if o.user_id is distinct from auth.uid() or auth.uid() is null or o.status <> 'DELIVERED' then raise exception 'Reviews are available for your delivered purchases.'; end if;
  select x into item from jsonb_array_elements(o.items) x where x->>'item_id'=p_item::text;
  if item is null then raise exception 'Order item not found.'; end if;
  if p_rating is null or p_rating not between 1 and 5 or length(coalesce(p_content,'')) > 1500 then raise exception 'Choose 1–5 stars and a review under 1500 characters.'; end if;
  select first_name into author from public.tk_profiles where id=auth.uid();
  insert into public.tk_reviews(user_id,product_id,order_id,item_id,rating,content,author_name)
  values(auth.uid(),(item->>'product_id')::uuid,o.id,p_item,p_rating,coalesce(p_content,''),coalesce(nullif(author,''),'Customer'))
  on conflict(item_id) do update set rating=excluded.rating, content=excluded.content where public.tk_reviews.user_id=auth.uid();
end $$;
create function public.tk_recalculate_rating() returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.tk_products where id=new.product_id for update;
  update public.tk_products set rating=(select round(avg(rating),2) from public.tk_reviews where product_id=new.product_id),
  review_count=(select count(*) from public.tk_reviews where product_id=new.product_id) where id=new.product_id;
  return new;
end $$;
create trigger tk_review_rating after insert or update on public.tk_reviews for each row execute function public.tk_recalculate_rating();

create function public.tk_request_refund(p_order uuid,p_item uuid,p_reason text) returns void language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders; item jsonb;
begin
  select * into o from public.tk_orders where id=p_order;
  if auth.uid() is null or o.user_id is distinct from auth.uid() or o.status <> 'DELIVERED' then raise exception 'Refund requests are available for your delivered order items.'; end if;
  select x into item from jsonb_array_elements(o.items) x where x->>'item_id'=p_item::text;
  if item is null then raise exception 'Order item not found.'; end if;
  if p_reason is null or p_reason not in ('Product arrived damaged','Wrong product received','Wrong size received','Product does not match the order','Defective product','Other eligible reason') then raise exception 'Choose one of the available refund reasons.'; end if;
  insert into public.tk_refunds(user_id,order_id,item_id,product_name,reason) values(auth.uid(),o.id,p_item,item->>'name',p_reason) on conflict(item_id) do nothing;
end $$;

create function public.tk_decide_refund(p_refund uuid,p_approved boolean) returns void language plpgsql security definer set search_path = '' as $$
declare r public.tk_refunds;
begin
  if not public.tk_is_admin() or p_approved is null then raise exception 'Administrator access required.'; end if;
  select * into r from public.tk_refunds where id=p_refund for update;
  if r.id is null or r.status <> 'PENDING_REVIEW' then raise exception 'This refund request has already been reviewed.'; end if;
  update public.tk_refunds set status=case when p_approved then 'APPROVED' else 'REJECTED' end,reviewed_by=auth.uid(),reviewed_at=now() where id=r.id;
  insert into public.tk_notifications(user_id,order_id,title,message) values(r.user_id,r.order_id,case when p_approved then 'Refund approved' else 'Refund rejected' end,
  case when p_approved then 'Your refund request was approved for processing. The store will arrange the return of funds separately.' else 'Your refund request was reviewed and rejected. Contact the store if you have questions.' end);
end $$;

create function public.tk_archive_product(p_id uuid) returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
  update public.tk_products set active=false where id=p_id;
end $$;

create function public.tk_save_product(p_product jsonb,p_variants jsonb) returns uuid language plpgsql security definer set search_path = '' as $$
declare pid uuid; entry jsonb; vid uuid; image text;
begin
  if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
  if jsonb_typeof(p_variants) is distinct from 'array' or jsonb_array_length(p_variants) not between 1 and 200 then raise exception 'Add between 1 and 200 variants.'; end if;
  if jsonb_typeof(p_product->'images') is distinct from 'array' or jsonb_array_length(p_product->'images') not between 1 and 8 then raise exception 'Add 1–8 product images.'; end if;
  for image in select jsonb_array_elements_text(p_product->'images') loop
    if image !~ '^https://' and image !~ '^asset:assets/images/[a-z0-9-]+\.jpg$' then raise exception 'Use uploaded HTTPS images or bundled catalog assets.'; end if;
  end loop;
  pid := coalesce((p_product->>'id')::uuid,gen_random_uuid());
  -- Lock variants before the product, matching checkout's lock order.
  perform 1 from public.tk_variants where product_id=pid order by id for update;
  insert into public.tk_products(id,name,brand,description,price_cents,images,active)
  values(pid,trim(p_product->>'name'),trim(p_product->>'brand'),coalesce(p_product->>'description',''),(p_product->>'price_cents')::integer,
    array(select jsonb_array_elements_text(p_product->'images')),coalesce((p_product->>'active')::boolean,true))
  on conflict(id) do update set name=excluded.name,brand=excluded.brand,description=excluded.description,price_cents=excluded.price_cents,images=excluded.images,active=excluded.active;
  for entry in select x from jsonb_array_elements(p_variants) x loop
    if (entry->>'stock') is null or (entry->>'stock') !~ '^[0-9]{1,6}$' or (entry->>'stock')::integer > 100000 then
      raise exception 'Variant stock must be between 0 and 100000.';
    end if;
    vid := (entry->>'id')::uuid;
    if vid is not null and not exists(select 1 from public.tk_variants where id=vid and product_id=pid) then raise exception 'A variant belongs to a different product.'; end if;
    insert into public.tk_variants(id,product_id,size,color,stock) values(coalesce(vid,gen_random_uuid()),pid,trim(entry->>'size'),trim(entry->>'color'),(entry->>'stock')::integer)
    on conflict(id) do update set size=excluded.size,color=excluded.color,stock=excluded.stock;
  end loop;
  return pid;
end $$;

-- Invoice jobs are leased to prevent concurrent retries creating multiple links.
create function public.tk_claim_invoice(p_order uuid) returns boolean language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders;
begin
  select * into o from public.tk_orders where id=p_order for update;
  if o.id is null or o.payment_method <> 'XENDIT' or o.payment_status <> 'PENDING' or o.status='CANCELLED' then return false; end if;
  if o.invoice_id is not null then return false; end if;
  if o.invoice_claimed_at > now() - interval '90 seconds' then return false; end if;
  update public.tk_orders set invoice_claimed_at=now() where id=o.id;
  return true;
end $$;

create function public.tk_attach_invoice(p_order uuid,p_invoice text,p_url text) returns void language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders;
begin
  select * into o from public.tk_orders where id=p_order for update;
  if o.id is null or o.payment_method <> 'XENDIT' then raise exception 'Order not found.'; end if;
  if o.invoice_id is not null and o.invoice_id <> p_invoice then raise exception 'An invoice is already attached to this order.'; end if;
  if p_url !~ '^https://([a-z0-9-]+\.)*xendit\.co/' then raise exception 'Invalid payment link.'; end if;
  update public.tk_orders set invoice_id=p_invoice,invoice_url=p_url,invoice_claimed_at=null,updated_at=now() where id=o.id;
end $$;

-- Invoked only after server-to-server invoice verification, never directly by a customer.
create function public.tk_apply_payment(p_order uuid,p_invoice text,p_status text,p_amount_cents bigint,p_currency text) returns void language plpgsql security definer set search_path = '' as $$
declare o public.tk_orders;
begin
  select * into o from public.tk_orders where id=p_order for update;
  if o.id is null or o.payment_method <> 'XENDIT' or p_invoice is null or p_currency is distinct from 'PHP' or p_amount_cents is distinct from o.total_cents::bigint then raise exception 'Invoice does not match this order.'; end if;
  if o.invoice_id is not null and o.invoice_id <> p_invoice then raise exception 'Invoice ID mismatch.'; end if;
  if p_status in ('PAID','SETTLED') then
    if o.payment_status in ('PAID','REFUND_REQUIRED') then return; end if;
    update public.tk_orders set invoice_id=p_invoice,updated_at=now(),payment_status=case when status='CANCELLED' then 'REFUND_REQUIRED' else 'PAID' end,
    status=case when status='PENDING' then 'CONFIRMED' else status end where id=o.id;
    insert into public.tk_notifications(user_id,order_id,title,message) values(o.user_id,o.id,'Payment received',case when o.status='CANCELLED' then 'Payment arrived for a cancelled order. Contact the store to arrange a refund.' else 'Your payment has been verified and your order is confirmed.' end);
  elsif p_status='EXPIRED' and o.payment_status='PENDING' then
    perform public.tk_release_inventory(o.id);
    update public.tk_orders set invoice_id=p_invoice,status='CANCELLED',payment_status='EXPIRED',updated_at=now() where id=o.id;
    insert into public.tk_notifications(user_id,order_id,title,message) values(o.user_id,o.id,'Payment link expired','This order was cancelled and its reserved inventory was released.');
  end if;
end $$;

-- Default EXECUTE on new functions is public in PostgreSQL: explicitly remove it.
revoke all on function public.tk_handle_signup(),public.tk_recalculate_rating(),public.tk_release_inventory(uuid),public.tk_claim_invoice(uuid),public.tk_attach_invoice(uuid,text,text),public.tk_apply_payment(uuid,text,text,bigint,text) from public,anon,authenticated;
revoke all on function public.tk_is_admin(),public.tk_set_cart(uuid,integer),public.tk_create_order(jsonb,jsonb,text,uuid,integer),public.tk_cancel_order(uuid),public.tk_advance_order(uuid,text),public.tk_read_notification(uuid),public.tk_submit_review(uuid,uuid,integer,text),public.tk_request_refund(uuid,uuid,text),public.tk_decide_refund(uuid,boolean),public.tk_archive_product(uuid),public.tk_save_product(jsonb,jsonb) from public,anon;
grant execute on function public.tk_is_admin(),public.tk_set_cart(uuid,integer),public.tk_create_order(jsonb,jsonb,text,uuid,integer),public.tk_cancel_order(uuid),public.tk_advance_order(uuid,text),public.tk_read_notification(uuid),public.tk_submit_review(uuid,uuid,integer,text),public.tk_request_refund(uuid,uuid,text),public.tk_decide_refund(uuid,boolean),public.tk_archive_product(uuid),public.tk_save_product(jsonb,jsonb) to authenticated;
grant execute on function public.tk_claim_invoice(uuid),public.tk_attach_invoice(uuid,text,text),public.tk_apply_payment(uuid,text,text,bigint,text) to service_role;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('product-images','product-images',true,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy tk_image_read on storage.objects for select to anon,authenticated using(bucket_id='product-images');
create policy tk_image_upload on storage.objects for insert to authenticated with check(bucket_id='product-images' and (select public.tk_is_admin()) and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy tk_image_delete on storage.objects for delete to authenticated using(bucket_id='product-images' and (select public.tk_is_admin()));

commit;
