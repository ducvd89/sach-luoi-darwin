import json,sys
from laya import Agent
for ck in ['ck1','ck2']:
    a=Agent(ck)
    for f in ['test.jsonl','test_ldk.jsonl']:
        rows=[json.loads(l) for l in open(f,encoding='utf8')]
        d=dc=nc=0
        for r in rows:
            o=a.predict(r['state'],r['questions'])['answers']['q']
            ok=o['choice']==r['expected']['q']; d+=ok
            if o['confidence']>=0.9: nc+=1; dc+=ok
        print(f'{ck} {f:15s} đúng {d}/{len(rows)} | tin cậy>=0.9: {dc}/{nc}',flush=True)
