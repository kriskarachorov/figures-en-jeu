/* Readiness uses only recent, unaided answers; it is not a predicted exam grade. */
(() => {
 const DAY=86400000;
 function assess(rounds,now=Date.now()){
  return window.THURSDAY_FIGURES.map(f=>{
   const all=rounds.flatMap(r=>r.answers.filter(a=>a.figureId===f.id).map(a=>({...a,date:r.completed_at,round:r.id}))).sort((a,b)=>Date.parse(b.date)-Date.parse(a.date));
   const recent=all.filter(a=>now-Date.parse(a.date)<=7*DAY).slice(0,5),last=all[0];
   const good=recent.filter(a=>a.correct&&!a.hinted),variants=new Set(good.map(a=>a.questionId));
   const solid=good.length>=3&&good.length/recent.length>=.8&&variants.size>=2&&good.some(a=>a.reasonId!==null&&a.reasonId!==undefined)&&last?.correct&&!last.hinted;
   const days=solid?3:1,nextAt=last?Date.parse((window.GameClock?GameClock.day(Date.parse(last.date)):last.date.slice(0,10))+'T00:00:00Z')+days*DAY:null,due=!last||!last.correct||last.hinted||(window.GameClock?GameClock.day(now):new Date(now).toISOString().slice(0,10))>=new Date(nextAt).toISOString().slice(0,10);
   const status=!last?'À découvrir':!recent.length||!last.correct||last.hinted?'À reprendre':solid?'Solide':'En cours';
   const priority=status==='À reprendre'?100+recent.filter(a=>!a.correct||a.hinted).length*5:due?60:status==='À découvrir'?50:status==='En cours'?30:0;
   return {id:f.id,name:f.name,status,due,priority,recent:recent.length,unaided:good.length,nextReview:last?new Date(nextAt).toISOString():null,lastQuestion:last?.questionId};
  });
 }
 function chooseExample(f,rounds){
  const counts=new Map(),last=[];
  for(const r of rounds)for(const a of r.answers)if(a.figureId===f.id){counts.set(a.questionId,(counts.get(a.questionId)||0)+1);last.push(a.questionId)}
  return f.examples.map((_,i)=>({i,count:counts.get(f.id*100+i)||0,repeated:last.at(-1)===f.id*100+i,random:Math.random()})).sort((a,b)=>Number(a.repeated)-Number(b.repeated)||a.count-b.count||a.random-b.random)[0].i;
 }
 window.ThursdayLearning={assess,chooseExample};
})();
