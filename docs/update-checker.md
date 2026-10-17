# GitHub Release 更新检查方案

## 目标

在 DLL 加载成功并完成 Hook 安装后，按配置异步检查 GitHub 最新 Release。有新版本时只弹窗提醒，并在用户确认后打开 GitHub Release 页面，不自动下载文件。

## 默认行为

默认不联网：

```json
"updates": {
  "enabled": false,
  "check_delay_ms": 15000,
  "timeout_ms": 5000,
  "notify_once": true,
  "allow_insecure_mirrors": true,
  "mirrors": [
    "https://wget.la/",
    "https://rapidgit.jjda.de5.net/",
    "https://fastgit.cc/",
    "https://gitproxy.mrhjx.cn/",
    "https://github.boki.moe/",
    "https://github.ednovas.xyz/"
  ]
}
```

## 工作流程

1. `src/main.cpp` 在 `Hooks::Install()` 和加载成功提示之后调用 `UpdateChecker::StartAsync()`。
2. `src/update/UpdateChecker.cpp` 先检查 `updates.enabled`，关闭时直接返回。
3. 开启后创建后台线程，先等待 `updates.check_delay_ms`。
4. 线程使用 WinHTTP 请求 GitHub latest release API：
   `https://api.github.com/repos/yuaotian/antigravity-proxy/releases/latest`
5. 直连失败后，按 `updates.mirrors` 顺序拼接代理站前缀重试。
6. 成功解析 `tag_name/html_url/body` 后，与 `config.json` 中 `_version` 比较。
7. 如果发现新版本，弹窗展示版本和发布说明摘要；用户点击“是”后打开 Release 页面。

## 安全边界

- 不自动下载 zip。
- 不自动替换 `version.dll`。
- 默认关闭，不增加 release 默认联网行为面。
- `allow_insecure_mirrors` 只作用于代理站请求，直连 GitHub 不忽略证书错误。
- `notify_once=true` 时，同一新版本只提醒一次，标记文件写入日志目录的 `update-notify.marker`。

## 验证方式

可使用 `tools/test-github-release-update.ps1` 单独测试 Release API 与代理站可达性。该脚本只发起 GET 请求并输出状态，不下载 Release 资产。
