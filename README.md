# 雨课堂自动刷课 (Yuketang Auto Study)

通过 Chrome DevTools Protocol 自动完成雨课堂的**视频**、**PPT 课件**和**PPT 内嵌视频**，支持 2 倍速播放、跨课程自动切换、断点续刷。

> 需要自己作答的内容（作业、图文、讨论、各类题目）会被自动跳过，不会伪造。

---

## ⬇️ 一键下载安装

### 方式一：直接下载（推荐）

点这个链接，浏览器会自动下载**最新版**压缩包：

**https://github.com/GPIO-PullUpTo-THEBEST/yuketang_autowatch/archive/refs/heads/main.zip**

> 这个链接永远指向最新代码，不会过期。
> 想下带版本号的正式包：https://github.com/GPIO-PullUpTo-THEBEST/yuketang_autowatch/releases/latest

下载后：

1. 解压到任意目录（**路径不要有空格**）
2. 双击 `install.bat`
3. 它会自动：检查 Python → 下载依赖 → 启动 Chrome → 提示你登录 → 开始刷课

### 方式二：克隆仓库

```bash
git clone https://github.com/GPIO-PullUpTo-THEBEST/yuketang_autowatch.git
cd yuketang_autowatch
pip install -r requirements.txt
python run_all.py
```

### 方式三：Green Code 按钮

在仓库首页点绿色 **Code** 按钮 → **Download ZIP**。

---

## 使用

看到黑色窗口滚动这样的日志就说明在跑了：

```
[21:19:08] CDP 已连接: https://www.yuketang.cn/...
[21:19:48]   未完成 83 项: 视频4, 作业46, 图文23, 讨论10
[21:19:48]   下一个: [视频] 自觉学习和运用马克思主义
[21:19:58]   倍速: HOOKED rate=2
[21:20:28]   ★ 播完 (138s)
```

想停：

- 双击 `stop.bat`
- 或命令行 `Ctrl+C`

**详细图文教程见 [新手教程.md](新手教程.md)**（含 cmd 怎么开、每一步复制粘贴什么）。

---

## 特性

- **三类内容全覆盖**
  - 纯视频 → 接管 `<video>`，锁 2 倍速播放到结束
  - PPT 课件 → 逐页翻阅并停留
  - PPT 内嵌视频 → 自动点击播放按钮，再锁 2 倍速
- **2 倍速不被打回**：直接改 `video.playbackRate` 会被雨课堂播放器重置为 1。本项目通过劫持该属性的 setter，使播放器的重置失效
- **跨课程自动切换**：一门课刷完自动标记并进入下一门
- **断点续刷**：进度存 `progress.json`，重跑不重复
- **智能跳过**：作业 / 图文 / 讨论 / 主观题 / 单选题 / 多选题 / 判断题 / 填空题 / 计算题 / 证明题 等
- **卡死自愈**：同一项 2 次无进展自动拉黑；同一页面连续 3 轮自动跳走

## 为什么用 CDP 而不是油猴脚本

Tampermonkey 在雨课堂的 `/ai-workspace/`（视频页）和 `/v2/web/studentCards/`（PPT 页）**无法注入脚本**——播放器只响应 `isTrusted=true` 的事件，注入的 JS 全部被忽略。Chrome 调试协议走浏览器原生通道，不受此限制。

## 环境要求

| 项目 | 要求 |
|---|---|
| 系统 | Windows（使用了 `--user-data-dir` 独立配置目录；Linux/macOS 改一下启动参数即可） |
| Chrome | 136 及以上（旧版本可直接用默认配置目录开调试端口） |
| Python | 3.8+ |
| 依赖 | `pip install -r requirements.txt` |

> Chrome 136+ 禁止在默认配置目录开启远程调试，所以必须使用独立的 `--user-data-dir`。

## 快速开始

### 1. 准备

```bash
pip install -r requirements.txt
```

### 2. 关闭所有 Chrome 窗口，然后用调试模式启动

Windows CMD：

```bat
"C:\Program Files\Google\Chrome\Application\chrome.exe" ^
  --remote-debugging-port=9222 ^
  --user-data-dir=%USERPROFILE%\ykt-chrome-profile
```

PowerShell：

```powershell
& "C:\Program Files\Google\Chrome\Application\chrome.exe" `
  --remote-debugging-port=9222 `
  --user-data-dir="$env:USERPROFILE\ykt-chrome-profile"
```

### 3. 在打开的浏览器里登录雨课堂

访问 https://www.yuketang.cn 并扫码登录。

### 4. 运行

```bash
python run_all.py
```

或者直接双击 `start.bat`（Windows，会自动完成 2~4 步）。

停止：双击 `stop.bat` 或 `Ctrl+C`。

## 命令行参数

```bash
python run_all.py                  # 2 倍速全自动
python run_all.py --rate 1         # 1 倍速（不劫持）
python run_all.py --dry            # 只看不操作
python run_all.py --course 32367036  # 仅指定课程 ID（用于调试）
```

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `YKT_CDP_PORT` | `9222` | Chrome 调试端口 |
| `YKT_PROGRESS` | `./progress.json` | 进度文件路径 |
| `YKT_RATE` | `2` | 播放倍速 |
| `YKT_PPT_DWELL` | `4` | PPT 每页停留秒数 |
| `YKT_COURSE_CODE_RE` | `20\d{2}[秋春]-` | 课程卡片识别正则（不同学校课序号格式可能不同） |

## 工作原理

```
课程列表  ──点──▶  课程页（未完成 tab）
                      │
                      ├─ 纯视频  ──▶ ai-workspace/.../video  ──▶ 劫持 2x ──▶ 播完
                      ├─ PPT    ──▶ studentCards/.../ppt     ──▶ 逐页停留
                      └─ PPT视频 ──▶ 同上 + 点 .video-box 中心 ──▶ 劫持 2x ──▶ 播完
                      │
                      ▼
                  回课程页，继续下一个
                      │
                  没有可刷项 ──▶ 标记课程完成 ──▶ 回课程列表 ──▶ 下一门
```

关键选择器：

| 元素 | 用途 |
|---|---|
| `li.unfinished-study__item` | 课程页里的未完成条目 |
| `.unfinished-study__type-card` | 条目类型（课件 / 视频 / 作业 / 图文 / 讨论） |
| `.title-inner-wrapper` | 课程名（需排除形如 `2026秋-SSE038-7` 的课序号） |
| `.video-box` | PPT 页里的视频容器，点击其中心才会创建 `<video>` |
| `.pptThumbsSwiper .swiper-slide` | PPT 缩略图，点击切换页 |

## 注意事项

- **不要关闭调试实例的 Chrome 窗口**，脚本依赖它
- 可以正常使用鼠标键盘，脚本不占用输入设备
- 最小化窗口可以，但别关闭标签页
- Chrome 大版本更新后如失效，删除 `--user-data-dir` 指向的目录重新登录即可
- 删除 `progress.json` 会重新刷所有课程

## 免责声明

本项目仅供个人学习与技术研究使用。使用产生的一切后果由使用者自行承担，请遵守所在学校及平台的相关规定。

## License

MIT
