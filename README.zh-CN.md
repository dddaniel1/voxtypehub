# Voxtype Hub

[English](README.md) | [简体中文](README.zh-CN.md) | [项目主页](https://dddaniel1.github.io/voxtypehub/)

Voxtype Hub 是一个 Omarchy Shell 插件，用于管理 Voxtype 转写模式、大模型后处理、语音模型和本地使用记录。

## 环境要求

- 已安装 Omarchy、Omarchy Shell 及其插件命令
- 已安装并配置 Voxtype
- Python 3.11 或更高版本
- 启用大模型后处理时，需要兼容 OpenAI 接口的供应商及其 API 密钥

## 安装

在项目目录中运行：

```sh
bin/install-plugin
omarchy plugin enable daniel.voxtypehub --section right
```

安装脚本会校验插件，将其复制到 `${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/daniel.voxtypehub`，将辅助脚本安装到 `~/.local/bin`，并通知 Shell 重新扫描插件。安装不会修改已有的 Voxtype 设置、提示词、API 密钥、历史记录或当前模式。修改插件或辅助脚本后，再次运行 `bin/install-plugin` 即可重新安装。

要使用大模型后处理，需要让 Voxtype 调用已安装的辅助脚本。在 `~/.config/voxtype/config.toml` 的 `[output.post_process]` 中设置以下内容，并将 `<username>` 替换为实际的主目录用户名：

```toml
[output.post_process]
command = "/home/<username>/.local/bin/voxtype-deepseek"
timeout_ms = 30000
```

如果文件已有 `[output.post_process]`，请修改原有段落，不要重复添加。已有的模式专属后处理命令可能覆盖此设置。修改配置后重启 Voxtype 守护进程。

## 使用面板

- **提示词**：开启或关闭大模型后处理；新增、重命名、删除和选择输入模式；编辑并保存各模式的提示词。至少需要保留一个模式。
- **供应商**：使用预设或手动填写兼容 OpenAI 的 chat-completions 地址、模型和 API 密钥。供应商支持时可获取模型列表，也可手动输入模型。选择供应商即可启用；至少需要保留一个供应商，删除时其密钥也会被删除。
- **语音模型**：选择已安装的 Voxtype 模型。模型的安装和卸载由 Voxtype 管理。
- **历史**：查看和逐条删除近期后处理记录。面板最多显示最近 200 条。
- **统计**：查看最近 7、30、90 天或全部时间的后处理数据。概览汇总所选范围内的全部记录；全部时间的趋势图显示最近 12 个月。

关闭后处理时，Voxtype 直接输出原始转写，这些转写不会计入插件的历史和统计。离开页面前，请先保存或撤销提示词和供应商的修改。

## 语言

界面跟随 Omarchy 的语言设置，提供英文和简体中文；其他语言回退到英文。自定义模式名称、提示词和其他用户输入内容不会被翻译。

## 数据与隐私

设置、提示词、API 密钥和历史记录保存在本地 `~/.config/voxtype`。API 密钥和转写内容属于私人数据，请勿提交到版本控制。启用后处理时，转写文本会发送给所选供应商。

## 开发

插件 QML 和翻译文件位于 `plugin/`，后端辅助脚本位于 `scripts/`。运行后端测试：

```sh
python3 -m unittest discover -s tests
```
