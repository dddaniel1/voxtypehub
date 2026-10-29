const translations = {
  en: {
    skip: 'Skip to content', nav_how: 'How it works', nav_features: 'Features', nav_setup: 'Get started', eyebrow: 'AN OMARCHY SHELL PLUGIN',
    headline: 'Your voice,<br><em>in its element.</em>', intro: 'A little more control over the words you speak. Switch profiles, choose a model, and shape your transcriptions without leaving your desktop.', get: 'Get Voxtype Hub', hero_foot: 'FROM THE BAR, INTO YOUR WORKFLOW', how_label: 'THE IDEA',
    story_title: 'Speak naturally.<br><em>Keep the control.</em>', story_body: 'Voxtype does the listening. Voxtype Hub gives you a place in the Omarchy bar to manage what happens next—from the active input profile to optional AI post-processing.', explore: 'Explore the documentation',
    features_label: 'THE TOOLKIT', features_title: 'A better place<br><em>for the details.</em>', features_intro: 'Small controls, right where you need them.', f1_title: 'A profile for the moment.', f1_body: 'Create and switch input profiles, each with its own editable prompt. Make room for coding, conversation, or your own workflow.',
    f2_title: 'Your choice of provider.', f2_body: 'Configure OpenAI-compatible providers, pick a model, and switch between saved configurations. Turn post-processing off when you want the original transcription.', f3_title: 'Keep track, locally.', f3_body: 'Browse recent post-processing history and see your activity over time. Choose from the speech models already installed in Voxtype.',
    privacy_label: 'A CLEAR BOUNDARY', privacy_title: 'Your words.<br><em>Your choices.</em>', privacy_body: 'Settings, keys, prompts, and history stay on your machine. If AI post-processing is enabled, transcription text is sent to the provider you choose. You can switch it off to use the original transcription.',
    setup_label: 'GET STARTED', setup_title: 'Make it yours.<br><em>Start with the docs.</em>', setup_body: 'For Omarchy and Voxtype users. Follow the repository instructions to install the plugin and configure post-processing.', read_install: 'Read installation guide', setup_note: 'The current helper paths target the original installation and may need adjustment on other systems.', footer: 'A small companion for Voxtype on Omarchy.'
  },
  zh: {
    skip: '跳至正文', nav_how: '工作方式', nav_features: '功能', nav_setup: '开始使用', eyebrow: 'OMARCHY SHELL 插件',
    headline: '让声音，<br><em>自然成为文字。</em>', intro: '从桌面状态栏掌握语音转写。切换输入模式、选择模型，让每一句话以适合你的方式呈现。', get: '获取 Voxtype Hub', hero_foot: '从状态栏，融入你的工作流', how_label: '设计初衷',
    story_title: '自然表达。<br><em>选择始终在你。</em>', story_body: 'Voxtype 负责聆听。Voxtype Hub 在 Omarchy 状态栏提供一个入口，让你管理输入模式，以及可选的大模型后处理。', explore: '查看使用文档',
    features_label: '功能一览', features_title: '把细节，<br><em>放在顺手的地方。</em>', features_intro: '需要时触手可及，不需要时安静退场。', f1_title: '为不同场景准备模式。', f1_body: '创建并切换输入模式，每个模式都有独立可编辑的提示词。编程、聊天，或你自己的工作方式，都可以照顾到。',
    f2_title: '供应商由你选择。', f2_body: '配置兼容 OpenAI 接口的供应商、选择模型，并在已保存的配置间切换。需要原始转写时，可以关闭后处理。', f3_title: '记录留在本地。', f3_body: '浏览近期后处理历史，查看一段时间内的使用情况，并选择 Voxtype 中已安装的语音模型。',
    privacy_label: '清晰的边界', privacy_title: '你的表达。<br><em>你的选择。</em>', privacy_body: '设置、密钥、提示词和历史保存在你的设备上。启用大模型后处理时，转写文本会发送给你选择的供应商；关闭后则直接使用原始转写。',
    setup_label: '开始使用', setup_title: '开始之前，<br><em>先看看文档。</em>', setup_body: '为 Omarchy 和 Voxtype 用户准备。按照仓库说明安装插件并配置后处理。', read_install: '阅读安装指南', setup_note: '当前辅助脚本路径针对原始安装环境，其他系统可能需要调整。', footer: 'Omarchy 上的 Voxtype 小助手。'
  }
};
const button = document.getElementById('language');
function setLanguage(language) {
  const copy = translations[language];
  document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
  document.querySelectorAll('[data-i18n]').forEach(element => { element.textContent = copy[element.dataset.i18n]; });
  document.querySelectorAll('[data-i18n-html]').forEach(element => { element.innerHTML = copy[element.dataset.i18nHtml]; });
  button.innerHTML = language === 'en' ? '中文 <span aria-hidden="true">↗</span>' : 'EN <span aria-hidden="true">↗</span>';
  button.setAttribute('aria-label', language === 'en' ? '切换到中文' : 'Switch to English');
  button.dataset.language = language;
}
button.addEventListener('click', () => setLanguage(button.dataset.language === 'en' ? 'zh' : 'en'));
setLanguage('en');
