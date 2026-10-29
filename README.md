# Voxtype Hub

[English](README.md) | [简体中文](README.zh-CN.md)

Voxtype Hub is an Omarchy Shell plugin for managing Voxtype transcription profiles, AI post-processing, speech models, and local usage history.

## Requirements

- Omarchy with Omarchy Shell and its plugin commands
- Voxtype installed and configured
- Python 3.11 or later
- An API key for an OpenAI-compatible provider if AI post-processing is enabled

## Installation

From the project directory, run:

```sh
bin/install-plugin
omarchy plugin enable daniel.voxtypehub --section right
```

The installer validates and copies the plugin to `${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/daniel.voxtypehub`, installs the helper scripts in `~/.local/bin`, and asks the Shell to rescan plugins. It does not modify your Voxtype settings, prompts, API keys, history, or active profile. Run `bin/install-plugin` again after changing the plugin or its helpers.

To use AI post-processing, configure Voxtype to run the installed helper. In `~/.config/voxtype/config.toml`, set the following under `[output.post_process]`, replacing `<username>` with your actual home-directory name:

```toml
[output.post_process]
command = "/home/<username>/.local/bin/voxtype-deepseek"
timeout_ms = 30000
```

Use your existing `[output.post_process]` section if one is already present; TOML sections must not be duplicated. Existing per-profile post-processing commands can override this setting. Restart the Voxtype daemon after changing its configuration.

## Using the panel

- **Prompt**: enable or disable AI post-processing; add, rename, delete, and select input profiles; edit and save each profile's prompt. At least one profile must remain.
- **Providers**: add a provider from a preset or enter an OpenAI-compatible chat-completions URL, model, and API key. Fetch the provider's model list when supported, or enter a model manually. Select a provider to activate it. At least one provider must remain; deleting one also removes its stored key.
- **Speech models**: select an installed Voxtype model. Model installation and removal are managed by Voxtype.
- **History**: view and delete individual recent post-processing records. The panel displays the latest 200 records.
- **Statistics**: view post-processing activity for the last 7, 30, or 90 days, or all time. Overview totals include all records in the selected range; the all-time trend shows the latest 12 months.

When post-processing is disabled, Voxtype outputs the original transcription and those bypassed transcriptions are not included in this plugin's history or statistics. Save or discard prompt and provider edits before leaving their page.

## Languages

The interface follows the Omarchy language setting and includes English and Simplified Chinese. Other languages fall back to English. Custom profile names, prompts, and other user-entered content are not translated.

## Data and privacy

Settings, prompts, API keys, and history are stored locally under `~/.config/voxtype`. API keys and transcriptions are private; do not commit them to version control. When post-processing is enabled, transcription text is sent to the selected provider.

## Development

Plugin QML and translations live in `plugin/`; backend helpers live in `scripts/`. Run the backend tests with:

```sh
python3 -m unittest discover -s tests
```
