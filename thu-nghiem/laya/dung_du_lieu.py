# Dựng train.jsonl từ nhãn Haiku, test.jsonl từ 90 câu gán tay của chương 5.
import json,glob,os,collections
INS='Which character speaks the `quote` in the `passage`?'
def hang(L,i,ds,nhan):
    return {'state':{'passage':'\n'.join(L[max(0,i-3):i+2]),'quote':L[i]},
            'questions':{'q':{'type':'choice','instructions':INS,'criteria':{n:n for n in ds}}},'expected':{'q':nhan}}
tr=[]; tk=collections.Counter()
for d in sorted(glob.glob('../haiku/train/c*')):
    f=d+'/ket_qua.json'
    if not os.path.exists(f): print('thiếu',d); continue
    L=[l.split(': ',1)[1] for l in open(d+'/chuong.txt',encoding='utf8').read().split('\n')]
    h={int(k):v for k,v in json.load(open(f)).items()}
    q={i for i,t in enumerate(L) if t.startswith('“')}
    for k in sorted(set(h)-q):   # khoá lệch sang dòng lời dẫn: kéo về câu thoại liền kề chưa có nhãn
        for j in (k-1,k+1):
            if j in q and j not in h: h[j]=h[k]; tk['sửa lệch khoá']+=1; break
        del h[k]
    tk['thiếu nhãn']+=len(q-set(h)); tk['KHAC']+=sum(v=='KHAC' for v in h.values())
    dem=collections.Counter(v for v in h.values() if v!='KHAC')
    ds=[n for n,c in dem.items()]
    for i in sorted(h):
        if h[i]!='KHAC' and len(ds)>=2: tr.append(hang(L,i,ds,h[i]))
    print(os.path.basename(d),len(q),'câu,',len(ds),'nhân vật:',dict(dem.most_common(6)))
with open('train.jsonl','w',encoding='utf8') as f:
    for r in tr: f.write(json.dumps(r,ensure_ascii=False)+'\n')
from vang import VANG,NHAN
L=open('chuong5.txt',encoding='utf8').read().split('\n')
with open('test.jsonl','w',encoding='utf8') as f:
    for i in sorted(VANG): f.write(json.dumps(hang(L,i,NHAN,VANG[i]),ensure_ascii=False)+'\n')
print('train',len(tr),'| test 90 |',dict(tk))
