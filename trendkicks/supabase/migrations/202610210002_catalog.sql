-- Illustrative school/demo catalog. Replace sample photos and pricing before selling.
begin;
insert into public.tk_products(id,name,brand,description,price_cents,images)
select ('10000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,name,brand,description,price,array['asset:assets/images/' || image]
from (values
 (1,'Air Force 1 ’07','Nike','An everyday icon. Clean leather, a classic low profile, and comfort that goes with everything.',549500,'nike-air.jpg'),
 (2,'Dunk Low Retro','Nike','Court heritage meets everyday style. A timeless silhouette with a padded collar and a crisp two-tone finish.',589500,'nike-dunk.jpg'),
 (3,'Samba OG','Adidas','From the indoor pitch to your daily rotation. A low-profile classic with suede details and a gum outsole.',680000,'adidas-samba.jpg'),
 (4,'Suede Classic','Puma','Soft suede and a street-ready shape. An enduring classic built for your own pace.',480000,'puma-suede.jpg'),
 (5,'Air Max 90','Nike','Visible cushioning, layered textures, and a familiar shape. Made for long days and easy styling.',739500,'nike-max.jpg'),
 (6,'Campus 00s','Adidas','A fresh take on a terrace favorite. A chunky profile, soft upper, and unmistakable three-stripe detail.',650000,'adidas-campus.jpg'),
 (7,'RS-X Efekt','Puma','A bold, layered runner with a cushioned feel. Bring a little extra energy to your everyday rotation.',620000,'puma-rsx.jpg'),
 (8,'Gazelle Indoor','Adidas','Rich color, soft suede, and a translucent gum sole. A classic that keeps finding new ways to stand out.',700000,'adidas-gazelle.jpg')
) as seed(i,name,brand,description,price,image) on conflict(id) do nothing;

insert into public.tk_variants(id,product_id,size,color,stock)
select ('20000000-0000-0000-0000-' || lpad((i*100+s)::text,12,'0'))::uuid,
 ('10000000-0000-0000-0000-' || lpad(i::text,12,'0'))::uuid,s::text,color,case when s=12 then 0 else 8 end
from (values (1,'White'),(2,'Black / White'),(3,'White / Gum'),(4,'Forest Green'),(5,'Sail / Orange'),(6,'Grey / White'),(7,'Cream / Sand'),(8,'Blue / Gum')) as seed(i,color)
cross join generate_series(6,12) s on conflict(id) do nothing;
commit;
