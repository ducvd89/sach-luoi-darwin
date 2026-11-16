import sys,json,time
from laya import Agent
a=Agent(sys.argv[1]) if len(sys.argv)>1 else None
rows=[json.loads(l) for l in open('test.jsonl',encoding='utf8')]
d=dc=nc=0; t=time.time()
for r in rows:
    o=a.predict(r['state'],r['questions'])['answers']['q']
    ok=o['choice']==r['expected']['q']; d+=ok
    if o['confidence']>=0.9: nc+=1; dc+=ok
print(f'đúng {d}/90   tin cậy>=0.9: {dc}/{nc}   {time.time()-t:.1f}s')
