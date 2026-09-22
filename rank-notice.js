/* Only announce a saved reward, on that reward's still-visible result screen. */
(() => {
 const requests=new Map();
 async function check(result,owner){
  const key=result.round?'round:'+result.round:'week:'+result.week;
  const target=document.getElementById('rank-notice');
  if(!owner||GameAccount.userId()!==owner||!target||target.dataset.result!==key)return;
  const requestKey=owner+':'+key;
  try{
   if(!requests.has(requestKey))requests.set(requestKey,GameAccount.api('get_xp_overtake',{p_round:result.round||null,p_week:result.week||null},owner));
   const notice=await requests.get(requestKey);
   if(GameAccount.userId()!==owner||!target.isConnected||document.getElementById('rank-notice')!==target||target.dataset.result!==key)return;
   if(!notice||!Number.isInteger(notice.rank)||notice.rank<1||!Number.isInteger(notice.passed_count)||notice.passed_count<1)return;
   const others=notice.passed_count-1;
   const name=String(notice.nickname||'Joueur').replace(/^@+/,'');
   target.textContent=`Vous avez dépassé @${name}${others?' et '+others+' autre'+(others>1?'s joueurs':' joueur'):''}. Vous occupez désormais la ${notice.rank===1?'1re':notice.rank+'e'} place. Continuez ainsi !`;
   target.hidden=false;
  }catch{requests.delete(requestKey)}
 }
 window.RankNotice={check};
 window.addEventListener('account-identity-changed',()=>requests.clear());
})();
