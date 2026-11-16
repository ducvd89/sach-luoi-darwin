import json,sys,time,collections
D=json.load(open('ldk_q.json')); van=D['van']; qs=D['qs']
h={int(k):v for k,v in json.load(open('../haiku/ldk/ket_qua.json')).items()}
ds=[n for n,c in collections.Counter(v for v in h.values() if v!='KHAC').items()]
ids=[i for i in range(len(qs)) if h.get(i,'KHAC')!='KHAC']
print(len(qs),'câu;',len(h),'có nhãn;',len(ids),'dùng được;',len(ds),'nhân vật:',collections.Counter(h.values()).most_common(8))
# Luật: tên gần nhất đứng trước câu thoại, tính từ cuối câu thoại trước (hoặc đầu đoạn); không có thì người nói cách hai lượt
ra={}; ls=[]
for i,(s,e) in enumerate(qs):
    dau=max(van.rfind('\n',0,s)+1, qs[i-1][1] if i else 0)
    doan=van[dau:s]; best=None
    for n in ds:
        p=doan.rfind(n)
        if p>=0 and (best is None or p>best[0]): best=(p,n)
    n=best[1] if best else (ls[-2] if len(ls)>=2 else (ls[-1] if ls else None))
    ra[i]=n; ls.append(n)
sl=[i for i in ids if ra[i]!=h[i]]
print(f'luật: khớp Haiku {len(ids)-len(sl)}/{len(ids)}')
from laya import Agent
INS='Which character speaks the `quote` in the `passage`?'
for ck in sys.argv[1:]:
    a=Agent(ck,subfolder='multilingual') if ck.startswith('conv') else Agent(ck)
    d=dc=nc=0; sai=[]; t=time.time()
    for i in ids:
        s,e=qs[i]
        o=a.predict({'passage':van[max(0,s-450):e+200],'quote':van[s:e]},{'q':{'type':'choice','instructions':INS,'criteria':{n:n for n in ds}}})['answers']['q']
        ok=o['choice']==h[i]; d+=ok
        if o['confidence']>=0.9: nc+=1; dc+=ok
        if not ok: sai.append(i)
    print(f'{ck}: khớp Haiku {d}/{len(ids)} | tin cậy>=0.9: {dc}/{nc} | {(time.time()-t)/len(ids)*1000:.0f} ms/câu')
    print('  trong',len(sl),'câu luật lệch Haiku, Laya khớp',sum(1 for i in sl if i not in sai))
    json.dump({'laya_sai':sai,'luat_sai':sl},open('ldk_sai.json','w'))
