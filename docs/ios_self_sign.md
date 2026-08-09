# iOS 自签构建

本分支以最后完整开源的 `release-v2.5.9` 为基础，补上了可配置的直播源，并修复了已经无法公开下载的依赖。生成的是未签名 IPA，需要使用自己的 Apple 证书、AltStore、SideStore 或 Sideloadly 重新签名后才能安装。

## 环境

- macOS 与完整 Xcode（只有 Command Line Tools 不够）
- Flutter 3.35.7（版本写在 `.fvmrc`）
- CocoaPods
- Bun

Homebrew 可安装 Flutter、CocoaPods 与 Bun：

```bash
brew install --cask flutter
brew install cocoapods
brew install oven-sh/bun/bun
```

首次安装 Xcode 后，请先打开一次 Xcode，让它完成组件安装并接受许可协议。

## 生成 IPA

```bash
./script/build_ios_ipa.sh
```

脚本会自动解析 Flutter 依赖、生成 Isar 代码、打包 JS 运行时和内置 JS 模板，然后执行无签名 iOS Release 构建。成功后的文件位于：

```text
build/ios/ipa/catmovie-2.5.9-dynamic-live-unsigned.ipa
```

如果本机没有完整 Xcode，可以把本分支推送到自己的 GitHub 仓库，在 Actions 页面手动运行 `Build unsigned iOS IPA`，完成后从 `catmovie-ios-unsigned` 构建产物中下载 IPA。

## 配置视频源与直播源

一个订阅文件可以同时包含苹果 CMS/JS 视频源和 M3U/TXT 直播源：

```json
{
  "sites": [
    {
      "id": "cms-demo",
      "name": "CMS 示例",
      "type": 0,
      "api": "https://example.com/api.php/provide/vod/"
    }
  ],
  "lives": [
    {
      "name": "M3U 直播",
      "url": "https://example.com/live.m3u",
      "type": 0
    },
    {
      "name": "TXT 直播",
      "url": "https://example.com/live.txt",
      "type": 1
    }
  ]
}
```

在“设置 → 扩展源”中填写订阅文件 URL 并同步，或者通过本地文件导入。`lives[].type` 为 `0` 时按 M3U 解析，为 `1` 时按 TXT 解析；即使 URL 没有文件扩展名也可正确识别。

## 安全提示

JS 扩展源相当于在应用内执行第三方代码，只使用你信任且能审查的配置。为了兼容仍使用 HTTP 的苹果 CMS 与 IPTV 地址，本分支允许 iOS 明文网络请求；优先选择 HTTPS 源，并避免在应用内填写敏感账号或 Cookie。
