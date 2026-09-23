const {PGlite}=require('@electric-sql/pglite'),fs=require('fs'),assert=require('assert/strict');
(async()=>{
 const db=new PGlite();
 await db.exec(`create role service_role;create role anon;create role authenticated;create schema auth;
 create table auth.users(id uuid primary key,raw_user_meta_data jsonb default '{}'::jsonb);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
 grant usage on schema auth to anon,authenticated;grant execute on function auth.uid() to anon,authenticated;`);
 for(const f of fs.readdirSync(process.argv[2]).filter(f=>f.endsWith('.sql')).sort())await db.exec(fs.readFileSync(process.argv[2]+'/'+f,'utf8'));
 const id=n=>'00000000-0000-4000-8000-'+String(n).padStart(12,'0');
 for(const [n,name,xp] of [[1,'Leader',100],[2,'Equal',100],[3,'Scorer',50],[4,'Maria',0],[5,'bob',0],[6,'bob',0],[7,'alice',0],[8,'Raiche',0]]){
  await db.query('insert into auth.users values($1,$2)',[id(n),JSON.stringify({display_name:name})]);
  if(xp)await db.query("insert into public.game_rounds(user_id,id,mode,answers,earned,best_combo) values($1,$2,'practice','[]',$3,0)",[id(n),id(100+n),xp]);
 }
 const read=async n=>{await db.exec(`set role authenticated;set request.jwt.claim.sub='${id(n)}'`);return (await db.query('select public.get_xp_leaderboard() data')).rows[0].data};
 let result=await read(4);
 assert.deepEqual(result.players.map(p=>[p.nickname,p.rank]),[['Equal',1],['Leader',1],['Scorer',2],['alice',3],['bob',4],['bob',5],['Maria',6],['Raiche',7]]);
 assert.equal(result.me.rank,6);
 assert.equal((await read(5)).me.rank,4);assert.equal((await read(6)).me.rank,5);
 await db.exec('reset role');
 await db.query("insert into public.game_rounds(user_id,id,mode,answers,earned,best_combo) values($1,$2,'practice','[]',10,0)",[id(6),id(106)]);
 result=await read(6);assert.equal(result.me.rank,3);assert.equal(result.players.find(p=>p.nickname==='alice').rank,4);
 await db.exec('reset role');await db.exec('delete from public.game_rounds');
 result=await read(4);assert.deepEqual(result.players.map(p=>p.rank),[1,2,3,4,5,6,7,8]);
 // The personal rank remains available beyond the first 100 rows.
 await db.exec('reset role');
 for(let n=9;n<110;n++)await db.query('insert into auth.users values($1,$2)',[id(n),JSON.stringify({display_name:'A'+n})]);
 result=await read(8);assert.equal(result.players.length,100);assert.equal(result.me.rank,108);
 await db.exec('reset role;set role anon');await assert.rejects(()=>db.query('select public.get_xp_leaderboard()'));
 await db.close();console.log('PASS: alphabetical zero-XP ranks, stable duplicate names, positive ties, first XP, all-zero board, own rank beyond top 100 and authenticated access.');
})().catch(e=>{console.error(e);process.exit(1)});
