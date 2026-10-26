// Disposable, loopback-only PostgreSQL. No application or hosted database is used.
import EmbeddedPostgres from 'embedded-postgres';
import pg from 'pg';
import {mkdir} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import {randomUUID} from 'node:crypto';
import {createServer} from 'node:net';
import assert from 'node:assert/strict';
import {execFile} from 'node:child_process';
import {promisify} from 'node:util';
const port=await new Promise((resolve,reject)=>{const s=createServer();s.on('error',reject);s.listen(0,'127.0.0.1',()=>{const p=s.address().port;s.close(()=>resolve(p));});});
const dir=fileURLToPath(new URL(`./runtime/pg-${randomUUID()}`,import.meta.url));
await mkdir(dir,{recursive:true});
const password=randomUUID();
const server=new EmbeddedPostgres({databaseDir:dir,user:'postgres',password,port,persistent:true,postgresFlags:['-h','127.0.0.1'],onLog:()=>{},onError:()=>{}});
let client;
const config={host:'127.0.0.1',port,user:'postgres',password,database:'postgres'};
try{
 await server.initialise();await server.start();
 client=new pg.Client(config);await client.connect();
 globalThis.tkTestDatabase={exec:sql=>client.query(sql),query:(sql,args)=>client.query(sql,args),close:async()=>{}};
 await import('./database_test.mjs');
 const variant='20000000-0000-0000-0000-000000000106';
 const alice='a0000000-0000-0000-0000-000000000001',bob='b0000000-0000-0000-0000-000000000001';
 await client.query('update tk_variants set stock=100 where id=$1',[variant]);
 await client.query("insert into tk_vouchers(code,kind,value,ends_at,usage_limit) values('RACE','FIXED',1000,now()+interval '1 day',1)");
 const attempt=async(user,code,points)=>{
  const c=new pg.Client(config);await c.connect();
  try{
   await c.query('begin');await c.query('set local role authenticated');
   await c.query("select set_config('request.jwt.claim.sub',$1,true)",[user]);
   await c.query("select set_config('request.jwt.claim.role','authenticated',true)");
   const result=await c.query('select tk_checkout_v2($1::jsonb,$2::jsonb,$3,$4::uuid,$5,$6)',[
    JSON.stringify([{variant_id:variant,quantity:1}]),JSON.stringify({name:'Concurrency Test',phone:'09123456789',address:'123 Test Street, Manila'}),'COD',randomUUID(),code,points]);
   // Keep the first reservation uncommitted briefly to exercise real row-lock waits.
   await c.query('select pg_sleep(0.15)');await c.query('commit');return result.rows[0];
  }catch(e){await c.query('rollback');throw e;}finally{await c.end();}
 };
 const vouchers=await Promise.allSettled([attempt(alice,'RACE',0),attempt(bob,'RACE',0)]);
 assert.equal(vouchers.filter(r=>r.status==='fulfilled').length,1);
 assert.equal(Number((await client.query("select count(*) from tk_voucher_redemptions r join tk_vouchers v on v.id=r.voucher_id where v.code='RACE' and r.status='RESERVED'")).rows[0].count),1);
 // Fixture balance exists only in this disposable cluster; production has no adjustment API.
 await client.query('update tk_loyalty_accounts set balance=100,debt=0 where user_id=$1',[alice]);
 const points=await Promise.allSettled([attempt(alice,'',100),attempt(alice,'',100)]);
 assert.equal(points.filter(r=>r.status==='fulfilled').length,1);
 assert.equal((await client.query('select balance from tk_loyalty_accounts where user_id=$1',[alice])).rows[0].balance,0);
 assert.equal((await client.query('select stock from tk_variants where id=$1',[variant])).rows[0].stock,98);
 console.log('PASS real PostgreSQL concurrent voucher limit and loyalty double-spend races; failed transactions roll back stock');
}catch(e){console.error('Database test failed:',e.message);process.exitCode=1;}
finally{
 if(client)await client.end();
 if(process.platform==='win32' && server.process && server.process.exitCode===null){
  // Graceful shutdown avoids orphaned PostgreSQL I/O workers on Windows.
  try{
   await promisify(execFile)(fileURLToPath(new URL('./node_modules/@embedded-postgres/windows-x64/native/bin/pg_ctl.exe',import.meta.url)),
    ['-D',dir,'-m','fast','-w','-t','20','stop'],{windowsHide:true,timeout:25000});
   server.process.stdout?.destroy();server.process.stderr?.destroy();server.process.unref();
  }catch{await server.stop();}
 }else if(server.process?.exitCode===null){await server.stop();}
}
