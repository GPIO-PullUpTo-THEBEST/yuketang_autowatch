"""
雨课堂全自动刷课 · 合并版
处理三类内容：
  1. 纯视频   /ai-workspace/.../video/...        → 直接 <video>，劫持 2x
  2. PPT 课件 /v2/web/studentCards/.../ppt        → 点缩略图逐页停留
  3. PPT内嵌视频 (同上，含 .video-box)            → 先点播放按钮，再劫持 2x

用法:
    python run_all.py                 # 全自动
    python run_all.py --rate 1        # 1 倍速
    python run_all.py --dry           # 只看不点
    python run_all.py --course 32367036   # 只刷指定课程
"""
import sys, asyncio, json, urllib.request, time, io, re, os

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.path.insert(0, '.')

import websockets

CDP_PORT = int(os.environ.get('YKT_CDP_PORT', '9222'))
HERE = os.path.dirname(os.path.abspath(__file__))
PROGRESS_FILE = os.environ.get('YKT_PROGRESS', os.path.join(HERE, 'progress.json'))

CFG = {
    'rate': float(os.environ.get('YKT_RATE', '2')),
    'poll': 5,
    'ppt_dwell': float(os.environ.get('YKT_PPT_DWELL', '4')),
    'max_one_item': 3600,   # 单个内容最长等 1 小时
    'home': 'https://www.yuketang.cn/v2/web/index',
}

# 课程卡片识别正则（默认适配 "2026秋-XXX" / "2026春-XXX" 这种课序号）
COURSE_CODE_RE = os.environ.get('YKT_COURSE_CODE_RE', r'20\d{2}[秋春]-')
# 注入到 JS 单引号字符串时必须转义反斜杠，否则 \d 会被 JS 解析成 d
COURSE_CODE_JS = COURSE_CODE_RE.replace('\\', '\\\\').replace("'", "\\'")

args = sys.argv[1:]
if '--rate' in args:
    CFG['rate'] = float(args[args.index('--rate') + 1])
ONLY_COURSE = args[args.index('--course') + 1] if '--course' in args else None
DRY = '--dry' in args


def log(*a):
    print(f"[{time.strftime('%H:%M:%S')}]", *a, flush=True)


# ==================== CDP ====================
class CDP:
    def __init__(self):
        self.ws = None
        self.mid = 0

    async def connect(self):
        tabs = json.loads(urllib.request.urlopen(
            f'http://127.0.0.1:{CDP_PORT}/json/list', timeout=5).read())
        # 优先找雨课堂标签
        page = None
        for x in tabs:
            if x.get('type') == 'page' and 'yuketang' in (x.get('url') or ''):
                page = x
                break
        if not page:
            raise RuntimeError('没有雨课堂标签页')
        self.ws = await websockets.connect(page['webSocketDebuggerUrl'], max_size=32 * 1024 * 1024)
        await self.send('Runtime.enable')
        await self.send('Page.enable')
        log('CDP 已连接:', (page.get('url') or '')[:70])

    async def send(self, method, params=None):
        self.mid += 1
        mid = self.mid
        await self.ws.send(json.dumps({'id': mid, 'method': method, 'params': params or {}}))
        while True:
            raw = await asyncio.wait_for(self.ws.recv(), timeout=30)
            m = json.loads(raw)
            if m.get('id') == mid:
                if 'error' in m:
                    raise RuntimeError(f"{method}: {m['error']}")
                return m.get('result', {})

    async def ev(self, expr, await_promise=False):
        r = await self.send('Runtime.evaluate', {
            'expression': expr, 'returnByValue': True,
            'awaitPromise': await_promise, 'userGesture': True
        })
        if 'exceptionDetails' in r:
            raise RuntimeError('JS: ' + str(r['exceptionDetails'].get('exception', r['exceptionDetails']))[:200])
        return r.get('result', {}).get('value')

    async def click(self, x, y):
        """CDP 真实坐标点击（CSS 像素）"""
        for ty, extra in [('mouseMoved', {}),
                          ('mousePressed', {'button': 'left', 'clickCount': 1}),
                          ('mouseReleased', {'button': 'left', 'clickCount': 1})]:
            await self.send('Input.dispatchMouseEvent',
                            dict({'type': ty, 'x': x, 'y': y}, **extra))
            await asyncio.sleep(0.1)

    async def goto(self, url, pattern=None, timeout=40):
        await self.send('Page.navigate', {'url': url})
        t0 = time.time()
        while time.time() - t0 < timeout:
            await asyncio.sleep(0.7)
            try:
                u = await self.ev('location.href')
            except Exception:
                continue
            if pattern is None or pattern in (u or ''):
                return u
        return await self.ev('location.href')

    async def close(self):
        try:
            await self.ws.close()
        except Exception:
            pass


# ==================== 页面 JS ====================
JS_URL = 'location.href'

# --- 课程列表 ---
JS_COURSES = r"""
JSON.stringify((function(){
  var CODE_RE = '%s';
  var all = [];
  document.querySelectorAll('div').forEach(function(d){
    var t = d.innerText || '';
    if (!new RegExp(CODE_RE).test(t)) return;
    var r = d.getBoundingClientRect();
    if (r.height < 80 || r.width < 180) return;
    all.push(d);
  });
  var leaf = all.filter(function(d){
    return !all.some(function(o){ return o !== d && d.contains(o); });
  });
  var out = [], seen = {};
  leaf.forEach(function(el, i){
    var lines = (el.innerText||'').split('\n').map(function(s){return s.trim();}).filter(Boolean);
    var name = lines[0];
    if (!name || seen[name]) return;
    seen[name] = 1;
    out.push({name: name, idx: i});
  });
  return out;
})())
"""

JS_CLICK_COURSE = r"""
(function(idx){
  var CODE_RE = '%s';
  var all = [];
  document.querySelectorAll('div').forEach(function(d){
    var t = d.innerText || '';
    if (!new RegExp(CODE_RE).test(t)) return;
    var r = d.getBoundingClientRect();
    if (r.height < 80 || r.width < 180) return;
    all.push(d);
  });
  var leaf = all.filter(function(d){
    return !all.some(function(o){ return o !== d && d.contains(o); });
  });
  if (idx < 0 || idx >= leaf.length) return 'OUT_OF_RANGE:' + leaf.length;
  var el = leaf[idx];
  var lines = (el.innerText||'').split('\n').map(function(s){return s.trim();}).filter(Boolean);
  el.scrollIntoView({block:'center'});
  el.click();
  return 'CLICKED:' + (lines[0] || '?');
})(%d)
"""

# --- 课程页：课程名 ---
JS_COURSE_NAME = r"""
(function(){
  var CODE_RE = '%s';
  var cands = [];
  document.querySelectorAll('.title-inner-wrapper').forEach(function(e){
    var t = (e.textContent || '').trim();
    if (!t) return;
    if (new RegExp(CODE_RE).test(t)) return;
    var r = e.getBoundingClientRect();
    cands.push({t: t, y: r.top});
  });
  if (cands.length) {
    cands.sort(function(a, b){ return a.y - b.y; });
    return cands[0].t;
  }
  var fb = '';
  document.querySelectorAll('div,span').forEach(function(e){
    if (fb) return;
    if (e.children.length > 1) return;
    var t = (e.textContent || '').trim();
    if (!t || t.length > 30) return;
    if (new RegExp(CODE_RE).test(t)) return;
    if (/学习日志|课件|作业|讨论|公告|成绩单/.test(t)) return;
    var r = e.getBoundingClientRect();
    if (r.top > 0 && r.top < 120 && r.width > 40) fb = t;
  });
  return fb;
})()
"""

# --- 课程页：读学习进度百分比 ---
JS_COURSE_PROGRESS = r"""
(function(){
  var pct = null, units = null;
  // 左侧环形图里的百分比
  document.querySelectorAll('*').forEach(function(e){
    if (e.children.length > 1) return;
    var t = (e.textContent || '').trim();
    if (pct === null && /^\d+(\.\d+)?%$/.test(t) && t.length <= 7) {
      var r = e.getBoundingClientRect();
      if (r.width > 0 && r.top < 700) pct = t;
    }
    if (units === null) {
      var m = t.match(/^(\d+)\s*\/\s*(\d+)$/);
      if (m && parseInt(m[2]) > 5) units = t;
    }
  });
  return pct + '|' + (units || '');
})()
"""

# --- 课程页：列出所有未完成项（带类型）---
JS_ITEMS = r"""
JSON.stringify((function(){
  var out = [];
  document.querySelectorAll('li.unfinished-study__item').forEach(function(li, i){
    var t = li.innerText || '';
    if (/已完成/.test(t)) return;
    var card = li.querySelector('.unfinished-study__type-card');
    var type = card ? card.textContent.trim() : '';
    var lines = t.split('\n').map(function(s){return s.trim();}).filter(Boolean);
    var title = '';
    for (var k = 0; k < lines.length; k++) {
      if (lines[k] === type) continue;
      if (/^\d+\s*\/\s*\d+\s*[页]?$/.test(lines[k])) continue;
      if (/截止/.test(lines[k])) continue;
      if (/计分|未开始|未完成|进行中|已完成/.test(lines[k])) continue;
      title = lines[k];
      break;
    }
    out.push({idx: i, type: type, title: title || '?', raw: t.replace(/\n/g,'|').slice(0,80)});
  });
  return out;
})())
"""

# --- 课程页：点击第一个可处理项（课件 or 视频，排除跳过名单）---
JS_CLICK_FIRST = r"""
(function(skipJson){
  var skip = [];
  try { skip = JSON.parse(skipJson) || []; } catch(e) { skip = []; }
  var list = Array.prototype.slice.call(document.querySelectorAll('li.unfinished-study__item'));
  for (var i = 0; i < list.length; i++) {
    var li = list[i], t = li.innerText || '';
    if (/已完成/.test(t)) continue;
    var card = li.querySelector('.unfinished-study__type-card');
    var type = card ? card.textContent.trim() : '';
    // 只处理 课件 / 视频
    if (!/课件|视频/.test(type)) continue;
    var lines = t.split('\n').map(function(s){return s.trim();}).filter(Boolean);
    var title = '';
    for (var k = 0; k < lines.length; k++) {
      if (lines[k] === type) continue;
      if (/^\d+\s*\/\s*\d+\s*[页]?$/.test(lines[k])) continue;
      if (/截止/.test(lines[k])) continue;
      if (/计分|未开始|未完成|进行中|已完成/.test(lines[k])) continue;
      title = lines[k];
      break;
    }
    // 题目类需要人工作答，跳过
    if (/主观题|客观题|单选题|多选题|判断题|选择题|简答题|论述题|填空题|计算题|证明题|问答题|不定项/.test(title)) continue;
    if (skip.indexOf(title) >= 0) continue;
    li.scrollIntoView({block:'center'});
    li.click();
    return 'CLICK:' + type + '|' + (title || '?');
  }
  return 'NONE';
})(%s)
"""

# --- 播放页状态 ---
JS_PLAYER_STATE = r"""
JSON.stringify((function(){
  var v = document.querySelector('video');
  return {
    hasVideo: !!v,
    rate: v ? v.playbackRate : null,
    paused: v ? v.paused : null,
    ended: v ? v.ended : null,
    t: v ? Math.round(v.currentTime) : 0,
    d: v ? Math.round(v.duration || 0) : 0
  };
})())
"""

# --- 劫持 2x ---
JS_HOOK = r"""
(function(){
  var v = document.querySelector('video');
  if (!v) return 'NO_VIDEO';
  var rate = %s;
  if (v.__yktHooked) {
    try { v.__yktDesc.set.call(v, rate); } catch(e){}
    return 'ALREADY rate=' + v.playbackRate;
  }
  var desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'playbackRate');
  if (!desc || !desc.set) return 'NO_DESC';
  v.__yktDesc = desc;
  Object.defineProperty(v, 'playbackRate', {
    configurable: true,
    get: function(){ return desc.get.call(v); },
    set: function(){ desc.set.call(v, rate); }
  });
  v.__yktHooked = true;
  try { desc.set.call(v, rate); } catch(e){}
  return 'HOOKED rate=' + v.playbackRate;
})()
"""

JS_PLAY = '(function(){var v=document.querySelector("video");if(!v)return "NO_VIDEO";v.play().catch(function(){});return "OK"})()'

# --- PPT 页：判断类型 ---
JS_PPT_INFO = r"""
JSON.stringify((function(){
  var box = document.querySelector('.video-box');
  var badge = document.querySelector('.watch_process');
  var thumbs = document.querySelectorAll('.pptThumbsSwiper .swiper-slide');
  var main = document.querySelector('.pptSwiper');
  return {
    hasVideoBox: !!box,
    boxRect: box ? (function(){ var r = box.getBoundingClientRect();
        return {cx: r.left + r.width/2, cy: r.top + r.height/2, w: Math.round(r.width), h: Math.round(r.height)}; })() : null,
    badge: badge ? badge.textContent.trim() : null,
    thumbCount: thumbs.length,
    hasSwiper: !!main,
    hasVideo: !!document.querySelector('video')
  };
})())
"""

# --- PPT 页：点第 n 张缩略图 ---
JS_PPT_GOTO = r"""
(function(n){
  var slides = document.querySelectorAll('.pptThumbsSwiper .swiper-slide');
  if (!slides.length) return 'NO_SLIDES';
  if (n >= slides.length) return 'OUT_OF_RANGE:' + slides.length;
  slides[n].click();
  return 'GOTO:' + n + '/' + slides.length;
})(%d)
"""

# --- PPT 页：当前页码 ---
JS_PPT_CUR = r"""
(function(){
  var active = document.querySelector('.pptThumbsSwiper .swiper-slide-active');
  var slides = document.querySelectorAll('.pptThumbsSwiper .swiper-slide');
  var idx = -1;
  for (var i = 0; i < slides.length; i++) if (slides[i] === active) { idx = i; break; }
  return idx;
})()
"""


# ==================== 进度存储 ====================
def load_progress():
    try:
        with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
            d = json.load(f)
            d.setdefault('courses_done', [])
            d.setdefault('course_ids', [])
            d.setdefault('items_done', {})
            d.setdefault('skipped', [])
            return d
    except Exception:
        return {'courses_done': [], 'course_ids': [], 'items_done': {}, 'skipped': []}


def save_progress(d):
    try:
        with open(PROGRESS_FILE, 'w', encoding='utf-8') as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
    except Exception:
        pass


# ==================== 业务 ====================
async def handle_video_page(cdp, ctx):
    """处理 ai-workspace 播放页"""
    st = json.loads(await cdp.ev(JS_PLAYER_STATE))
    if not st.get('hasVideo'):
        for _ in range(20):
            await asyncio.sleep(1)
            st = json.loads(await cdp.ev(JS_PLAYER_STATE))
            if st.get('hasVideo'):
                break
    if not st.get('hasVideo'):
        log('  ! 没有 video')
        return False

    if not st.get('d'):
        for _ in range(30):
            await asyncio.sleep(1)
            st = json.loads(await cdp.ev(JS_PLAYER_STATE))
            if st.get('d'):
                break

    log(f"  视频 {st['d']}s")
    if DRY:
        log('  (dry 不播放)')
        return True

    if CFG['rate'] != 1:
        log('  倍速:', await cdp.ev(JS_HOOK % CFG['rate']))

    await cdp.ev(JS_PLAY)
    return await monitor_video(cdp)


async def monitor_video(cdp, max_wait=None):
    """监控视频播完"""
    max_wait = max_wait or CFG['max_one_item']
    t0 = time.time()
    last = -1
    stuck = 0
    while time.time() - t0 < max_wait:
        await asyncio.sleep(CFG['poll'])
        try:
            s = json.loads(await cdp.ev(JS_PLAYER_STATE))
        except Exception:
            continue
        if not s.get('hasVideo'):
            log('  video 消失')
            return False
        if s.get('ended'):
            log(f"  ★ 播完 ({s['d']}s)")
            return True
        if s.get('paused'):
            await cdp.ev(JS_PLAY)
        if s['t'] == last:
            stuck += 1
            if stuck >= 8:
                log('  进度停滞，跳过')
                return False
        else:
            stuck = 0
        last = s['t']
        if int(s['t']) % 60 < CFG['poll']:
            log(f"  {s['t']}/{s['d']}s  rate={s['rate']}")
    log('  超时')
    return False


async def handle_ppt_page(cdp, ctx):
    """处理 studentCards PPT 页（可能有内嵌视频）"""
    info = json.loads(await cdp.ev(JS_PPT_INFO))
    log(f"  PPT: 缩略图 {info['thumbCount']} 张, 内嵌视频框={'有' if info['hasVideoBox'] else '无'}, 标记={info['badge']}")

    if DRY:
        log('  (dry 不操作)')
        return True

    # --- 情况 A：内嵌视频 ---
    if info['hasVideoBox']:
        # 已经有 video 在播就直接监控
        if info['hasVideo']:
            log('  video 已存在，直接接管')
        else:
            box = info['boxRect']
            log(f"  点击视频框中心 ({box['cx']:.0f},{box['cy']:.0f}) 播放")
            await cdp.click(box['cx'], box['cy'])
            await asyncio.sleep(2.5)
            st = json.loads(await cdp.ev(JS_PLAYER_STATE))
            if not st.get('hasVideo'):
                # 再点一次
                await cdp.click(box['cx'], box['cy'])
                await asyncio.sleep(2.5)
                st = json.loads(await cdp.ev(JS_PLAYER_STATE))
            if not st.get('hasVideo'):
                log('  ! 点了没出现 video，可能已看完')
                return True

        # 等时长
        for _ in range(30):
            st = json.loads(await cdp.ev(JS_PLAYER_STATE))
            if st.get('d'):
                break
            await asyncio.sleep(1)
        log(f"  内嵌视频 {st.get('d')}s")

        if CFG['rate'] != 1:
            log('  倍速:', await cdp.ev(JS_HOOK % CFG['rate']))
        await cdp.ev(JS_PLAY)
        return await monitor_video(cdp)

    # --- 情况 B：纯 PPT，逐页停留 ---
    n = info['thumbCount']
    if n <= 0:
        log('  ! 没有缩略图，可能不是 PPT 页')
        await asyncio.sleep(3)
        return True

    for i in range(n):
        r = await cdp.ev(JS_PPT_GOTO % i)
        if r != f'GOTO:{i}/{n}':
            log('  翻页失败:', r)
            break
        log(f'  第 {i+1}/{n} 页 · 停 {CFG["ppt_dwell"]}s')
        await asyncio.sleep(CFG['ppt_dwell'])
    return True


def course_url(cid):
    return (f'https://www.yuketang.cn/v2/web/studentLog/{cid}'
            f'?university_id=2910&platform_id=3&classroom_id={cid}'
            f'&content_url=&tab=unfinished')


def cid_from_player(url):
    m = re.search(r'/lms-graph/(\d+)/video/', url or '')
    if m:
        return m.group(1)
    m = re.search(r'/studentCards/(\d+)/', url or '')
    if m:
        return m.group(1)
    m = re.search(r'/studentLog/(\d+)', url or '')
    if m:
        return m.group(1)
    return None


async def ensure_course_url(cdp, ctx):
    """保证 ctx 里有可用的 course_url（从当前 URL 推导）"""
    if ctx.get('course_url') and 'studentLog' in (ctx['course_url'] or ''):
        return ctx['course_url']
    try:
        here = await cdp.ev(JS_URL) or ''
    except Exception:
        here = ''
    cid = cid_from_player(here) or ctx.get('cid')
    if cid:
        ctx['cid'] = cid
        ctx['course_url'] = course_url(cid)
        return ctx['course_url']
    return None


async def back_to_course(cdp, ctx):
    """回到课程页，失败则回主页"""
    cu = await ensure_course_url(cdp, ctx)
    if cu:
        log('  返回课程页')
        await cdp.goto(cu, 'studentLog')
        await asyncio.sleep(4)
        # 验证确实到了
        try:
            u = await cdp.ev(JS_URL)
        except Exception:
            u = ''
        if 'studentLog' in (u or ''):
            return True
        log('  ! 回课程页失败，回主页')
    await cdp.goto(CFG['home'], '/v2/web/index')
    await asyncio.sleep(5)
    return False


async def handle_course_page(cdp, ctx):
    """课程页：找下一个未完成项"""
    url = await cdp.ev(JS_URL) or ''
    ctx['course_url'] = url
    cid = cid_from_player(url)
    if cid:
        ctx['cid'] = cid

    if not ctx.get('course_name'):
        try:
            nm = await cdp.ev(JS_COURSE_NAME % COURSE_CODE_JS)
            if nm:
                ctx['course_name'] = nm
                log(f'  课程: {nm}')
        except Exception:
            pass

    # 确保在未完成 tab
    if 'tab=unfinished' not in url and cid:
        await cdp.goto(course_url(cid), 'studentLog')
        await asyncio.sleep(4)

    items = []
    for _ in range(10):
        raw = await cdp.ev(JS_ITEMS)
        try:
            items = json.loads(raw) if raw else []
        except Exception:
            items = []
        if items:
            break
        await asyncio.sleep(2)

    # 按类型统计
    by_type = {}
    for it in items:
        t = it['type'] or '其他'
        by_type[t] = by_type.get(t, 0) + 1

    # 判断上一轮点击是否产生进展
    prev_title = ctx.get('last_title')
    prev_count = ctx.get('last_item_count')
    if prev_title and prev_count is not None:
        if len(items) >= prev_count:
            fc = ctx.setdefault('fail_count', {})
            fc[prev_title] = fc.get(prev_title, 0) + 1
            log(f"  ⚠ 「{prev_title[:24]}」无进展 ({fc[prev_title]} 次)")
            if fc[prev_title] >= 2:
                ctx.setdefault('skip_titles', set()).add(prev_title)
                log(f"  → 拉黑跳过")
        else:
            ctx.setdefault('fail_count', {})[prev_title] = 0
        ctx['last_title'] = None
        ctx['last_item_count'] = None

    # 读学习进度
    try:
        pr = await cdp.ev(JS_COURSE_PROGRESS)
        if pr:
            pct, units = (pr.split('|') + ['', ''])[:2]
            log(f'  学习进度 {pct}  已完成单元 {units}')
            if pct == '100%' or pct == '100.00%':
                log('  🎉 本课程已达 100%')
    except Exception:
        pass

    log(f'  未完成 {len(items)} 项: ' + ', '.join(f'{k}{v}' for k, v in by_type.items()))

    # 计算可处理项（排除主观题类）
    SKIP_PAT = re.compile(r'主观题|客观题|单选题|多选题|判断题|选择题|简答题|论述题|填空题|计算题|证明题|问答题|不定项')
    skip_titles = set(ctx.get('skip_titles') or [])
    actionable = [it for it in items
                  if ('课件' in it['type'] or '视频' in it['type'])
                  and not SKIP_PAT.search(it['title'])
                  and it['title'] not in skip_titles]

    if not actionable:
        log('  ★ 本课程可刷内容已全部完成（剩余需人工处理）')
        left = [it for it in items if '课件' in it['type'] or '视频' in it['type']]
        if left:
            log('  剩余需人工: ' + ' | '.join(it['title'][:20] for it in left[:5]))
        done = ctx['progress']
        name = ctx.get('course_name', '')
        if name and name not in done['courses_done']:
            done['courses_done'].append(name)
        if cid and cid not in done['course_ids']:
            done['course_ids'].append(cid)
        save_progress(done)
        log(f"  累计完成 {len(done['courses_done'])} 门")
        ctx['course_name'] = None
        ctx['cid'] = None
        ctx['skip_titles'] = set()
        if DRY:
            return
        log('  回课程列表')
        await cdp.goto(CFG['home'], '/v2/web/index')
        await asyncio.sleep(5)
        return

    target = actionable[0]
    log('  下一个: [' + target['type'] + '] ' + target['title'][:40])
    if DRY:
        return

    # 记录"点击前"的项数，用于判断有无进展
    ctx['last_item_count'] = len(items)
    ctx['last_title'] = target['title']

    import json as _json
    r = await cdp.ev(JS_CLICK_FIRST % _json.dumps(list(skip_titles), ensure_ascii=False))
    log('  点击:', r)
    if not str(r).startswith('CLICK:'):
        log('  ! 点击失败（可能全部被跳过）')
        # 全部跳过 → 视为已完成
        return

    # 等页面跳转
    for _ in range(60):
        await asyncio.sleep(0.6)
        u = await cdp.ev(JS_URL)
        if 'studentCards' in (u or '') or 'ai-workspace' in (u or ''):
            log('  打开:', (u or '')[:70])
            await asyncio.sleep(3)
            return
    log('  ! 页面没打开')


async def handle_index(cdp, ctx):
    """课程列表：选下一门课"""
    courses = []
    for attempt in range(15):
        raw = await cdp.ev(JS_COURSES % COURSE_CODE_JS)
        try:
            courses = json.loads(raw) if raw else []
        except Exception:
            courses = []
        if courses:
            break
        if attempt == 0:
            log('  课程列表加载中…')
        await asyncio.sleep(2)

    if not courses:
        log('  ! 读不到课程列表，跳过本轮')
        await asyncio.sleep(5)
        return None

    done = ctx['progress']['courses_done']
    todo = [c for c in courses if c['name'] not in done]
    log(f'  课程 {len(courses)} 门，已完成 {len(done)} 门，待处理 {len(todo)} 门')

    if ONLY_COURSE:
        todo = [c for c in todo if c['name'] and str(c.get('idx')) is not None]

    if not todo:
        log('★★★ 所有课程都处理完了')
        return 'FINISHED'

    target = todo[0]
    ctx['course_name'] = target['name']
    log(f"  进入课程: {target['name']} (idx={target['idx']})")
    if DRY:
        return None

    r = await cdp.ev((JS_CLICK_COURSE % COURSE_CODE_JS) % target['idx'])
    log('  点击:', r)
    for _ in range(60):
        await asyncio.sleep(0.6)
        u = await cdp.ev(JS_URL)
        if 'studentLog' in (u or ''):
            if 'tab=unfinished' not in (u or ''):
                await cdp.goto(u + ('&' if '?' in u else '?') + 'tab=unfinished', 'tab=unfinished')
            log('  进入课程页')
            await asyncio.sleep(4)
            return None
    log('  ! 课程页没打开')
    return None


async def main():
    cdp = CDP()
    await cdp.connect()
    ctx = {'progress': load_progress(), 'course_name': None, 'cid': None, 'course_url': None}

    log(f"启动 rate={CFG['rate']} dry={DRY}")
    log('已完成课程:', ctx['progress']['courses_done'])

    rounds = 0
    last_url = ''
    same_count = 0
    while rounds < 5000:
        rounds += 1
        if DRY and rounds > 8:
            log('(dry 轮次上限)')
            break
        try:
            url = await cdp.ev(JS_URL) or ''
        except Exception as e:
            log('取 URL 失败:', str(e)[:60])
            await asyncio.sleep(2)
            continue

        # 同一页面反复访问保护（防止原地打转）
        if url == last_url:
            same_count += 1
        else:
            same_count = 0
            last_url = url
        if same_count >= 3:
            log(f'  ! 同一页面已停留 {same_count+1} 轮，强制回课程页')
            same_count = 0
            await back_to_course(cdp, ctx)
            continue

        try:
            if 'studentCards' in url:
                log('--- PPT 页 ---')
                ok = await handle_ppt_page(cdp, ctx)
                await back_to_course(cdp, ctx)
            elif 'ai-workspace' in url and '/video/' in url:
                log('--- 视频播放页 ---')
                await handle_video_page(cdp, ctx)
                await back_to_course(cdp, ctx)
            elif 'studentLog' in url:
                log('--- 课程页 ---')
                await handle_course_page(cdp, ctx)
            elif '/v2/web/index' in url or url.rstrip('/').endswith('/v2/web'):
                log('--- 课程列表 ---')
                r = await handle_index(cdp, ctx)
                if r == 'FINISHED':
                    break
            else:
                log('未知页面，回主页:', url[:60])
                await cdp.goto(CFG['home'], '/v2/web/index')
                await asyncio.sleep(4)
        except Exception as e:
            log('!! 异常:', str(e)[:150])
            await asyncio.sleep(3)

    log('===== 结束 =====')
    await cdp.close()


if __name__ == '__main__':
    asyncio.run(main())
