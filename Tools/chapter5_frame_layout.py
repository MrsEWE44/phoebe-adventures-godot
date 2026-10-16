"""Read source silhouettes to author atlas regions; never rewrite source pixels."""
from pathlib import Path
import numpy as np
from PIL import Image

def foreground(image):
    pixels=np.asarray(image)
    return pixels[:,:,3]>224 if image.mode=='RGBA' else pixels[:,:,:3].min(axis=2)<230

def components(mask):
    """Connected components of horizontal runs, without a scipy dependency."""
    parents=[]; boxes=[]; areas=[]; previous=[]
    def root(i):
        while parents[i]!=i:
            parents[i]=parents[parents[i]];i=parents[i]
        return i
    for y,row in enumerate(mask):
        edges=np.flatnonzero(np.diff(np.pad(row.astype(np.int8),(1,1))))
        current=[];j=0
        for x0,x1 in edges.reshape(-1,2):
            label=len(parents);parents.append(label);boxes.append([int(x0),y,int(x1),y+1]);areas.append(int(x1-x0))
            while j<len(previous) and previous[j][1]<x0: j+=1
            k=j
            while k<len(previous) and previous[k][0]<=x1:
                other=root(previous[k][2]);label=root(label)
                if other!=label:
                    parents[other]=label
                    a=boxes[label];b=boxes[other]
                    boxes[label]=[min(a[0],b[0]),min(a[1],b[1]),max(a[2],b[2]),max(a[3],b[3])]
                    areas[label]+=areas[other]
                k+=1
            current.append((x0,x1,label))
        previous=current
    return sorted([(areas[i],boxes[i]) for i in range(len(parents)) if root(i)==i],reverse=True)

def layout(image):
    boxes=[b for area,b in components(foreground(image)) if area>image.width*image.height*.012]
    # Discard clipped edge characters and leftover fragments from neighbouring sheets.
    boxes=[b for b in boxes if b[0]>1 and b[2]<image.width-1]
    rows=[]
    for box in sorted(boxes,key=lambda b:b[1]):
        if not rows or box[1]-rows[-1][0][1]>image.height*.15: rows.append([])
        rows[-1].append(box)
    assert len(rows)==3, ('Expected three directional rows',rows)
    for row in rows:
        row.sort(key=lambda b:b[0])
        assert 3<=len(row)<=4, ('Expected three or four intact poses',row)
    # Regions follow real silhouettes. Atlas margins align all frames to a common
    # bottom centre, without resampling or changing any source image pixels.
    rows=[[[max(0,b[0]-1),max(0,b[1]-1),min(image.width,b[2]+1),min(image.height,b[3]+1)] for b in row] for row in rows]
    width=max(b[2]-b[0] for row in rows for b in row)+8
    height=max(b[3]-b[1] for row in rows for b in row)+8
    return rows,width,height

if __name__=='__main__':
    root=Path(__file__).resolve().parents[1]
    paths=list((root/'Art/Chapter5').glob('*_rgba.png'))+[root/'NextPlayer/初音未来精灵图.png']
    for folder in ['奶娃','袋鼠狗','肥袋鼠狗','奶娃狗','奶娃鼠']: paths+=list((root/'NextPlayer'/folder).glob('*.png'))
    for path in paths:
        image=Image.open(path)
        large=[b for area,b in components(foreground(image)) if area>image.width*image.height*.012]
        print(path.relative_to(root),len(large),sorted(large,key=lambda b:(b[1],b[0])))
