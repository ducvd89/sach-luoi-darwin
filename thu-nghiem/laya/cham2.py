import json,time,resource,sys
from laya import Agent
from vang import VANG
import luat
a=Agent('ck1',device=sys.argv[1])
rows=[json.loads(l) for l in open('test.jsonl',encoding='utf8')]
ids=sorted(VANG); ra=luat.doan(); ls={i for i in VANG if ra[i]!=VANG[i]}
a.predict(rows[0]['state'],rows[0]['questions'])
d=dc=nc=0; sai=[]; t=time.time()
for i,r in zip(ids,rows):
    o=a.predict(r['state'],r['questions'])['answers']['q']
    ok=o['choice']==r['expected']['q']; d+=ok
    if o['confidence']>=0.9: nc+=1; dc+=ok
    if not ok: sai.append((i,o['choice'],r['expected']['q'],round(o['confidence'],2)))
tg=time.time()-t
print(sys.argv[1],f'đúng {d}/90 | tin cậy>=0.9: {dc}/{nc} | {tg/90*1000:.0f} ms/câu | RSS đỉnh {resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/1e6:.0f} MB')
for s in sai: print(' sai',s)
print('trong 11 câu luật sai, Laya đã train đúng',sum(1 for i in ls if i not in {s[0] for s in sai}))
