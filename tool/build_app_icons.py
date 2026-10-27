"""Create platform launcher sizes from the original Pixso Think logo."""
from PIL import Image
from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
logo=Image.open(root/'assets/branding/think-logo.png').convert('RGBA')
base=Image.new('RGB',(1024,1024),'white')
logo.thumbnail((700,700),Image.Resampling.LANCZOS)
base.paste(logo,((1024-logo.width)//2,(1024-logo.height)//2),logo)
def save(path,size):
 base.resize((size,size),Image.Resampling.LANCZOS).save(root/path,optimize=True)
for density,size in [('mdpi',48),('hdpi',72),('xhdpi',96),('xxhdpi',144),('xxxhdpi',192)]:
 save(f'android/app/src/main/res/mipmap-{density}/ic_launcher.png',size)
for platform in ['ios','macos']:
 folder=Path(platform+'/Runner/Assets.xcassets/AppIcon.appiconset')
 for entry in json.loads((root/folder/'Contents.json').read_text())['images']:
  if entry.get('filename'):
   size=round(float(entry['size'].split('x')[0])*float(entry['scale'].rstrip('x')))
   save(folder/entry['filename'],size)
for filename,size in [('favicon.png',32),('icons/Icon-192.png',192),('icons/Icon-512.png',512),('icons/Icon-maskable-192.png',192),('icons/Icon-maskable-512.png',512)]:
 save('web/'+filename,size)
print('Think launcher icons generated from Pixso logo')
