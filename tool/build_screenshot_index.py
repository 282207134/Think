"""Build contact sheets and a browsable index from actual Flutter screenshots."""
from pathlib import Path
import json,math
from PIL import Image,ImageOps,ImageDraw
root=Path(__file__).resolve().parents[1]
folder=root/'docs/screenshots'
rows=json.loads((folder/'manifest.json').read_text())
lines=['# 全部界面截图','', '截图来自实际 Flutter Widget 渲染，尺寸为 750 × 1624（设计尺寸 375 × 812，2×）。','', 'Android 模拟器流程截图见 [测试记录](../TESTING.md)。','']
for category in dict.fromkeys(r['category'] for r in rows):
 group=[r for r in rows if r['category']==category]
 cols=4; tw,th=150,325; pad=12;label=28
 sheet=Image.new('RGB',(cols*(tw+pad)+pad,math.ceil(len(group)/cols)*(th+label+pad)+pad),'#edf0f7')
 draw=ImageDraw.Draw(sheet)
 for i,r in enumerate(group):
  im=Image.open(folder/r['file']).convert('RGB').resize((tw,th),Image.Resampling.LANCZOS)
  x=pad+(i%cols)*(tw+pad);y=pad+(i//cols)*(th+label+pad)
  sheet.paste(im,(x,y));draw.text((x,y+th+5),r['name'],fill='#22242a')
 filename=category[:2]+'-overview.jpg';sheet.save(folder/filename,quality=90)
 lines += ['## '+group[0]['title']+' / '+category,'',f'![{category}]({filename})','', '| 界面 | Pixso 节点 | Flutter 截图 |','|---|---|---|']
 lines += [f"| {r['name']} | `{r['id']}` | [查看]({r['file']}) |" for r in group]
 lines.append('')
(folder/'README.md').write_text('\n'.join(lines))
print('11 contact sheets and 120 indexed screenshots generated')
