from laya import Router
from vang import *
import luat
L=open('chuong5.txt',encoding='utf8').read().split('\n')
r=Router(); ra=luat.doan()
sai=[i for i in VANG if ra[i]!=VANG[i]]
def chay(i,s):
    a=r.predict(s,{'q':{'type':'choice','instructions':'Who is speaking in `text`?','criteria':{n:n for n in NHAN}}},model='multilingual')['answers']['q']
    return a['choice'],round(a['confidence'],2)
print('11 câu luật sai — Laya (dòng trước + câu thoại | thêm dòng sau):')
c1=c2=0
for i in sai:
    a=chay(i,{'text':L[i-1]+' '+L[i]}); b=chay(i,{'text':L[i-1]+' '+L[i]+' '+L[i+1]})
    c1+=a[0]==VANG[i]; c2+=b[0]==VANG[i]
    print(i,'vàng:',VANG[i],'|',a,'|',b)
print('Laya chữa được',c1,'và',c2,'trên',len(sai))
