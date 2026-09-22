/* One shared quest timezone; UTC weekly challenges keep their separate schedule. */
(() => {
 const zone='Europe/Sofia',formatter=new Intl.DateTimeFormat('en-CA',{timeZone:zone,year:'numeric',month:'2-digit',day:'2-digit'});
 function day(at=Date.now()){const p=Object.fromEntries(formatter.formatToParts(new Date(at)).map(p=>[p.type,p.value]));return p.year+'-'+p.month+'-'+p.day}
 function delay(at=Date.now()){const current=day(at);let lo=at,hi=at+36*3600000;while(hi-lo>1){const mid=Math.floor((hi+lo)/2);if(day(mid)===current)lo=mid;else hi=mid}return hi-at}
 let current=day(),timer;
 function check(){const next=day();if(next!==current){const previous=current;current=next;window.dispatchEvent(new CustomEvent('game-day-changed',{detail:{previous,day:next}}))}clearTimeout(timer);timer=setTimeout(check,delay()+20)}
 window.GameClock={zone,day,index:()=>Math.floor(Date.parse(day()+'T00:00:00Z')/86400000),check,delay};
 window.addEventListener('focus',check);document.addEventListener('visibilitychange',()=>{if(document.visibilityState!=='hidden')check()});window.addEventListener('pageshow',check);window.addEventListener('pagehide',()=>clearTimeout(timer));check();
})();
