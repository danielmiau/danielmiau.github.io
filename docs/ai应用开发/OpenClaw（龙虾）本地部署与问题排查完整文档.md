# OpenClaw（龙虾）本地部署与问题排查完整文档
## 版本信息
- OpenClaw 版本：`2026.4.27`
- 部署环境：Windows 11
- 目标模型：阿里云通义千问 `dashscope/qwen3.5-plus`

---

## 一、环境准备
### 1. 基础依赖检查
确保系统已安装以下环境（Windows 11 推荐）：
- PowerShell（管理员权限）
- 稳定网络（需能访问阿里云 DashScope 服务）
- 预留至少 2GB 磁盘空间

### 2. 下载 OpenClaw
从官方渠道获取 OpenClaw 安装包，解压到本地目录（例如 `E:\openclaw\openclaw`）。

---

## 二、首次部署与启动
### 1. 启动网关服务
以管理员身份打开 PowerShell，进入 OpenClaw 目录：
```powershell
cd E:\openclaw\openclaw
openclaw gateway run
```
- 正常启动后，会输出 `gateway ready` 日志
- 浏览器访问 `http://127.0.0.1:18789/` 即可打开管理面板

### 2. 配置模型（以通义千问为例）
1.  登录阿里云 DashScope，获取 API Key
2.  编辑配置文件 `C:\Users\你的用户名\.openclaw\providers.json`：
    ```json
    {
      "defaultModel": "dashscope/qwen3.5-plus",
      "providers": {
        "dashscope": {
          "type": "openai",
          "baseUrl": "https://dashscope.aliyuncs.com/compatible-mode/v1",
          "apiKey": "你的DashScope API Key"
        }
      }
    }
    ```

---

## 三、关键问题：启动卡顿/主线程阻塞
### 1. 问题现象
- 日志出现 `event_loop_delay`、`eventLoopUtilization=1` 警告
- 消息发送后延迟数分钟甚至无响应
- 界面加载缓慢，插件管理页面无法打开

### 2. 元凶定位
以下插件会导致 Windows 环境下的主线程阻塞：
- `active-memory`：后台频繁读写本地存储，占满主线程
- `bonjour`：mDNS 服务发现冲突，循环重试导致 CPU 占用过高
- `memory-core`/`phone-control`/`talk-voice`：非核心插件，易引发兼容性问题

### 3. 根治方案（命令行禁用插件）
1.  先彻底杀死所有进程：
    ```powershell
    taskkill /F /IM openclaw.exe /T
    taskkill /F /IM node.exe /T
    ```
2.  使用官方 CLI 命令禁用问题插件：
    ```powershell
    openclaw plugins disable active-memory
    openclaw plugins disable bonjour
    openclaw plugins disable memory-core
    openclaw plugins disable phone-control
    openclaw plugins disable talk-voice
    ```
3.  验证禁用结果：
    ```powershell
    openclaw plugins list
    ```
    输出中上述插件状态应显示为 `disabled`。

---

## 四、防止配置文件被自动重置
### 1. 问题现象
手动修改 `config.json` 后，启动 OpenClaw 配置被自动恢复为默认值。

### 2. 解决方案
1.  编辑 `C:\Users\你的用户名\.openclaw\config.json`，写入标准格式配置：
    ```json
    {
      "defaultModel": "dashscope/qwen3.5-plus",
      "maxContextTokens": 8192,
      "requestTimeout": 120000,
      "plugins": {
        "entries": {
          "active-memory": { "enabled": false },
          "bonjour": { "enabled": false },
          "memory-core": { "enabled": false },
          "phone-control": { "enabled": false },
          "talk-voice": { "enabled": false }
        }
      }
    }
    ```
2.  右键 `config.json` → 属性 → 勾选「只读」，防止启动时被重写。

---

## 五、启动验证与健康检查
### 1. 正常启动日志特征
- 无 `bonjour` 服务注册重试警告
- `eventLoopDelayMaxMs` 不超过 5000ms
- 日志显示 `gateway ready`、`heartbeat started`
- 模型加载日志：`agent model: dashscope/qwen3.5-plus`

### 2. 聊天功能验证
1.  打开管理面板，进入聊天界面
2.  新建会话，手动选择 `dashscope/qwen3.5-plus` 模型
3.  发送测试消息（如“你好，请问你用的是什么模型”）
4.  正常情况下，3-5秒内收到回复

---

## 六、后续维护与优化
### 1. 定期清理缓存
删除 `C:\Users\你的用户名\.openclaw\canvas` 目录，避免画布文件过多拖慢启动速度。

### 2. 降级到稳定版本（备选方案）
若当前版本仍有卡顿问题，可降级到社区反馈最稳定的 `2026.4.23` 版本，无主线程阻塞问题。

### 3. 常见问题排查清单
| 问题现象           | 排查步骤                                                     |
| :----------------- | :----------------------------------------------------------- |
| 消息一直加载中     | 1. 新建会话并手动选择模型<br>2. 点击红色方块按钮取消请求<br>3. 检查后台日志是否有模型调用报错 |
| 配置文件被重置     | 1. 确保已设置「只读」属性<br>2. 使用 `openclaw plugins disable` 命令禁用插件 |
| 启动后界面无法访问 | 1. 检查 `18789` 端口是否被占用<br>2. 关闭防火墙或添加端口例外 |

---

## 七、最终状态确认
完成以上步骤后，你的 OpenClaw 应满足：
- 后台日志无循环报错、无高延迟警告
- 聊天响应时间 ≤ 5秒
- 插件管理页面可正常加载
- 模型调用稳定，无超时或无响应问题

---

如果你需要，我可以帮你把文档里的所有命令整合成一个一键执行的 PowerShell 脚本，双击就能完成禁用插件+锁定配置的所有操作。