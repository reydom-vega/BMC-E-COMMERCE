import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';

const db = globalThis.tkTestDatabase ?? new PGlite();
// Supabase-owned schemas are stubbed only in the disposable test database.
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth; create schema storage;
  create table auth.users(id uuid primary key, raw_user_meta_data jsonb default '{}');
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
  create function auth.role() returns text language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.role',true),'') $$;
  create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
  create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text);
  alter table storage.objects enable row level security;
  create function storage.foldername(text) returns text[] language sql immutable as $$ select string_to_array($1,'/') $$;
  grant usage on schema public,auth,storage to anon,authenticated,service_role;
  grant execute on function auth.uid(),auth.role() to anon,authenticated,service_role;
  grant select,insert,delete on storage.objects to anon,authenticated,service_role;
`);
for (const file of ['202610210001_store.sql', '202610210002_catalog.sql', '202610210003_reservation_cleanup.sql', '202610230001_shopping_features.sql', '202610240001_financial_foundation.sql', '202610240002_customer_operations.sql', '202610240003_review_media.sql', '202610240004_admin_reporting.sql', '202610240005_operational_hardening.sql', '202610250001_checkout_documents_push.sql']) {
  await db.exec(await readFile(new URL(`../supabase/migrations/${file}`, import.meta.url), 'utf8'));
}
console.log('PASS all migrations execute against PostgreSQL');
const alice = 'a0000000-0000-0000-0000-000000000001';
const bob = 'b0000000-0000-0000-0000-000000000001';
const admin = 'c0000000-0000-0000-0000-000000000001';
await db.query(`insert into auth.users(id,raw_user_meta_data) values ($1,'{"first_name":"Alice"}'),($2,'{"first_name":"Bob"}'),($3,'{"first_name":"Admin"}')`, [alice,bob,admin]);
await db.query('insert into tk_admins values($1)', [admin]);
const asUser = async (id, fn, role = 'authenticated') => {
  await db.exec(`set role ${role}`);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)", [id ?? '']);
  await db.query("select set_config('request.jwt.claim.role',$1,false)", [role]);
  try { return await fn(); } finally { await db.exec('reset role'); }
};
const value = async (sql, args=[]) => Object.values((await db.query(sql,args)).rows[0])[0];
const rejected = async (fn, message) => {
  let failure;
  try { await fn(); } catch (e) { failure=e; }
  assert.ok(failure, message);
};
const variant = '20000000-0000-0000-0000-000000000106';
const delivery = {name:'Alice Test',phone:'09123456789',address:'123 Example Street, Manila'};
const key1 = 'd0000000-0000-0000-0000-000000000001';
const create = (key, quantity=1, method='COD', id=variant) => value('select tk_create_order($1::jsonb,$2::jsonb,$3,$4::uuid)', [JSON.stringify([{variant_id:id,quantity}]),JSON.stringify(delivery),method,key]);

await asUser(null, async () => {
  assert.equal(await value('select count(*)::int from tk_products'),8);
  await rejected(() => db.query('select * from tk_orders'), 'Guest must not read orders');
  await rejected(() => create(key1), 'Guest must not check out');
}, 'anon');
console.log('PASS public catalog and guest restrictions');

await asUser(alice, async () => {
  await db.query('select tk_set_cart($1,3)',[variant]);
  assert.equal(await value('select quantity from tk_cart'),3);
  await rejected(() => db.query('select tk_set_cart($1,99)',[variant]), 'Reject cart above stock');
  await rejected(() => db.query("insert into tk_admins values(auth.uid())"), 'Reject role escalation');
  await rejected(() => db.query("update tk_products set price_cents=1"), 'Reject client price changes');
});
await asUser(bob, async () => {
  assert.equal(await value('select count(*)::int from tk_cart'),0);
  assert.equal(await value('select count(*)::int from tk_profiles'),1);
  await db.query('select tk_set_cart($1,1)',[variant]);
});
console.log('PASS cart persistence, ownership, stock and privilege checks');

let orderId;
await asUser(alice, async () => {
  orderId = await create(key1,2);
  assert.equal(await create(key1,2),orderId);
  assert.equal(await value('select count(*)::int from tk_orders'),1);
  assert.equal(await value('select stock from tk_variants where id=$1',[variant]),6);
  assert.equal(await value('select quantity from tk_cart where variant_id=$1',[variant]),1);
  assert.equal(await value('select total_cents from tk_orders where id=$1',[orderId]),549500*2+12000);
  await rejected(() => create('d0000000-0000-0000-0000-000000000002',7), 'Reject overselling');
  assert.equal(await value('select stock from tk_variants where id=$1',[variant]),6);
});
await asUser(bob, async () => {
  assert.equal(await value('select count(*)::int from tk_orders'),0);
  await rejected(() => db.query('select tk_cancel_order($1)',[orderId]), 'Cannot cancel another customer order');
  await rejected(() => db.query("select tk_advance_order($1,'CONFIRMED')",[orderId]), 'Only admin can advance');
});
console.log('PASS authoritative totals, shipping, idempotency, atomic stock and order privacy');

await asUser(alice, async () => {
  await rejected(() => value('select tk_create_order($1::jsonb,$2::jsonb,$3,$4::uuid,$5)', [JSON.stringify([{variant_id:variant,quantity:1}]),JSON.stringify(delivery),'COD','d0000000-0000-0000-0000-000000000099',1]), 'Changed displayed total requires confirmation');
  assert.equal(await value('select stock from tk_variants where id=$1',[variant]),6);
});
console.log('PASS changed checkout total rejects and rolls back the reservation');

await asUser(alice, async () => {
  const entries = [{variant_id:variant,quantity:1},{variant_id:'20000000-0000-0000-0000-000000000212',quantity:1}];
  await rejected(() => value('select tk_create_order($1::jsonb,$2::jsonb,$3,$4::uuid)',[JSON.stringify(entries),JSON.stringify(delivery),'COD','d0000000-0000-0000-0000-000000000098']), 'An unavailable second item rolls back the first reservation');
  assert.equal(await value('select stock from tk_variants where id=$1',[variant]),6);
  assert.equal(await value('select quantity from tk_cart where variant_id=$1',[variant]),1);
  await rejected(() => db.query('select tk_release_inventory($1)',[orderId]),'Inventory release is internal only');
});
console.log('PASS multi-item failure rolls back stock and cart mutations');

await asUser(alice, async () => {
  await db.query('select tk_cancel_order($1)',[orderId]);
  await db.query('select tk_cancel_order($1)',[orderId]);
  assert.equal(await value('select stock from tk_variants where id=$1',[variant]),8);
});
console.log('PASS cancellation returns inventory exactly once');

let delivered, item, reviewId;
await asUser(alice, async () => {
  delivered = await create('d0000000-0000-0000-0000-000000000003');
  item = await value("select items->0->>'item_id' from tk_orders where id=$1",[delivered]);
  await rejected(() => db.query("select tk_submit_review($1,$2,5,'Good')",[delivered,item]), 'Reviews require delivery');
});
await asUser(admin, async () => {
  for (const status of ['CONFIRMED','PREPARING','SHIPPED','DELIVERED']) {
    await db.query('select tk_advance_order($1,$2)',[delivered,status]);
    if (status==='SHIPPED') await asUser(alice, async () => {
      await rejected(() => db.query('select tk_cancel_order($1)',[delivered]), 'Cannot cancel after shipping');
    });
    // Nested identity changes reset the role; restore admin explicitly.
    await db.exec('set role authenticated');
    await db.query("select set_config('request.jwt.claim.sub',$1,false)",[admin]);
  }
});
await asUser(alice, async () => {
  await db.query("select tk_submit_review($1,$2,5,'Great pair')",[delivered,item]);
  await db.query("select tk_submit_review($1,$2,4,'Updated review')",[delivered,item]);
  const ownReview = await value('select tk_my_review($1,$2)',[delivered,item]);
  reviewId = ownReview.id;
  assert.equal(ownReview.content, 'Updated review');
  await assert.rejects(() => db.query('select id,user_id from tk_reviews where id=$1',[reviewId]), e => e.code==='42501');
  await assert.rejects(() => db.query('select id from tk_reviews where id=$1 and user_id=$2',[reviewId,alice]), e => e.code==='42501');
  assert.equal(await value("select review_count from tk_products where id='10000000-0000-0000-0000-000000000001'"),1);
  assert.equal(Number(await value("select rating from tk_products where id='10000000-0000-0000-0000-000000000001'")),4);
  await rejected(() => db.query("select tk_submit_review($1,$2,6,'Invalid')",[delivered,item]), 'Stars must be 1–5');
  await db.query("select tk_request_refund($1,$2,'Wrong size received')",[delivered,item]);
  const refund = await value('select id from tk_refunds');
  await rejected(() => db.query('select tk_decide_refund($1,true)',[refund]), 'Customer cannot approve refunds');
});
await asUser(bob, async () => {
  await rejected(() => db.query("select tk_submit_review($1,$2,1,'Tampered')",[delivered,item]), 'Cannot review another account purchase');
  assert.equal(await value('select tk_my_review($1,$2)',[delivered,item]), null);
  assert.equal(await value("select content from tk_reviews where product_id='10000000-0000-0000-0000-000000000001'"), 'Updated review');
  assert.equal(await value('select count(*)::int from tk_refunds'),0);
});
await asUser(null, async () => {
  assert.equal(await value("select count(id)::int from tk_reviews where product_id='10000000-0000-0000-0000-000000000001'"),1);
  assert.equal(await value("select content from tk_reviews where product_id='10000000-0000-0000-0000-000000000001'"), 'Updated review');
  assert.equal(Number(await value("select rating from tk_products where id='10000000-0000-0000-0000-000000000001'")),4);
}, 'anon');
await asUser(null, async () => {
  assert.equal(await value('select id from tk_reviews where id=$1 and user_id=$2',[reviewId,alice]),reviewId);
  assert.equal((await db.query('select id from tk_reviews where id=$1 and user_id=$2',[reviewId,bob])).rows.length,0);
}, 'service_role');
await asUser(admin, async () => {
  const refund = await value('select id from tk_refunds');
  await db.query('select tk_decide_refund($1,true)',[refund]);
});
await asUser(alice, async () => {
  assert.equal(await value('select status from tk_refunds'),'APPROVED');
  assert.ok(await value('select count(*)::int from tk_notifications') >= 5);
  const notice = await value('select id from tk_notifications limit 1');
  await db.query('select tk_read_notification($1)',[notice]);
  assert.equal(await value('select read from tk_notifications where id=$1',[notice]),true);
});
console.log('PASS fulfillment transitions, delivered reviews, aggregate ratings, item refunds and notifications');

let online;
await asUser(alice, async () => {
  online = await create('d0000000-0000-0000-0000-000000000004',1,'XENDIT');
  await rejected(() => db.query("select tk_apply_payment($1,'inv-1','PAID',561500,'PHP')",[online]), 'Client must not mark payment paid');
  await rejected(() => db.query("update tk_orders set payment_status='PAID' where id=$1",[online]), 'No direct payment updates');
});
await asUser(admin, async () => {
  await rejected(() => db.query("select tk_advance_order($1,'CONFIRMED')",[online]), 'Unpaid online orders cannot fulfill');
});
await asUser(null, async () => {
  assert.equal(await value('select tk_claim_invoice($1)',[online]),true);
  assert.equal(await value('select tk_claim_invoice($1)',[online]),false);
  await db.query("select tk_attach_invoice($1,'inv-1','https://checkout.xendit.co/inv-1')",[online]);
  await rejected(() => db.query("select tk_apply_payment($1,'inv-1','PAID',1,'PHP')",[online]),'Reject wrong invoice amount');
  await db.query("select tk_apply_payment($1,'inv-1','PAID',561500,'PHP')",[online]);
  await db.query("select tk_apply_payment($1,'inv-1','PAID',561500,'PHP')",[online]);
  await db.query("select tk_apply_payment($1,'inv-1','EXPIRED',561500,'PHP')",[online]);
  assert.equal(await value('select payment_status from tk_orders where id=$1',[online]),'PAID');
  assert.equal(await value("select count(*)::int from tk_notifications where order_id=$1 and title='Payment received'",[online]),1);
}, 'service_role');
await asUser(alice, async () => { await db.query('select tk_cancel_order($1)',[online]); });
await asUser(null, async () => { assert.equal(await value('select payment_status from tk_orders where id=$1',[online]),'REFUND_REQUIRED'); }, 'service_role');
console.log('PASS payment privileges, invoice leases, duplicate/out-of-order callbacks and paid cancellations');
// Mimic a historical paid Xendit row: no invented timestamp or receipt on migration.
const legacyPaid='f0000000-0000-0000-0000-000000000001';
await db.query("insert into tk_orders(id,user_id,request_key,items,delivery,subtotal_cents,shipping_cents,total_cents,status,payment_method,payment_status,invoice_id) values($1,$2,gen_random_uuid(),'[]',$3::jsonb,10000,0,10000,'CONFIRMED','XENDIT','PAID','legacy-paid-invoice')",[legacyPaid,alice,JSON.stringify(delivery)]);
assert.equal(await value('select count(*)::int from tk_receipts where order_id=$1',[legacyPaid]),0);
await asUser(null,async()=>{
 await db.query("select tk_record_payment($1,'legacy-paid-invoice','PAID',10000,'PHP')",[legacyPaid]);
 await db.query("select tk_record_payment($1,'legacy-paid-invoice','SETTLED',10000,'PHP')",[legacyPaid]);
},'service_role');
assert.equal(await value('select count(*)::int from tk_receipts where order_id=$1',[legacyPaid]),1);
assert.equal(await value('select count(*)::int from tk_payment_events where order_id=$1',[legacyPaid]),1);
console.log('PASS trusted historical payment reconciliation, one receipt and normalized event deduplication');

let expired;
await asUser(alice, async () => { expired=await create('d0000000-0000-0000-0000-000000000005',1,'XENDIT'); });
await db.query("update tk_orders set created_at=now()-interval '3 hours' where id=$1",[expired]);
await asUser(null, async () => {
  assert.equal(await value('select tk_expire_abandoned()'),1);
  assert.equal(await value('select tk_expire_abandoned()'),0);
  assert.equal(await value('select status from tk_orders where id=$1',[expired]),'CANCELLED');
}, 'service_role');
console.log('PASS abandoned reservation cleanup is repeatable');

let late;
await asUser(alice, async () => { late=await create('d0000000-0000-0000-0000-000000000006',1,'XENDIT'); });
const reservedStock = await value('select stock from tk_variants where id=$1',[variant]);
await asUser(null, async () => {
  await db.query("select tk_attach_invoice($1,'inv-2','https://checkout.xendit.co/inv-2')",[late]);
  await db.query("select tk_apply_payment($1,'inv-2','EXPIRED',561500,'PHP')",[late]);
  await db.query("select tk_apply_payment($1,'inv-2','EXPIRED',561500,'PHP')",[late]);
  assert.equal(await value('select stock from tk_variants where id=$1',[variant]),reservedStock+1);
  await db.query("select tk_apply_payment($1,'inv-2','PAID',561500,'PHP')",[late]);
  assert.equal(await value('select payment_status from tk_orders where id=$1',[late]),'REFUND_REQUIRED');
  assert.equal(await value('select stock from tk_variants where id=$1',[variant]),reservedStock+1);
},'service_role');
await asUser(bob, async () => { assert.equal(await value('select count(*)::int from tk_notifications'),0); });
console.log('PASS expiration releases stock once and late payment requires refund');

await asUser(admin, async () => {
  const product = {name:'Test shoe',brand:'Trend Kicks',description:'Database-tested product',price_cents:123400,images:['https://example.com/shoe.jpg'],active:true};
  const pid = await value('select tk_save_product($1::jsonb,$2::jsonb)',[JSON.stringify(product),JSON.stringify([{size:'8',color:'Black',stock:4}])]);
  assert.equal(await value('select stock from tk_variants where product_id=$1',[pid]),4);
  await rejected(() => value('select tk_save_product($1::jsonb,$2::jsonb)',[JSON.stringify({...product,id:pid}),JSON.stringify([{id:variant,size:'8',color:'Black',stock:999}])]), 'Cannot reassign another product variant');
  await db.query('select tk_archive_product($1)',[pid]);
  assert.equal(await value('select active from tk_products where id=$1',[pid]),false);
  await db.query('insert into storage.objects(bucket_id,name) values($1,$2)',['product-images',`${admin}/shoe.jpg`]);
});
await asUser(alice, async () => {
  await rejected(() => db.query("select tk_save_product('{}','[]')"),'Customers cannot create products');
  await rejected(() => db.query('insert into storage.objects(bucket_id,name) values($1,$2)',['product-images',`${alice}/shoe.jpg`]), 'Customers cannot upload product images');
});
console.log('PASS admin product/variant boundaries, archival and image upload policy');

const favorite = '10000000-0000-0000-0000-000000000001';
await asUser(alice, async () => {
  await db.query('insert into tk_wishlist(user_id,product_id) values($1,$2) on conflict do nothing',[alice,favorite]);
  await db.query('insert into tk_wishlist(user_id,product_id) values($1,$2) on conflict do nothing',[alice,favorite]);
  assert.equal(await value('select count(*)::int from tk_wishlist'),1);
  await rejected(() => db.query('insert into tk_wishlist(user_id,product_id) values($1,$2)',[bob,favorite]), 'Cannot save to another account wishlist');
  await rejected(() => db.query('update tk_wishlist set user_id=$1',[bob]), 'Wishlist owner cannot be rewritten');
});
await asUser(bob, async () => {
  assert.equal(await value('select count(*)::int from tk_wishlist'),0);
  await db.query('delete from tk_wishlist where user_id=$1',[alice]);
});
await asUser(alice, async () => { assert.equal(await value('select count(*)::int from tk_wishlist'),1); });
await asUser(null, async () => {
  await rejected(() => db.query('select * from tk_wishlist'), 'Guests cannot read account wishlists');
  await rejected(() => db.query('insert into tk_wishlist(user_id,product_id) values($1,$2)',[alice,favorite]), 'Guests cannot write account wishlists');
}, 'anon');
await asUser(admin, async () => {
  const product = {name:'Fit test',brand:'Nike',description:'Verified fit metadata',price_cents:500000,images:['https://example.com/fit.jpg'],category:'Running',fit_notes:'Test fit note'};
  const variants = [{size:'8',color:'Blue',stock:2}];
  const pid = await value('select tk_save_product($1::jsonb,$2::jsonb)',[JSON.stringify(product),JSON.stringify(variants)]);
  assert.equal(await value('select category from tk_products where id=$1',[pid]),'Running');
  assert.equal(await value('select fit_notes from tk_products where id=$1',[pid]),'Test fit note');
  variants[0].id = await value('select id from tk_variants where product_id=$1',[pid]);
  const oldClient = {...product,id:pid}; delete oldClient.category; delete oldClient.fit_notes;
  await value('select tk_save_product($1::jsonb,$2::jsonb)',[JSON.stringify(oldClient),JSON.stringify(variants)]);
  assert.equal(await value('select category from tk_products where id=$1',[pid]),'Running');
  assert.equal(await value('select fit_notes from tk_products where id=$1',[pid]),'Test fit note');
  await rejected(() => value('select tk_save_product($1::jsonb,$2::jsonb)',[JSON.stringify({...product,category:'invalid'}),JSON.stringify(variants)]), 'Reject unsupported category');
  await rejected(() => value('select tk_save_product($1::jsonb,$2::jsonb)',[JSON.stringify({...product,fit_notes:'x'.repeat(601)}),JSON.stringify(variants)]), 'Limit fit-note length');
  await db.query('select tk_archive_product($1)',[pid]);
  await asUser(alice, async () => { await rejected(() => db.query('insert into tk_wishlist(user_id,product_id) values($1,$2)',[alice,pid]), 'Cannot newly wishlist an archived product'); });
});
await asUser(alice, async () => {
  await db.query('delete from tk_wishlist where product_id=$1',[favorite]);
  assert.equal(await value('select count(*)::int from tk_wishlist'),0);
});
console.log('PASS wishlist privacy, duplicates, guest restrictions, metadata validation and old-client compatibility');
await db.query("insert into tk_vouchers(code,kind,value,ends_at,usage_limit) values('TEST10','PERCENT',10,now()+interval '1 day',1)");
let discounted;
const v2 = key => value('select tk_checkout_v2($1::jsonb,$2::jsonb,$3,$4::uuid,$5,$6)',[JSON.stringify([{variant_id:variant,quantity:1}]),JSON.stringify(delivery),'COD',key,'TEST10',0]);
await asUser(alice,async()=>{
  const q=await value('select tk_quote($1::jsonb,$2)',[JSON.stringify([{variant_id:variant,quantity:1}]),'TEST10']);
  assert.equal(q.voucher_discount_cents,54950);
  discounted=await v2('d0000000-0000-0000-0000-000000000081');
  assert.equal(await v2('d0000000-0000-0000-0000-000000000081'),discounted);
  assert.equal(await value('select total_cents from tk_orders where id=$1',[discounted]),506550);
});
await asUser(bob,()=>rejected(()=>v2('d0000000-0000-0000-0000-000000000082'),'Voucher limit includes reservations'));
await asUser(alice,async()=>{await db.query('select tk_cancel_order($1)',[discounted]);await db.query('select tk_cancel_order($1)',[discounted]);});
await asUser(bob,()=>v2('d0000000-0000-0000-0000-000000000082'));
await asUser(alice,async()=>{
 await rejected(()=>db.query('update tk_loyalty_accounts set balance=10000'),'No customer balances writes');
 const a={recipient:'Alice Test',mobile:'09123456789',label:'Home',street:'123 Example',barangay:'One',city:'Manila',province:'Metro Manila',postal_code:'1000',is_default:true};
 const id=await value('select tk_save_address($1::jsonb)',[JSON.stringify(a)]);
 assert.equal(await value('select count(*)::int from tk_customer_addresses'),1);
 await asUser(bob,()=>rejected(()=>db.query('select tk_save_address($1::jsonb,$2)',[JSON.stringify(a),id]),'Cannot replace another address'));
});
console.log('PASS v2 discounts, reservation limits, idempotency, release, ledger security and address isolation');
await db.query("insert into tk_vouchers(code,kind,value,starts_at,ends_at,minimum_cents,categories) values('EXPIRED','FIXED',100,now()-interval '2 days',now()-interval '1 day',0,'{}'),('MINIMUM','FIXED',100,now(),now()+interval '1 day',1000000000,'{}'),('SCOPED','FIXED',100,now(),now()+interval '1 day',0,array['Skate']),('FREEPAIR','FIXED',1000000000,now(),now()+interval '1 day',0,'{}'),('STACK','PERCENT',10,now(),now()+interval '1 day',0,'{}')");
await db.query('insert into tk_loyalty_accounts(user_id,balance) values($1,100) on conflict(user_id) do update set balance=100',[alice]);
await asUser(alice,async()=>{
 const items=JSON.stringify([{variant_id:variant,quantity:1}]);
 for(const code of ['EXPIRED','MINIMUM','SCOPED'])await rejected(()=>db.query('select tk_quote($1::jsonb,$2)',[items,code]),'Reject expiry, minimum and scope');
 assert.equal((await value('select tk_quote($1::jsonb,$2)',[items,'FREEPAIR'])).total_cents,12000);
 const stacked=await value('select tk_quote($1::jsonb,$2,100)',[items,'STACK']);
 assert.equal(stacked.voucher_discount_cents,54950);assert.equal(stacked.loyalty_discount_cents,5000);assert.equal(stacked.total_cents,501550);
});
const firstCustomer='e0000000-0000-0000-0000-000000000001';
await db.query('insert into auth.users(id) values($1)',[firstCustomer]);
await db.query("insert into tk_vouchers(code,kind,value,ends_at,first_purchase,per_user_limit) values('FIRST','FIXED',100,now()+interval '1 day',true,2)");
await asUser(firstCustomer,async()=>{
 const params=[JSON.stringify([{variant_id:variant,quantity:1}]),JSON.stringify(delivery),'COD','d0000000-0000-0000-0000-000000000061','FIRST',0];
 await value('select tk_checkout_v2($1::jsonb,$2::jsonb,$3,$4::uuid,$5,$6)',params);
 params[3]='d0000000-0000-0000-0000-000000000062';
 await rejected(()=>db.query('select tk_checkout_v2($1::jsonb,$2::jsonb,$3,$4::uuid,$5,$6)',params),'First purchase cannot be claimed again');
});
console.log('PASS voucher dates, minimums, scope, merchandise-only cap, stacking arithmetic and first-purchase exclusion');
await db.query('update tk_loyalty_accounts set balance=0 where user_id=$1',[alice]);
// Exercise actual production functions, including transactional trigger effects.
const outVariant='20000000-0000-0000-0000-000000000212';
await db.query('update tk_variants set stock=0 where id=$1',[outVariant]);
await asUser(alice,async()=>{
 await db.query('select tk_subscribe_restock($1,true)',[outVariant]);
 await db.query('select tk_subscribe_restock($1,true)',[outVariant]);
 assert.equal(await value('select count(*)::int from tk_restock_subscriptions'),1);
});
await db.query('update tk_variants set stock=3 where id=$1',[outVariant]);
await db.query('update tk_variants set stock=4 where id=$1',[outVariant]);
assert.equal(await value("select count(*)::int from tk_notifications where category='restock'"),1);
await asUser(bob,async()=>assert.equal(await value('select count(*)::int from tk_restock_subscriptions'),0));
console.log('PASS exact-variant restock transition, duplicate subscription and alert deduplication');
let ticket;
await asUser(alice,async()=>{ticket=await value("select tk_create_ticket('Order','Where is my order?','Please help with delivery',$1)",[delivered]);});
await asUser(bob,async()=>{
 assert.equal(await value('select count(*)::int from tk_support_tickets'),0);
 await rejected(()=>db.query("select tk_reply_ticket($1,'Forged reply',null)",[ticket]),'Ticket replies isolated');
 await rejected(()=>db.query("select tk_sales_report(current_date,current_date)"),'Analytics private');
});
await asUser(admin,async()=>{await db.query("select tk_reply_ticket($1,'We are checking.','WAITING_FOR_CUSTOMER')",[ticket]);});
await asUser(alice,async()=>{
 await db.query("select tk_reply_ticket($1,'Thank you',null)",[ticket]);
 assert.equal(await value('select status from tk_support_tickets where id=$1',[ticket]),'OPEN');
 await rejected(()=>db.query("select tk_reply_ticket($1,'Closed','CLOSED')",[ticket]),'Customer cannot close arbitrarily');
 await rejected(()=>db.query("select tk_save_shipment($1,'Courier','123','https://courier.example/123','On the way')",[delivered]),'Only admin tracking');
});
await asUser(admin,async()=>{
 await db.query("select tk_save_shipment($1,'Courier','123','https://courier.example/123','Delivery recorded')",[delivered]);
 await rejected(()=>db.query("select tk_save_shipment($1,'Courier','123','javascript:alert(1)','Invalid URL')",[delivered]),'Reject unsafe courier URL');
 const report=await value('select tk_sales_report(current_date-30,current_date+1)');
 assert.ok(Number(report.collected_cents)>0);assert.ok(report.daily.length>0);
});
console.log('PASS support persistence, replies, status rules, shipment authorization, safe links and private analytics');
const review=await value('select id from tk_reviews where item_id=$1',[item]);
await asUser(alice,()=>rejected(()=>db.query("select tk_reserve_review_image($1,$2,'image/png',1024,200,200)",[review,alice]),'Customers cannot bypass image-byte validation'));
let photo;
await asUser(null,async()=>{photo=await value("select tk_reserve_review_image($1,$2,'image/png',1024,200,200)",[review,alice]);},'service_role');
await db.query("update tk_review_images set status='VISIBLE' where id=$1",[photo.id]);
await asUser(bob,()=>rejected(()=>db.query('select tk_remove_review_image($1)',[photo.id]),'Cannot remove another review photo'));
await asUser(alice,()=>db.query('select tk_remove_review_image($1)',[photo.id]));
assert.equal(await value('select status from tk_review_images where id=$1',[photo.id]),'REMOVED');
console.log('PASS review media protected reservation, ownership and removal');
await asUser(null,async()=>{
 for(let i=0;i<3;i++)await db.query("select tk_reserve_review_image($1,$2,'image/jpeg',1024,200,200)",[review,alice]);
 await rejected(()=>db.query("select tk_reserve_review_image($1,$2,'image/jpeg',1024,200,200)",[review,alice]),'Photo count is locked at three');
},'service_role');
await asUser(null,async()=>{assert.equal(await value('select count(*)::int from tk_review_images'),0);},'anon');
await asUser(alice,async()=>{
 await db.query("insert into tk_notification_preferences(user_id,push_enabled) values($1,true)",[alice]);
 await db.query("select tk_register_device('test-device-token-for-alice-12345',true)");
});
await db.query("insert into tk_notifications(user_id,title,message) values($1,'Test update','Open app')",[alice]);
assert.equal(await value('select count(*)::int from tk_notification_outbox'),1);
await asUser(alice,()=>rejected(()=>db.query('select * from tk_device_tokens'),'Device tokens are not exposed'));
await asUser(null,async()=>{
 const jobs=await value('select tk_claim_push(10)');assert.equal(jobs.length,1);
 await db.query("select tk_finish_push($1,$2,'DELIVERED',null)",[jobs[0].id,jobs[0].lease_id]);
 await db.query("select tk_finish_push($1,$2,'PENDING','duplicate finish')",[jobs[0].id,jobs[0].lease_id]);
},'service_role');
assert.equal(await value('select status from tk_notification_outbox'),'DELIVERED');
console.log('PASS review count, anonymous visibility, private tokens, notification queue leases and duplicate delivery completion');
await db.query('update tk_variants set stock=100 where id=$1',[variant]);
let rewardOrder;
await asUser(alice,async()=>{rewardOrder=await create('d0000000-0000-0000-0000-000000000071',2);});
await asUser(admin,async()=>{for(const s of ['CONFIRMED','PREPARING','SHIPPED','DELIVERED'])await db.query('select tk_advance_order($1,$2)',[rewardOrder,s]);});
assert.equal(await value("select count(*)::int from tk_receipts where order_id=$1",[rewardOrder]),1);
await asUser(bob,async()=>assert.equal(await value('select count(*)::int from tk_receipts where order_id=$1',[rewardOrder]),0));
const earnedPoints=await value("select points from tk_loyalty_ledger where order_id=$1 and kind='EARN'",[rewardOrder]);
assert.equal(earnedPoints,109);
await asUser(alice,()=>rejected(()=>db.query("update tk_loyalty_ledger set points=100000"),'Immutable points'));
let pointsOrder;
await asUser(alice,async()=>{
 pointsOrder=await value('select tk_checkout_v2($1::jsonb,$2::jsonb,$3,$4::uuid,$5,$6)',[JSON.stringify([{variant_id:variant,quantity:1}]),JSON.stringify(delivery),'COD','d0000000-0000-0000-0000-000000000072','',100]);
 await rejected(()=>value('select tk_checkout_v2($1::jsonb,$2::jsonb,$3,$4::uuid,$5,$6)',[JSON.stringify([{variant_id:variant,quantity:1}]),JSON.stringify(delivery),'COD','d0000000-0000-0000-0000-000000000073','',100]),'Cannot double-spend points');
 const before=await value('select balance from tk_loyalty_accounts where user_id=$1',[alice]);
 await db.query('select tk_cancel_order($1)',[pointsOrder]);await db.query('select tk_cancel_order($1)',[pointsOrder]);
 assert.equal(await value('select balance from tk_loyalty_accounts where user_id=$1',[alice]),before+100);
});
await asUser(null,async()=>{
 await db.query('select tk_confirm_refund($1,$2,$3)',[rewardOrder,'verified-test-refund',1111000]);
 await db.query('select tk_confirm_refund($1,$2,$3)',[rewardOrder,'verified-test-refund',1111000]);
},'service_role');
assert.equal(await value("select count(*)::int from tk_loyalty_ledger where source='refund:verified-test-refund'"),1);
console.log('PASS COD collection, unique receipts, fulfilled rewards, no double spend, repeated release and verified refund reversal');
await asUser(alice,async()=>{
 await db.query("select tk_set_push_enabled(true,$1)",['new-device-token-for-atomic-preferences']);
 assert.equal(await value('select push_enabled from tk_notification_preferences where user_id=$1',[alice]),true);
 await rejected(()=>db.query('select tk_set_push_enabled(true,null)'),'Missing registration must fail');
 await db.query('select tk_set_push_enabled(false,null)');
 assert.equal(await value('select push_enabled from tk_notification_preferences where user_id=$1',[alice]),false);
});
assert.equal(await value('select count(*)::int from tk_device_tokens where user_id=$1 and active',[alice]),0);
await asUser(null,()=>rejected(()=>db.query('select tk_set_push_enabled(false,null)'),'Guests cannot change push preferences'),'anon');
// Simulate a pre-feature, admin-collected COD order missing its document.
await db.query('delete from tk_receipts where order_id=$1',[rewardOrder]);
await db.query('update tk_orders set paid_at=null,payment_reference=null where id=$1',[rewardOrder]);
const repair=await readFile(new URL('../supabase/migrations/202610250001_checkout_documents_push.sql',import.meta.url),'utf8');
await db.exec(repair);
const repaired=await value('select reference from tk_receipts where order_id=$1',[rewardOrder]);
await db.exec(repair);
assert.equal(await value('select reference from tk_receipts where order_id=$1',[rewardOrder]),repaired);
console.log('PASS atomic authenticated push preference/token changes and repeatable legacy COD receipt repair');
await db.close();
