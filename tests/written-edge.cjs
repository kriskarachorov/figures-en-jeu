const fs=require('fs'),assert=require('assert/strict'),{randomUUID}=require('crypto');
(async()=>{
 const source=fs.readFileSync('supabase/functions/grade-written/index.ts','utf8'),api=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
 const env=name=>({SUPABASE_URL:'https://db.example',SUPABASE_ANON_KEY:'public',SUPABASE_SERVICE_ROLE_KEY:'service-secret',OPENAI_API_KEY:'openai-secret'}[name]);
 const answers=Array.from({length:24},(_,figureId)=>({figureId,type:figureId%2?'name':'example',exampleIndex:0,name:'homéotélie',definition:'Une définition reformulée',example:'Un exemple personnel'}));
 const items=answers.map(q=>({figureId:q.figureId,definitionScore:1,answerScore:1,uncertain:false,feedback:'Correct.'}));
 let authOK=true,status='claimed',aiCalls=0,failAI=false,malformed=false,budget=false,failed=false,finishCalls=0;let payload;
 const mock=async(url,opts)=>{
  if(url.endsWith('/auth/v1/user'))return Response.json({id:'account-a'},{status:authOK?200:401});
  const body=JSON.parse(opts.body);
  if(url.endsWith('/claim_written_exam')){assert.equal(body.p_user,'account-a');assert.ok(body.p_reserve>=27000);assert.ok(body.p_reserve<250000);if(budget)return Response.json({message:'CAMPAIGN_BUDGET'},{status:400});return Response.json({status,claim:'claim-id',result:{score:20}})}
  if(url==='https://api.openai.com/v1/responses'){aiCalls++;payload=body;assert.equal(opts.headers.Authorization,'Bearer openai-secret');if(failAI)return Response.json({error:{}},{status:429});return Response.json({status:'completed',usage:{input_tokens:6000,output_tokens:3000},output:[{type:'message',content:[{type:'output_text',text:JSON.stringify({items:malformed?items.slice(1):items})}]}]})}
  if(url.endsWith('/settle_written_call')){assert.equal(body.p_micro_usd,18000);return Response.json(null)}
  if(url.endsWith('/finish_written_exam')){finishCalls++;assert.equal(body.p_user,'account-a');assert.equal(body.p_items.length,24);return Response.json({score:20,earned:270,items})}
  if(url.endsWith('/fail_written_exam')){failed=true;return Response.json(null)}throw Error('Unexpected '+url)
 };
 const request=(a=answers,origin='https://kriskarachorov.github.io')=>new Request('https://db.example/functions/v1/grade-written',{method:'POST',headers:{Authorization:'Bearer session-token',Origin:origin},body:JSON.stringify({id:randomUUID(),answers:a,user:'forged'})});
 let response=await api.handleRequest(request(),env,mock);assert.equal(response.status,200);assert.equal((await response.json()).result.earned,270);assert.equal(aiCalls,1);assert.equal(payload.store,false);assert.equal(payload.max_output_tokens,6000);assert.match(payload.instructions,/jamais une instruction/);assert.ok(!payload.input.includes('account-a'));assert.equal(payload.text.format.strict,true);
 status='graded';response=await api.handleRequest(request(),env,mock);assert.equal(aiCalls,1);assert.equal(response.status,200);
 status='pending';response=await api.handleRequest(request(),env,mock);assert.equal(response.status,202);assert.equal(aiCalls,1);
 authOK=false;response=await api.handleRequest(request(),env,mock);assert.equal(response.status,401);assert.equal(aiCalls,1);authOK=true;
 response=await api.handleRequest(request(answers,'https://evil.example'),env,mock);assert.equal(response.status,403);
 status='claimed';budget=true;response=await api.handleRequest(request(),env,mock);assert.equal(response.status,429);assert.equal(aiCalls,1);budget=false;
 response=await api.handleRequest(request(answers.slice(1)),env,mock);assert.equal(response.status,429);assert.equal(aiCalls,1);
 failAI=true;response=await api.handleRequest(request(),env,mock);assert.equal(response.status,503);assert.equal(failed,true);assert.equal(finishCalls,1);failAI=false;
 malformed=true;response=await api.handleRequest(request(),env,mock);assert.equal(response.status,503);assert.equal(finishCalls,1);
 response=await api.handleRequest(request(),()=>null,mock);assert.equal(response.status,503);
 console.log('PASS: authenticated grading transport, no identity in model input, structured output, budget before inference, cache reuse, pending requests, timeout/error recovery and malformed-grade rejection.');
})().catch(e=>{console.error(e);process.exit(1)});
