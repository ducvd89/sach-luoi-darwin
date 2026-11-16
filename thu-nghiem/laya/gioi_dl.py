import json,glob,os,re,random,collections
rd=random.Random(1)
def Q(t): return {'g':{'type':'choice','instructions':f'Is the character {t} in `passage` male or female?','criteria':{'nam':'male (nam giới)','nữ':'female (nữ giới)'}}}
def mau(van,k,g,toi_da=6):
    v=[m.start() for m in re.finditer(re.escape(k),van)]
    rd.shuffle(v); ra=[]
    for i in range(0,min(len(v),toi_da*2),2):
        c=' […] '.join(van[max(0,p-160):p+200].replace('\n',' ') for p in v[i:i+2])
        ra.append({'state':{'passage':c},'questions':Q(k),'expected':{'g':g},'_ten':k})
    return ra
tr=[];te=[];tk=collections.Counter()
for d in sorted(glob.glob('../haiku/gioi/*')):
    f=d+'/ket_qua.json'
    if not os.path.exists(f): print('thiếu',d); continue
    van=open(d+'/chuong.txt',encoding='utf8').read(); h=json.load(open(f))
    la_test=os.path.basename(d).startswith('T_')
    for k,g in h.items():
        if g not in('nam','nữ') or k not in van: tk['bỏ (không thấy/nhãn lạ)']+=1; continue
        (te if la_test else tr).extend(mau(van,k,g))
    print(os.path.basename(d),len(h),'nhân vật',dict(collections.Counter(h.values())))
ten_tr={r['_ten'] for r in tr}
te_moi=[r for r in te if r['_ten'] not in ten_tr and not any(r['_ten'] in t or t in r['_ten'] for t in ten_tr)]
def dem(rs): return len(rs),len({r['_ten'] for r in rs}),dict(collections.Counter(r['expected']['g'] for r in rs))
print('train (mẫu, nhân vật, giới):',dem(tr)); print('test tất cả:',dem(te)); print('test nhân vật MỚI:',dem(te_moi)); print(dict(tk))
ng=[l for l in open('train2.jsonl',encoding='utf8')]; rd.shuffle(ng)
al=[json.dumps({k:v for k,v in r.items() if k!='_ten'},ensure_ascii=False)+'\n' for r in tr]+ng[:500]; rd.shuffle(al)
open('train3.jsonl','w',encoding='utf8').writelines(al)
json.dump(te,open('test_gioi.json','w'),ensure_ascii=False); json.dump([r['_ten'] for r in te_moi],open('test_gioi_moi.json','w'),ensure_ascii=False)
open('test_gioi.jsonl','w',encoding='utf8').writelines(json.dumps({k:v for k,v in r.items() if k!='_ten'},ensure_ascii=False)+'\n' for r in te_moi)
print('train3:',len(al),'dòng (kèm 500 câu người nói)')
