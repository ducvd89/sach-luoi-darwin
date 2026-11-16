import sys,time,json
from laya import Router
from vang import *
L=open('chuong5.txt',encoding='utf8').read().split('\n')
MOTA={'Harry':'Harry Potter','Ron':'Ron Weasley','Hermione':'Hermione Granger','Ginny':'Ginny Weasley, em gái Ron',
'Fred':'Fred Weasley, anh sinh đôi','George':'George Weasley, anh sinh đôi','Percy':'anh Percy Weasley',
'Bill':'anh Bill Weasley','Charlie':'anh Charlie Weasley','Ông Weasley':'ông Arthur Weasley, người cha',
'Bà Weasley':'bà Molly Weasley, người mẹ'}
def hoi(i):
    return ({'truoc':'\n'.join(L[max(0,i-3):i]),'cau_thoai':L[i],'sau':L[i+1] if i+1<len(L) else ''},
            {'nguoi_noi':{'type':'choice','instructions':'Ai là người nói câu trong `cau_thoai`? Dựa vào lời dẫn trong `truoc` và `sau`.',
                          'criteria':MOTA}})
r=Router(device=sys.argv[1] if len(sys.argv)>1 else None)
s,q=hoi(3); t=time.time(); o=r.predict(s,q); print('lần đầu',round(time.time()-t,1),'s'); print(json.dumps(o,ensure_ascii=False,default=str)[:1500])
dung=0; ra=[]; t=time.time()
for i in sorted(VANG):
    s,q=hoi(i); o=r.predict(s,q); a=o['answers']['nguoi_noi']; a=(a['choice'],round(a['confidence'],3))
    ra.append((i,a[0],VANG[i],a[1]))
tg=time.time()-t
json.dump(ra,open('ket_qua.json','w'),ensure_ascii=False,default=str)
print('tổng',round(tg,1),'s cho',len(ra),'câu')

d=[x for x in ra if x[1]==x[2]]; print('Laya đúng',len(d),'/',len(ra))
from collections import Counter
print('nhãn đã chọn:',Counter(x[1] for x in ra))
cao=[x for x in ra if x[3]>=0.9]; print('tin cậy >=0.9:',len(cao),'câu, đúng',sum(x[1]==x[2] for x in cao))
for x in ra[:25]: print(x)
