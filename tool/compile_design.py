"""Compile a read-only Pixso export into deduplicated Flutter drawing data.

Coordinates remain in the original 375 × 812 design space. Shared paints and
vector paths are interned; photographs remain separate offline assets.
"""
import gzip
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'docs/design/raw/design.json'
raw = json.loads(SOURCE.read_text() if SOURCE.exists() else gzip.decompress(SOURCE.with_suffix('.json.gz').read_bytes()))
components = json.loads((SOURCE.parent / 'components.json').read_text())
styles, paths, style_index, path_index = [], [], {}, {}

def intern(value, table, index):
    key = json.dumps(value, sort_keys=True, separators=(',', ':'))
    if key not in index:
        index[key] = len(table)
        table.append(value)
    return index[key]

def rounded(value):
    if isinstance(value, float):
        return round(value, 3)
    if isinstance(value, list):
        return [rounded(v) for v in value]
    if isinstance(value, dict):
        return {k: rounded(v) for k, v in value.items() if k not in ('blendMode', 'imageThumbnail', 'originalImageWidth', 'originalImageHeight', 'hash')}
    return value

def compile_node(n):
    style = {k: rounded(v) for k, v in n.items() if k not in ('id', 'name', 'type', 'w', 'h', 'm', 'children', 'characters', 'vectorPaths')}
    style = {k: v for k, v in style.items() if not (k in ('isMask', 'clipsContent') and not v) and not (k in ('cornerRadius', 'topLeftRadius', 'topRightRadius', 'bottomLeftRadius', 'bottomRightRadius', 'strokeWeight') and v == 0) and not (k == 'opacity' and v == 1) and k != 'strokeCap'}
    if n.get('vectorPaths'):
        style['paths'] = [intern(p, paths, path_index) for p in n['vectorPaths']]
    out = {'id': n['id'], 'n': n['name'], 't': n['type'], 'w': round(n['w'], 3), 'h': round(n['h'], 3), 'm': rounded(n['m']), 's': intern(style, styles, style_index)}
    if n['id'] in components:
        out['component'] = components[n['id']]
    if 'characters' in n:
        out['text'] = n['characters']
    if n.get('children'):
        out['c'] = [compile_node(c) for c in n['children']]
    return out

translations = ['引导与启动', '登录与注册', '社交与聊天', '导航菜单', '个人主页', '动态与文章', '音乐与影像', '统计与效率', '商城与支付', '旅行与出行', '弹窗与反馈']
pages = []
for page, title in zip(raw['pages'], translations):
    # Pixso's child array is opposite the visible layer-panel order.
    pages.append({'id': page['id'], 'name': page['name'], 'title': title, 'screens': [compile_node(n) for n in reversed(page['screens'])]})
images = {p.stem: str(p.relative_to(ROOT)) for p in (ROOT / 'assets/design').iterdir()}
out = {'name': raw['document'], 'pages': pages, 'styles': styles, 'paths': paths, 'images': images}
target = ROOT / 'assets/catalog/think.json'
target.write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')))
print(f'{sum(len(p["screens"]) for p in pages)} screens, {len(styles)} styles, {len(paths)} vector paths, {len(images)} photos; {target.stat().st_size:,} bytes')
