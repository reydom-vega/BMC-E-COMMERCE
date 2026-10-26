begin;
create or replace function public.tk_my_review(p_order uuid,p_item uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',id,'rating',rating,'content',content) from public.tk_reviews where user_id=auth.uid() and order_id=p_order and item_id=p_item;
$$;
create table public.tk_review_images(id uuid primary key default gen_random_uuid(),review_id uuid not null references public.tk_reviews(id),
 user_id uuid not null references auth.users(id),path text not null unique,
 status text not null default 'PENDING' check(status in ('PENDING','VISIBLE','REMOVED')),
 mime text not null check(mime in ('image/jpeg','image/png','image/webp')),bytes integer not null check(bytes between 1 and 5242880),
 width integer not null check(width between 100 and 6000),height integer not null check(height between 100 and 6000),created_at timestamptz not null default now());
create index on public.tk_review_images(review_id,status);
create table public.tk_review_image_reports(id uuid primary key default gen_random_uuid(),image_id uuid not null references public.tk_review_images(id),
 user_id uuid not null references auth.users(id),reason text not null check(length(trim(reason)) between 3 and 500),created_at timestamptz not null default now(),unique(image_id,user_id));
alter table public.tk_review_images enable row level security;
alter table public.tk_review_image_reports enable row level security;
revoke all on public.tk_review_images,public.tk_review_image_reports from anon,authenticated;
grant all on public.tk_review_images,public.tk_review_image_reports to service_role;
grant select on public.tk_review_images to anon,authenticated;
grant select on public.tk_review_image_reports to authenticated;
create policy tk_review_media_guest on public.tk_review_images for select to anon using(status='VISIBLE');
create policy tk_review_media_read on public.tk_review_images for select to authenticated using(status='VISIBLE' or user_id=auth.uid() or public.tk_is_admin());
create policy tk_review_report_read on public.tk_review_image_reports for select to authenticated using(user_id=auth.uid() or public.tk_is_admin());
create function public.tk_reserve_review_image(p_review uuid,p_user uuid,p_mime text,p_bytes integer,p_width integer,p_height integer) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.tk_reviews;result public.tk_review_images;new_id uuid:=gen_random_uuid();
begin
 select * into r from public.tk_reviews where id=p_review and user_id=p_user for update;
 if r.id is null or not exists(select 1 from public.tk_orders where id=r.order_id and status='DELIVERED' and user_id=p_user) then raise exception 'Only your delivered purchase reviews can have photos.'; end if;
 if (select count(*) from public.tk_review_images where review_id=r.id and status in ('PENDING','VISIBLE'))>=3 then raise exception 'Use up to three photos per review.'; end if;
 insert into public.tk_review_images(id,review_id,user_id,path,mime,bytes,width,height) values(new_id,r.id,p_user,r.id::text||'/'||new_id::text,p_mime,p_bytes,p_width,p_height) returning * into result;
 return to_jsonb(result);
end $$;
create function public.tk_remove_review_image(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 update public.tk_review_images set status='REMOVED' where id=p_id and (user_id=auth.uid() or public.tk_is_admin());
 if not found then raise exception 'Photo not found.'; end if;
end $$;
create function public.tk_report_review_image(p_id uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null then raise exception 'Please sign in.'; end if;
 if not exists(select 1 from public.tk_review_images where id=p_id and status='VISIBLE') then raise exception 'Photo unavailable.'; end if;
 insert into public.tk_review_image_reports(image_id,user_id,reason) values(p_id,auth.uid(),p_reason) on conflict do nothing;
end $$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('review-images','review-images',false,5242880,array['image/jpeg','image/png','image/webp']) on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
-- No direct customer upload/update policy: the authenticated Edge Function validates real bytes/dimensions.
create policy tk_review_storage_read on storage.objects for select to anon,authenticated using(bucket_id='review-images' and exists(select 1 from public.tk_review_images where path=name and status='VISIBLE'));
revoke all on function public.tk_reserve_review_image(uuid,uuid,text,integer,integer,integer),public.tk_remove_review_image(uuid),public.tk_report_review_image(uuid,text) from public,anon,authenticated;
grant execute on function public.tk_reserve_review_image(uuid,uuid,text,integer,integer,integer) to service_role;
grant execute on function public.tk_remove_review_image(uuid),public.tk_report_review_image(uuid,text) to authenticated;
commit;
