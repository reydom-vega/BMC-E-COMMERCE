-- Apply once after the three original store migrations.
begin;
alter table public.tk_products
  add column category text not null default 'Lifestyle'
    check (category in ('Lifestyle','Running','Training','Basketball','Skate','Walking','Other')),
  add column fit_notes text not null default '' check (char_length(fit_notes) <= 600);

create table public.tk_wishlist (
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.tk_products(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key(user_id, product_id)
);
alter table public.tk_wishlist enable row level security;
create policy tk_wishlist_read on public.tk_wishlist for select to authenticated
  using (user_id = (select auth.uid()));
create policy tk_wishlist_insert on public.tk_wishlist for insert to authenticated
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.tk_products p where p.id = product_id and p.active
  ));
create policy tk_wishlist_delete on public.tk_wishlist for delete to authenticated
  using (user_id = (select auth.uid()));
revoke all on public.tk_wishlist from public, anon, authenticated;
grant select, insert, delete on public.tk_wishlist to authenticated;
grant all on public.tk_wishlist to service_role;

-- Preserve the existing admin guards and variant-before-product lock order.
create or replace function public.tk_save_product(p_product jsonb,p_variants jsonb) returns uuid language plpgsql security definer set search_path = '' as $$
declare pid uuid; entry jsonb; vid uuid; image text;
begin
  if not public.tk_is_admin() then raise exception 'Administrator access required.'; end if;
  if jsonb_typeof(p_variants) is distinct from 'array' or jsonb_array_length(p_variants) not between 1 and 200 then raise exception 'Add between 1 and 200 variants.'; end if;
  if jsonb_typeof(p_product->'images') is distinct from 'array' or jsonb_array_length(p_product->'images') not between 1 and 8 then raise exception 'Add 1–8 product images.'; end if;
  for image in select jsonb_array_elements_text(p_product->'images') loop
    if image !~ '^https://' and image !~ '^asset:assets/images/[a-z0-9-]+\.jpg$' then raise exception 'Use uploaded HTTPS images or bundled catalog assets.'; end if;
  end loop;
  pid := coalesce((p_product->>'id')::uuid,gen_random_uuid());
  perform 1 from public.tk_variants where product_id=pid order by id for update;
  insert into public.tk_products(id,name,brand,description,price_cents,images,active,category,fit_notes)
  values(pid,trim(p_product->>'name'),trim(p_product->>'brand'),coalesce(p_product->>'description',''),(p_product->>'price_cents')::integer,
    array(select jsonb_array_elements_text(p_product->'images')),coalesce((p_product->>'active')::boolean,true),
    coalesce(p_product->>'category',(select category from public.tk_products where id=pid),'Lifestyle'),
    coalesce(p_product->>'fit_notes',(select fit_notes from public.tk_products where id=pid),''))
  on conflict(id) do update set name=excluded.name,brand=excluded.brand,description=excluded.description,price_cents=excluded.price_cents,images=excluded.images,active=excluded.active,category=excluded.category,fit_notes=excluded.fit_notes;
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
revoke all on function public.tk_save_product(jsonb,jsonb) from public,anon;
grant execute on function public.tk_save_product(jsonb,jsonb) to authenticated;
commit;
