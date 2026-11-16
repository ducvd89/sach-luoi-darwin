import json,glob,os,collections,random
INS='Which character speaks the `quote` in the `passage`?'
def hang(van,qs,i,ds,nhan):
    s,e=qs[i]
    return {'state':{'passage':van[max(0,s-450):e+200],'quote':van[s:e]},
            'questions':{'q':{'type':'choice','instructions':INS,'criteria':{n:n for n in ds}}},'expected':{'q':nhan}}
def tu(d,f):
    D=json.load(open(d)); van=D['van']; qs=D['qs']
    h={int(k):v for k,v in json.load(open(f)).items() if k.isdigit() and int(k)<len(qs)}
    dem=collections.Counter(v for v in h.values() if v!='KHAC'); ds=list(dem)
    return [hang(van,qs,i,ds,h[i]) for i in sorted(h) if h[i]!='KHAC' and len(ds)>=2], len(qs), len(h), dict(dem.most_common(5))
ld=[]
for d in sorted(glob.glob('../haiku/ldk_train/k*')):
    if not os.path.exists(d+'/ket_qua.json'): print('thiếu',d); continue
    r,n,m,dem=tu(d+'/q.json',d+'/ket_qua.json'); ld+=r; print(os.path.basename(d),n,'câu,',m,'có nhãn,',len(r),'dùng được',dem)
hp=[l for l in open('train.jsonl',encoding='utf8')]
al=hp+[json.dumps(r,ensure_ascii=False)+'\n' for r in ld]
random.Random(0).shuffle(al)
open('train2.jsonl','w',encoding='utf8').writelines(al)
t,_,_,_=tu('ldk_q.json','../haiku/ldk/ket_qua.json')
open('test_ldk.jsonl','w',encoding='utf8').writelines(json.dumps(r,ensure_ascii=False)+'\n' for r in t)
print('train2:',len(hp),'HP +',len(ld),'LĐK =',len(al),'| test_ldk',len(t))
