# Cách dùng luật thuần: tên đầu tiên trong câu dẫn ngay trước; không có thì
# nhìn câu ngay sau; vẫn không có thì lấy người nói cách đó hai lượt (thoại qua lại).
import re
from vang import *
L=open('chuong5.txt',encoding='utf8').read().split('\n')
TEN=[('Ông Weasley',r'[Ôô]ng Weasley'),('Bà Weasley',r'[Bb]à Weasley'),('Harry',r'Harry'),('Ron',r'Ron'),
     ('Hermione',r'Hermione'),('Ginny',r'Ginny'),('Fred',r'Fred'),('George',r'George'),('Percy',r'Percy'),
     ('Bill',r'Bill'),('Charlie',r'Charlie')]
def ten_dau(cau):
    best=None
    for n,p in TEN:
        m=re.search(p,cau)
        if m and (best is None or m.start()<best[0]): best=(m.start(),n)
    return best[1] if best else None
def cau_cuoi(t): return re.split(r'(?<=[.!?…])\s+',t)[-1]
def cau_dau(t): return re.split(r'(?<=[.!?…])\s+',t)[0]
def doan():
    ra={}; ls=[]
    for i in sorted(VANG):
        n=None
        tr=L[i-1]
        if not tr.startswith('“') and tr.endswith(':'): n=ten_dau(cau_cuoi(tr))
        if n is None and i+1<len(L) and not L[i+1].startswith('“') and not L[i+1].endswith(':'):
            n=ten_dau(cau_dau(L[i+1]))
        if n is None and len(ls)>=2: n=ls[-2]
        if n is None and ls: n=ls[-1]
        ra[i]=n; ls.append(n)
    return ra
if __name__=='__main__':
    ra=doan(); sai=[(i,ra[i],VANG[i]) for i in VANG if ra[i]!=VANG[i]]
    print('luật: đúng',len(VANG)-len(sai),'/',len(VANG)); 
    for s in sai: print(s)
