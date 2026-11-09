# 雨课堂自动刷课

自动完成雨课堂的**视频**、**PPT 课件**、**PPT 内嵌视频**，2 倍速播放，跨课程自动切换，断点续刷。

作业、图文、讨论、各类题目会被自动跳过（需要你自己做）。

---

## ⬇️ 下载

**https://github.com/GPIO-PullUpTo-THEBEST/yuketang_autowatch/archive/refs/heads/main.zip**

点开就自动下载，解压到任意目录（**路径不要有空格**）。

---

## ⚠️ 三条铁律（不遵守会失败）

### 1. 调试用的 Chrome 窗口**不能关闭**

脚本靠这个窗口工作。关掉 = 脚本停摆。

### 2. 调试用的 Chrome 窗口**不能最小化**

Chrome 会节流最小化窗口里的定时器和渲染，视频会卡住不往前走。

- ✅ 可以：切到别的窗口、被别的窗口挡住、最大化、普通大小
- ❌ 不行：点最小化按钮

### 3. 可以正常用鼠标键盘

脚本走浏览器调试协议，不占用你的鼠标键盘。你可以开自己的浏览器上网、看视频、打游戏，都不受影响。

---

## 三个按钮

解压后目录里只有三个 `.bat`，按顺序用：

| 文件 | 什么时候用 |
|---|---|
| **`install.bat`** | **第一次**用，双击它 |
| **`start.bat`** | 以后每次开始刷课，双击它 |
| **`stop.bat`** | 想停下来，双击它 |

---

## 第一次使用

### 第 1 步：双击 `install.bat`

它会：
1. 找 Python（找不到会提示你去装）
2. 自动装依赖
3. 检查 Chrome
4. 启动 `start.bat`

> 需要 Python 3.8+。没装的话去 https://www.python.org/downloads/ 下载，
> **安装第一屏底部务必勾选 `Add python.exe to PATH`**。

### 第 2 步：Chrome 自动弹出后，登录雨课堂

`start.bat` 会自动：
1. 关掉你所有 Chrome 窗口
2. 用调试模式启动一个新 Chrome
3. 等你登录

在新 Chrome 里打开 https://www.yuketang.cn，扫码登录（只需第一次）。

登录好了回到黑色窗口，按任意键继续。

### 第 3 步：等它自己刷

黑色窗口滚动这样的日志就是在跑：

```
[23:36:50]   未完成 87 项: 图文35, 视频计分39, 讨论1, 作业12
[23:36:50]   下一个: [视频计分] 1.2.3毛泽东思想的主要内容
[23:36:52]   视频 839s
[23:36:52]   倍速: HOOKED rate=2
[23:37:12]   544/839s  rate=2
[23:37:52]   ★ 播完 (839s)
```

**这时候你可以去干别的，但别关也别最小化那个 Chrome。**

---

## 以后每次使用

```
双击 start.bat  →  等它跑
想停双击 stop.bat
```

不用再做 `install.bat`。

---

## 想停下来

双击 **`stop.bat`**，或者直接关掉黑色窗口。

进度会自动存在 `progress.json`，下次 `start.bat` 接着刷，不会重复。

---

## 常见问题

### 双击后闪一下就没了

Python 没装或没加到 PATH。去 https://www.python.org/downloads/ 重装，勾 `Add python.exe to PATH`。

装好后双击 `install.bat` 再试一次。

### 提示 `[ERROR] chrome.exe not found`

Chrome 装在非常规位置。用记事本打开 `start.bat`，把 `set "CHROME=..."` 那几行改成你电脑上 Chrome 的实际路径。

### Chrome 窗口被我不小心最小化了

最大化回去（**不要只是恢复，要点最大化按钮**），脚本会在几秒内自动恢复播放。日志里会看到它重新 `play()`。

### Chrome 被我不小心关了

双击 `stop.bat` 清掉残留进程，然后重新双击 `start.bat`。登录状态还在，不用重新扫码。

### 一直显示"课程列表加载中"

在 Chrome 里刷新一下雨课堂首页，确认是已登录状态。

### 日志里出现「无进展」「拉黑跳过」

正常。表示某项内容刷不动（通常是题目类），脚本会自动跳过它，继续下一项。

### 日志 10 分钟没有新内容

卡死了。双击 `stop.bat`，再双击 `start.bat`。

### Chrome 大版本更新后突然不能用了

删掉这个文件夹：

```
C:\Users\你的用户名\ykt-chrome-profile
```

然后重新双击 `start.bat`，重新扫码登录。

### 想从头再刷一遍

删掉 `progress.json`。

### 只想重刷某一门课

用记事本打开 `progress.json`，在 `courses_done` 数组里删掉那门课的名字。

---

## 它会做什么

```
课程列表
   ↓
课程页（未完成列表）
   ├─ 纯视频 ────→ 2 倍速播完
   ├─ PPT 课件 ──→ 逐页翻阅停留
   └─ PPT 视频 ──→ 点播放 → 2 倍速播完
   ↓
没有可刷内容 → 标记本课完成 → 下一门
   ↓
全部完成 → 自动退出
```

**自动跳过**：作业、图文、讨论、主观题、单选题、多选题、判断题、填空题、计算题、证明题。

---

## 文件说明

| 文件 | 作用 |
|---|---|
| `install.bat` | 首次安装 |
| `start.bat` | 开始刷课 |
| `stop.bat` | 停止 |
| `run_all.py` | 主程序 |
| `progress.json` | 进度记录（**别删，删了会重头刷**） |
| `requirements.txt` | Python 依赖清单 |

---

## 技术原理（想了解才看）

### 为什么 2 倍速能生效

直接改 `video.playbackRate = 2` 会被雨课堂播放器在 2 秒内重置回 1。

本项目劫持这个属性的 setter，让播放器的重置失效：

```js
var desc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, 'playbackRate');
Object.defineProperty(video, 'playbackRate', {
  get: function(){ return desc.get.call(video); },
  set: function(){ desc.set.call(video, 2); }   // 无视外部赋值
});
```

### 为什么必须用 Chrome 调试协议

Tampermonkey 在雨课堂的视频页和 PPT 页**注入不进去**——播放器只响应 `isTrusted=true` 的真实事件，脚本 `click()` 全被忽略。

试过无效的方案：`element.click()`、`dispatchEvent(MouseEvent)`、`dispatchEvent(PointerEvent)`、CDP `Input.dispatchMouseEvent`。

Chrome 调试协议（CDP）走浏览器原生通道，能绕过这个限制。

### 关键选择器

| 元素 | 用途 |
|---|---|
| `li.unfinished-study__item` | 课程页未完成条目 |
| `.unfinished-study__type-card` | 条目类型 |
| `.video-box` | PPT 页的视频容器，点中心才创建 `<video>` |
| `.pptThumbsSwiper .swiper-slide` | PPT 缩略图 |

---

## 免责声明

仅供个人学习与技术研究使用。使用产生的一切后果由使用者自行承担，请遵守所在学校及平台的相关规定。

## License

MIT
