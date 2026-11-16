import time,re
from laya import Router
from vang import *
import luat
L=open('chuong5.txt',encoding='utf8').read().split('\n')
TRAN={n:n for n in NHAN}
def ung_vien(i):  # chỉ những tên có mặt trong cửa sổ
    cua=' '.join(L[max(0,i-6):i+2]); c=[n for n,p in luat.TEN if re.search(p,cua)]
    return c if len(c)>=2 else NHAN
def A(i): # ngữ cảnh 3 dòng, lệnh tiếng Việt
    return {'truoc':'\n'.join(L[max(0,i-3):i]),'cau_thoai':L[i],'sau':L[i+1] if i+1<len(L) else ''},'Ai là người nói câu trong `cau_thoai`?',NHAN
def B(i): # một khối văn, lệnh tiếng Anh
    return {'passage':'\n'.join(L[max(0,i-3):i+2]),'quote':L[i]},'Which character speaks the `quote` in the `passage`?',NHAN
def C(i): # chỉ dòng dẫn ngay trước + câu thoại
    return {'text':L[i-1]+' '+L[i]},'Who is speaking in `text`?',NHAN
def D(i): # như B nhưng chỉ đưa tên có trong cửa sổ
    return {'passage':'\n'.join(L[max(0,i-3):i+2]),'quote':L[i]},'Which character speaks the `quote` in the `passage`?',ung_vien(i)
r=Router(max_loaded=3)
for ten,f in [('A',A),('B',B),('C',C),('D',D)]:
    for mo in ['multilingual','english','typed-decisions']:
        t=time.time(); d=0; dc=nc=0
        for i in sorted(VANG):
            s,ins,ds=f(i)
            a=r.predict(s,{'q':{'type':'choice','instructions':ins,'criteria':{n:n for n in ds}}},model=mo)['answers']['q']
            ok=a['choice']==VANG[i]; d+=ok
            if a['confidence']>=0.9: nc+=1; dc+=ok
        print(f'{ten} {mo:16s} đúng {d}/90   tin cậy>=0.9: {dc}/{nc}   {time.time()-t:.1f}s',flush=True)
