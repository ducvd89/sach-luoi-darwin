import re,glob,json,html
from laya import Agent
hp='\n'.join(open(f,encoding='utf8').read() for f in sorted(glob.glob('ch[0-9][0-9].txt'))+['chuong5.txt'])
def ldk(c):
    s=open(f'ldk/H{c:02d}.xhtml',encoding='utf8').read()
    return '\n'.join(re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>','',p))).strip() for p in re.findall(r'<p[^>]*>(.*?)</p>',s,flags=re.S))
ld='\n'.join(ldk(c) for c in range(3,12))
# (tên hiển thị, chuỗi tìm trong văn, giới thật, nguồn)
NV=[('Harry','Harry','nam',hp),('Ron','Ron','nam',hp),('Hermione','Hermione','nữ',hp),('Ginny','Ginny','nữ',hp),('Fred','Fred','nam',hp),
('Percy','Percy','nam',hp),('Bill','Bill','nam',hp),('Charlie','Charlie','nam',hp),('Arthur Weasley','ông Weasley','nam',hp),('Molly Weasley','bà Weasley','nữ',hp),
('Diggory','Diggory','nam',hp),('Bagman','Bagman','nam',hp),('Crouch','Crouch','nam',hp),('Winky','Winky','nữ',hp),('McGonagall','McGonagall','nữ',hp),
('Dumbledore','Dumbledore','nam',hp),('Moody','Moody','nam',hp),('Malfoy','Malfoy','nam',hp),('Trelawney','Trelawney','nữ',hp),('Neville','Neville','nam',hp),
('Maxime','Maxime','nữ',hp),('Karkaroff','Karkaroff','nam',hp),('Hagrid','Hagrid','nam',hp),('Snape','Snape','nam',hp),('Fleur','Fleur','nữ',hp),
('Krum','Krum','nam',hp),('Cedric','Cedric','nam',hp),('Parvati','Parvati','nữ',hp),('Lavender','Lavender','nữ',hp),('Sprout','Sprout','nữ',hp),
('Vi Tiểu Bảo','Vi Tiểu Bảo','nam',ld),('Khang Hy','Khang Hy','nam',ld),('Hải lão công','Hải lão công','nam',ld),('Ngao Bái','Ngao Bái','nam',ld),
('Thái hậu','Thái hậu','nữ',ld),('Nhụy Sơ','Nhụy Sơ','nữ',ld),('Sách Ngạch Đồ','Sách Ngạch Đồ','nam',ld),('Khang thân vương','Khang thân vương','nam',ld),
('Tiểu quận chúa','Tiểu quận chúa','nữ',ld),('Phương Di','Phương Di','nữ',ld),('Kiến Ninh công chúa','công chúa','nữ',ld),('Trần Cận Nam','Trần Cận Nam','nam',ld)]
def canh(van,k,n=4):
    v=[m.start() for m in re.finditer(re.escape(k),van)]
    if not v: return None
    chon=v[::max(1,len(v)//n)][:n]
    return ' […] '.join(van[max(0,p-160):p+200].replace('\n',' ') for p in chon)
NAM=r'\b(ông|anh|thầy|cụ|lão|chú|cậu|gã|hắn|thằng)\b'; NU=r'\b(bà|cô|chị|nàng|mụ|dì|con bé|cô bé|ả)\b'
def luat(c,k):
    a=b=0
    for m in re.finditer(re.escape(k),c):
        tr=c[max(0,m.start()-12):m.start()].lower()
        a+=bool(re.search(NAM+r'\s*$',tr)); b+=bool(re.search(NU+r'\s*$',tr))
    return 'nam' if a>b else 'nữ' if b>a else '?'
ds=[(t,k,g,canh(v,k)) for t,k,g,v in NV]; print('không thấy trong văn:',[t for t,k,g,c in ds if c is None]); ds=[d for d in ds if d[3]]
Q=lambda t:{'q':{'type':'choice','instructions':f'Is the character {t} in `passage` male or female?','criteria':{'nam':'male (nam giới)','nữ':'female (nữ giới)'}}}
print('luật xưng hô:',sum(luat(c,k)==g for t,k,g,c in ds),'/',len(ds),'| không quyết được:',sum(luat(c,k)=='?' for t,k,g,c in ds))
for ck,kw in [('convaiinnovations/laya',{'subfolder':'multilingual'}),('ck2',{})]:
    a=Agent(ck,**kw); d=0; sai=[]; dn=dnu=0
    for t,k,g,c in ds:
        o=a.predict({'passage':c},Q(t))['answers']['q']
        ok=o['choice']==g; d+=ok
        if g=='nữ': dnu+=ok
        else: dn+=ok
        if not ok: sai.append((t,round(o['confidence'],2)))
    nn=sum(g=='nam' for *_,g,_ in ds)
    print(f'{ck}: đúng {d}/{len(ds)} (nam {dn}/{nn}, nữ {dnu}/{len(ds)-nn}) sai: {sai}')
