import json,collections
from laya import Agent
a=Agent('ck3')
te=json.load(open('test_gioi.json')); moi=set(json.load(open('test_gioi_moi.json')))
phieu=collections.defaultdict(lambda: collections.Counter()); that={}
d=n=0; lop=collections.Counter(); dl=collections.Counter(); dc=nc=0
for r in te:
    if r['_ten'] not in moi: continue
    o=a.predict(r['state'],r['questions'])['answers']['g']; g=r['expected']['g']
    ok=o['choice']==g; d+=ok; n+=1; lop[g]+=1; dl[g]+=ok
    if o['confidence']>=0.9: nc+=1; dc+=ok
    phieu[r['_ten']][o['choice']]+=o['confidence']; that[r['_ten']]=g
print(f'theo mẫu: đúng {d}/{n} (nam {dl["nam"]}/{lop["nam"]}, nữ {dl["nữ"]}/{lop["nữ"]}) | tin cậy>=0.9: {dc}/{nc}')
kq={t:p.most_common(1)[0][0] for t,p in phieu.items()}
sai=[(t,that[t]) for t in kq if kq[t]!=that[t]]
nn=sum(g=='nam' for g in that.values())
print(f'theo nhân vật (gộp phiếu): đúng {len(kq)-len(sai)}/{len(kq)} (trong đó {nn} nam, {len(kq)-nn} nữ) | sai: {sai}')
for f in ['test.jsonl','test_ldk.jsonl']:
    rows=[json.loads(l) for l in open(f,encoding='utf8')]
    print(f,'người nói đúng',sum(a.predict(r['state'],r['questions'])['answers']['q']['choice']==r['expected']['q'] for r in rows),'/',len(rows))
