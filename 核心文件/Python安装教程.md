# Python 安装教程（Windows）

**只用一种方法：一条命令，连按三个 y，装完。**

---

## 方式零（强烈推荐）：用仓库自带脚本，全自动

**双击仓库根目录里的 `PythonChrome安装状态检查（第一步，必点）.bat`**（和 `启动器（第二步，必点）.bat` 在同一级目录）。

它会自动：

- 检查本机是否已装 Python（含 PATH、pip 三项检查）和 Chrome
- 已装 → 直接提示"本机已装 Python / 本机已装 Chrome"，跳过安装
- 没装 → 自动下载官方离线包静默安装，**自动勾好 PATH 和 pip**，装完当场验证

全程不需要你敲任何命令，装完直接回到刷课工具点第一步即可。

> 下面手动安装的 winget 方法，是给不想用脚本的人准备的备选方案。

---

## 一、安装

### 第 1 步：打开命令行

按 **Win + R**，输入 `cmd`，回车。出现黑色窗口。

### 第 2 步：粘贴命令

复制下面这一行，在黑窗口里右键粘贴，然后回车：

```
winget install Python.Python.3.13 -e
```

### 第 3 步：一路按 y

接下来会连续问几次许可协议，**一路按 `y` 再回车，大概按三次 y**。

### 第 4 步：等黑框自己跑完

按完 y 之后会**再弹出一个黑色的命令行窗口**，里面滚动安装进度。

> ⚠️ **这个黑框不要关，也不要点 ×**
> 它是安装程序在工作，关掉就装不全。等它自己跑完消失即可。

### 第 5 步：关掉原窗口，重新开一个

**必须关掉最开始那个 cmd 窗口，重新按 Win+R 开一个新的**，否则读不到刚装的 Python。

---

## 二、验证

新窗口里输入：

```
python --version
```

显示 `Python 3.13.17` 就成功了。

再确认一下路径：

```
where python
```

正常应该显示：

```
C:\Users\你的用户名\AppData\Local\Programs\Python\Python313\python.exe
```

> 如果第一条显示的是 `...\Microsoft\WindowsApps\python.exe`，说明那是微软商店的假 Python，看下面「常见问题」。

---

## 三、版本说明

这条命令装的是 **Python 3.13.17**。

winget 软件仓库目前只有这几个版本：

| 命令里的版本号 | 实际安装版本 |
|---|---|
| `Python.Python.3.12` | 3.12.10 |
| `Python.Python.3.13` | 3.13.17 |
| `Python.Python.3.14` | 3.14.10 |

官网首页最新的 3.15.2 还没有进 winget 仓库，所以这里用 3.13。

**3.13.17 和 3.15.2 对本工具没有任何区别，都能跑。**

想装其它版本，把命令里的 `3.13` 换掉即可，例如：

```
winget install Python.Python.3.12 -e
winget install Python.Python.3.14 -e
```

---

## 四、常见问题

### 提示 `winget` 不是内部或外部命令

系统太旧，没有 winget。这种情况走官网手动装：

1. 打开 https://www.python.org/downloads/
2. 点黄色大按钮下载 **Python 3.15.2**（文件 `python-3.15.2-amd64.exe`）
3. 双击安装，**第一屏底部务必勾上 `Add python.exe to PATH`**
4. 点 `Install Now`，等完成
5. 重开 cmd 验证

### 输入 python 弹出微软商店

电脑里有微软商店的「假 Python」占位符。修法：

1. 按 **Win**，输入 `管理应用执行别名`，打开设置页
2. 找到 `python.exe` 和 `python3.exe`，把开关**关掉**
3. 重开 cmd，再试 `python --version`

### 装了但提示找不到 python

PATH 没生效。先确认**是不是新开的 cmd 窗口**。还是不行就重装一次：

```
winget uninstall Python.Python.3.13
winget install Python.Python.3.13 -e
```

### 想卸载

```
winget uninstall Python.Python.3.13
```

---

## 五、装好之后

回到仓库根目录，双击 `启动器（第二步，必点）.bat`，点 **「第一步 检查环境，安装依赖」**，看到全是 `[OK]` 就成了：

```
=== 检查环境 ===
[OK] Python: C:\Users\你的用户名\AppData\Local\Programs\Python\Python313\python.exe
[OK] Chrome: C:\Program Files\Google\Chrome\Application\chrome.exe
[OK] Python 3.13.17
[OK] 依赖已就绪（websockets）

环境检查完成，可以点第二步开始刷课。
```

---

## 速查

```
推荐         双击 PythonChrome安装状态检查（第一步，必点）.bat   （全自动）
装          winget install Python.Python.3.13 -e     （连按三次 y）
黑框         别关，等它跑完
验证         python --version      → Python 3.13.17
查位置       where python
卸载         winget uninstall Python.Python.3.13
假 python    设置 → 管理应用执行别名 → 关掉 python.exe / python3.exe
```

**记住三点**：

1. 装完必须**新开一个 cmd** 才算
2. 安装时的黑框**不能关**
3. `where python` 第一条不能是 `WindowsApps`
