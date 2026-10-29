import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  moduleName: "daniel.voxtypehub"
  manageIpc: false
  property var anchorItem: null
  property var hostWidget: null
  property string page: "profiles"
  property string profile: "general"
  property string pendingProfile: ""
  property var profiles: [{id:"general",label:strings.t("ui.1a0fdce8f88f")},{id:"code",label:strings.t("ui.3b70f4e442a1")},{id:"chat",label:strings.t("ui.5358b2ddde5a")}]
  property bool addingProfile: false
  property bool renamingProfile: false
  property bool confirmProfileDelete: false
  property bool confirmProviderDelete: false
  property bool postprocessEnabled: true
  property var prompts: ({})
  property var providers: []
  property string activeProvider: ""
  property string editingProvider: ""
  property var providerBaseline: ({name:"",url:"",model:""})
  property bool providerDirty: nameInput && (nameInput.text!==providerBaseline.name || urlInput.text!==providerBaseline.url || modelInput.text!==providerBaseline.model || keyInput.text!=="")
  property string noticePage: ""
  property var models: []
  property string currentModel: ""
  property var providerModels: []
  property string modelsUrl: ""
  property var history: []
  property int confirmHistoryDelete: 0
  property int statsDays: 7
  property var stats: ({total:0,success:0,characters:0,profiles:{},trend:[],trend_unit:"日"})
  property bool statsLoaded: false
  property string notice: ""
  property string pending: ""
  property string operation: ""
  property string savedPrompt: ""
  property var editor: null
  property var nameInput: null
  property var urlInput: null
  property var modelInput: null
  property var keyInput: null
  property bool dirty: editor && editor.text !== savedPrompt
  property var chartColors: [Commons.Color.accent, "#4e9b82", "#d29548", "#a880c2"]
  component DonutChart: Canvas {
    id: chart
    property var values: []
    property var colors: root.chartColors
    property string centerText: ""
    width:Style.space(130); height:width
    onWidthChanged:requestPaint()
    onHeightChanged:requestPaint()
    onValuesChanged:requestPaint()
    onColorsChanged:requestPaint()
    onPaint: {
      var ctx=getContext("2d"); ctx.reset();
      var total=values.reduce(function(a,b) { return a+b },0)
      if (!total) return
      var angle=-Math.PI/2
      ctx.lineWidth=width*0.16
      for (var i=0;i<values.length;i++) {
        if (values[i]<=0) continue
        var next=angle+2*Math.PI*values[i]/total
        ctx.beginPath(); ctx.strokeStyle=colors[i]; ctx.arc(width/2,height/2,width*0.38,angle,next); ctx.stroke()
        angle=next
      }
    }
    Text { anchors.centerIn:parent; text:chart.centerText; textFormat:Text.PlainText; color:Commons.Color.foreground; font.pixelSize:Style.font.heading; font.bold:true }
  }
  function backendError(message) {
    var keys={"API 地址":"ui.acd8a5043158","API 密钥":"ui.5df1d83e18c6","供应商":"ui.703c9eb0f092","名称":"ui.1be7ae4fc257","提示词":"ui.2f0bb1238738","模型":"ui.98fd0cbd9c31","获取模型列表":"ui.941d9a6e3599","输入模式":"ui.4b06c1bc5958","API 地址须为 HTTPS 的 /chat/completions 地址":"ui.61992c911de8","供应商不存在":"ui.eafa484d64fa","提示词不能为空或模式不存在":"ui.93e87e03bbd0","新供应商或更换地址时请输入密钥":"ui.e3b7281e354b","无效操作":"ui.aa496188d33a","无效时间范围":"ui.aecc74e23cfd","无效模式":"ui.87a5bc00d445","无效的开关状态":"ui.fde56d174031","无效记录":"ui.492d20c6e107","无法获取模型列表，请检查密钥、网络或供应商接口；也可手动输入模型":"ui.64f09809537e","模型未安装":"ui.15057e5fd640","模式不存在":"ui.b3a2338e362c","模式名称已存在":"ui.324d4eeca2f3","模式名称须为 1 到 24 个字符，且不能包含控制字符或尖括号":"ui.466c7585b5c6","记录不存在":"ui.4349e2c2af16","请先输入 API 密钥":"ui.e778fa34e00b","请先输入此地址对应的 API 密钥":"ui.be28d13af34d","请填写名称、模型和有效的 HTTPS 地址":"ui.0259ecc952b3","请至少保留一个供应商":"ui.a85793a2122b","请至少保留一个输入模式":"ui.c16de6a4d5ef"}
    return keys[message] ? strings.t(keys[message]) : strings.t("ui.09e424b5e896")
  }
  function profileLabel(id) {
    var item=profiles.find(function(p) { return p.id===id })
    if (!item) return strings.t("ui.711216949f6d")
    var defaults={general:"通用",code:"编程",chat:"聊天"}
    if (defaults[id] && item.label===defaults[id]) return strings.t(id)
    return item.label
  }
  function profileStats() {
    var items=[]
    for (var id in stats.profiles) {
      var count=stats.profiles[id]
      if (count>0) items.push({id:id,label:profileLabel(id),count:count})
    }
    return items.sort(function(a,b) { return b.count-a.count })
  }
  function chartColor(index) { return index<chartColors.length ? chartColors[index] : Qt.hsla((index*0.618)%1,0.55,0.55,1) }
  signal profileSelected(string value)
  function open() { controller.show(); request({action:"load"}) }
  function editProvider(id) {
    confirmProviderDelete=false
    providerModels=[]
    editingProvider=id
    var item=providers.find(function(p) { return p.id===id })
    nameInput.text=item ? item.name : ""
    urlInput.text=item ? item.url : ""
    modelInput.text=item ? item.model : ""
    keyInput.text=""
    providerBaseline={name:nameInput.text,url:urlInput.text,model:modelInput.text}
  }
  function useProviderPreset(preset) {
    if (keyInput.text!=="") { noticePage=page; notice=strings.t("ui.d688799df6f2"); return }
    providerModels=[]
    nameInput.text=preset.name
    urlInput.text=preset.url
    modelInput.text=preset.model
    keyInput.text=""
  }
  function setProviders(data) {
    providers=data.items; activeProvider=data.active; editProvider(data.active)
  }
  function loadStats(days) {
    statsDays=days; statsLoaded=false; notice=strings.t("ui.1bc7a23a2c34")
    request({action:"statistics",days:days})
  }
  function request(data) {
    noticePage=page
    if (worker.running) { notice=strings.t("ui.9cecf14f2d0f"); return }
    operation=data.action
    pending=JSON.stringify(data)
    worker.stdinEnabled=true
    worker.running=true
  }
  Process {
    id: worker
    command: ["/home/daniel/.local/bin/voxtype-panel-backend"]
    onStarted: { write(root.pending); stdinEnabled=false; root.pending="" }
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var result=JSON.parse(text)
          if (!result.ok) { root.notice=backendError(result.error); return }
          if (root.operation === "load") {
            var d=result.data
            root.postprocessEnabled=d.postprocess_enabled; root.profiles=d.profiles; root.prompts=d.prompts; root.setProviders(d.providers); root.models=d.models; root.currentModel=d.current_model; root.history=d.history
            root.profile=d.profile; root.savedPrompt=String(root.prompts[root.profile] || ""); root.editor.text=root.savedPrompt
            root.profileSelected(root.profile)
          } else if (root.operation === "delete_history") { root.history=root.history.filter(function(item){return item.id!==result.data.id}); root.confirmHistoryDelete=0; root.notice=strings.t("ui.df5c9239a953")
          } else if (root.operation === "postprocess") { root.postprocessEnabled=result.data.enabled; root.notice=root.postprocessEnabled ? strings.t("ui.edd4c3befa9e") : strings.t("ui.a981bc1099bc")
          } else if (root.operation === "add_profile") {
            root.profiles=result.data.profiles; root.profile=result.data.id; root.prompts[root.profile]=result.data.prompt
            root.savedPrompt=result.data.prompt; root.editor.text=result.data.prompt; root.addingProfile=false; profileName.text=""
            root.profileSelected(root.profile); root.notice=strings.t("ui.2a00f52a09bd")
          } else if (root.operation === "rename_profile") { root.profiles=result.data.profiles; root.renamingProfile=false; root.notice=strings.t("ui.c98d55c4c9d3")
          } else if (root.operation === "delete_profile") {
            root.profiles=result.data.profiles; root.profile=result.data.id; root.prompts[root.profile]=result.data.prompt; root.savedPrompt=result.data.prompt; root.editor.text=result.data.prompt
            root.confirmProfileDelete=false; root.profileSelected(root.profile); root.notice=strings.t("ui.1e03085f4ed8")
          } else if (root.operation === "prompt") { root.savedPrompt=root.editor.text; root.prompts[root.profile]=root.editor.text; root.notice=strings.t("ui.cdfab96f757f") }
          else if (root.operation === "profile") { root.profile=root.pendingProfile; root.savedPrompt=String(root.prompts[root.profile] || ""); root.editor.text=root.savedPrompt; root.profileSelected(root.profile); root.notice=strings.t("ui.1dfbf8172fef") }
          else if (root.operation === "model") { root.currentModel=result.data.model; root.notice=strings.t("ui.00c722881afc") }
          else if (root.operation === "statistics") { root.stats=result.data; root.statsLoaded=true; root.notice="" }
          else if (root.operation === "provider_models") { if (root.modelsUrl===root.urlInput.text.trim()) { root.providerModels=result.data; root.notice=result.data.length ? strings.t("ui.7330bf2340e2") : strings.t("ui.1f2c65600cbf") } }
          else if (root.operation === "provider" || root.operation === "select_provider" || root.operation === "delete_provider") { root.setProviders(result.data); root.notice=root.operation === "provider" ? strings.t("ui.f6ded2520b93") : (root.operation === "delete_provider" ? strings.t("ui.3e50704d1db0") : strings.t("ui.1dfbf8172fef")) }
          else { root.notice=strings.t("ui.cdfab96f757f") }
        } catch(e) { console.warn("Voxtype operation failed:", root.operation, e); root.notice=strings.t("ui.ed6b12f47042") }
      }
    }
  }
  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    contentWidth: panel.fittedContentWidth(Style.space(480))
    contentHeight: panel.fittedContentHeight(Style.space(650))
    content: Column {
      id: main
      Component.onCompleted: { root.editor=promptInput; root.nameInput=nameField; root.urlInput=urlField; root.modelInput=modelField; root.keyInput=keyField }
      width: parent.width
      spacing: Style.space(8)
      Text { text: "Voxtype"; textFormat: Text.PlainText; color: Commons.Color.foreground; font.pixelSize: Style.font.heading; font.bold: true }
      Flow {
        width:parent.width; spacing: Style.space(2)
        Repeater {
          model: [{id:"profiles",label:strings.t("ui.2f0bb1238738")},{id:"provider",label:strings.t("ui.703c9eb0f092")},{id:"models",label:strings.t("ui.3f2869ccfabe")},{id:"history",label:strings.t("ui.be78b2058534")},{id:"stats",label:strings.t("ui.ca8ffc399034")}]
          Button { required property var modelData; text: modelData.label; selected: root.page===modelData.id; focusable: true; enabled:!worker.running
            onClicked: { if(root.dirty) { root.noticePage=root.page; root.notice=strings.t("ui.9e57e62cec6a"); return } if(root.page==="provider" && root.providerDirty && modelData.id!=="provider") { root.noticePage=root.page; root.notice=strings.t("ui.5d8cfa9b66b5"); return } root.page=modelData.id; root.notice=""; if(root.page==="stats") root.loadStats(root.statsDays) }
          }
        }
      }
      PanelSeparator {}
      Flickable {
        width: parent.width
        height: Math.max(0, parent.height - y - (actions.visible ? actions.implicitHeight + main.spacing : 0))
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: body
          width: parent.width
          spacing: Style.space(8)
          Text { width:parent.width; visible:root.notice!=="" && (root.noticePage===root.page || root.noticePage===""); text:root.notice; textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground; font.pixelSize:Style.font.body }
          Column {
            width: parent.width; spacing: Style.space(8); visible: root.page==="profiles"
            PanelSectionHeader { text: strings.t("ui.b5364ec8c324") }
            Button { text:root.postprocessEnabled ? strings.t("ui.c79c5f9c59b6") : strings.t("ui.b63d95c8c554"); selected:root.postprocessEnabled; bordered:true; focusable:true; enabled:!worker.running; onClicked:root.request({action:"postprocess",enabled:!root.postprocessEnabled}) }
            Text { width:parent.width; text:root.postprocessEnabled ? strings.t("ui.541a245e0932") : strings.t("ui.af1f376fb59a"); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            PanelSectionHeader { text: strings.t("ui.4b06c1bc5958") }
            Flow {
              width:parent.width; spacing: Style.space(5)
              Repeater {
                model: root.profiles
                Button { required property var modelData; text: root.profileLabel(modelData.id); selected: root.profile===modelData.id; bordered: true; focusable: true; enabled:!worker.running
                  onClicked: {
                    if(root.dirty) { root.notice=strings.t("ui.69e454964ed7"); return }
                    root.confirmProfileDelete=false; root.renamingProfile=false; root.pendingProfile=modelData.id
                    root.request({action:"profile",value:modelData.id})
                  }
                }
              }
            }
            Flow { width:parent.width; spacing:Style.space(5)
              Button { text:root.renamingProfile ? strings.t("ui.89fdd63b69c3") : strings.t("ui.ae938ccba18d"); focusable:true; enabled:!worker.running; onClicked: { root.confirmProfileDelete=false; root.renamingProfile=!root.renamingProfile; var item=root.profiles.find(function(p){return p.id===root.profile}); renameProfileName.text=item ? item.label : "" } }
              Button { text:root.confirmProfileDelete ? strings.t("ui.3aa69add90c9") : strings.t("ui.d0bf191e2d7e"); focusable:true; enabled:!worker.running && root.profiles.length>1; onClicked: { if(root.dirty) { root.notice=strings.t("ui.9e57e62cec6a"); return } root.renamingProfile=false; root.confirmProfileDelete=!root.confirmProfileDelete } }
            }
            Column { width:parent.width; spacing:Style.space(5); visible:root.renamingProfile
              TextField { id:renameProfileName; width:parent.width; placeholderText:strings.t("ui.7dd0e8bdf6b3") }
              Button { text:strings.t("ui.056421f9223b"); focusable:true; enabled:!worker.running; onClicked:root.request({action:"rename_profile",id:root.profile,name:renameProfileName.text}) }
            }
            Column { width:parent.width; spacing:Style.space(5); visible:root.confirmProfileDelete
              Text { width:parent.width; text:strings.t("ui.ca62247804b7"); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground }
              Button { text:strings.t("ui.0302e72024c8"); bordered:true; focusable:true; enabled:!worker.running; onClicked:root.request({action:"delete_profile",id:root.profile}) }
            }
            Button { text:root.addingProfile ? strings.t("ui.e75119551af5") : strings.t("ui.e9dfbfde09b4"); focusable:true; onClicked: { if(root.dirty) { root.notice=strings.t("ui.69e454964ed7"); return } root.addingProfile=!root.addingProfile } }
            Column { width:parent.width; spacing:Style.space(5); visible:root.addingProfile
              TextField { id:profileName; width:parent.width; placeholderText:strings.t("ui.9e130e846bfd") }
              Button { text:strings.t("ui.65edcb5de712"); bordered:true; focusable:true; enabled:!worker.running; onClicked:root.request({action:"add_profile",name:profileName.text}) }
            }
            PanelSectionHeader { text: strings.t("ui.2f0bb1238738"); visible:root.postprocessEnabled || root.dirty }
            BorderSurface {
              visible:root.postprocessEnabled || root.dirty
              width: parent.width; height: Math.max(Style.space(150), promptInput.implicitHeight + Style.space(16)); radius: Style.cornerRadius
              color: Commons.Color.popups.background
              borderSpec: Border.controlSpec("normal", Commons.Color.foreground, Commons.Color.accent)
              TextEdit { id: promptInput; anchors.fill:parent; anchors.margins:Style.space(8); wrapMode: TextEdit.Wrap; selectByMouse: true; readOnly:worker.running; color: Commons.Color.foreground; font.family: Style.font.family; font.pixelSize: Style.font.body; textFormat: TextEdit.PlainText }
            }
          }
          Column {
            width:parent.width; spacing:Style.space(8); visible:root.page==="provider"
            PanelSectionHeader { text:strings.t("ui.703c9eb0f092") }
            Text { width:parent.width; text:strings.t("ui.66dcde8eb630"); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            Repeater { model:root.providers
              RowLayout {
                required property var modelData; width:parent.width; spacing:Style.space(5)
                Button { Layout.fillWidth:true; text:parent.modelData.name; leftAlign:true; selected:root.editingProvider===parent.modelData.id; focusable:true; enabled:!worker.running
                  onClicked: { if(root.editingProvider===parent.modelData.id) return; if(root.providerDirty) { root.noticePage=root.page; root.notice=strings.t("ui.5d8cfa9b66b5"); return } root.editProvider(parent.modelData.id) }
                }
                Controls.RadioButton {
                  id:providerChoice
                  text:strings.t("ui.d4e9ca3dd494"); Accessible.name:strings.t("provider.accessible").arg(parent.modelData.name); palette.text:Commons.Color.foreground; palette.highlight:Commons.Color.accent; font.family:Style.font.family; font.pixelSize:Style.font.body
                  autoExclusive:false; checked:root.activeProvider===parent.modelData.id; enabled:!worker.running
                  onClicked: {
                    checked=Qt.binding(function(){return root.activeProvider===providerChoice.parent.modelData.id})
                    if(root.activeProvider===parent.modelData.id) return
                    if(root.providerDirty) { root.noticePage=root.page; root.notice=strings.t("ui.5d8cfa9b66b5"); return }
                    root.request({action:"select_provider",id:parent.modelData.id})
                  }
                }
              }
            }
            Button { text:strings.t("ui.3f55a222eae4"); focusable:true; onClicked: { if(root.providerDirty) { root.noticePage=root.page; root.notice=strings.t("ui.5d8cfa9b66b5"); return } root.editProvider("") } }
            PanelSectionHeader { text:root.editingProvider ? strings.t("ui.5360aaf038ab") : strings.t("ui.96861813fa96") }
            Flow {
              width:parent.width; spacing:Style.space(5); visible:!root.editingProvider
              Repeater {
                model: [
                  {name:"DeepSeek",url:"https://api.deepseek.com/chat/completions",model:"deepseek-flash"},
                  {name:strings.t("ui.b1663a13d671"),url:"https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",model:"qwen-plus"},
                  {name:"Gemini",url:"https://generativelanguage.googleapis.com/v1beta/openai/chat/completions",model:"gemini-3.8-flash"},
                  {name:"OpenAI",url:"https://api.openai.com/v1/chat/completions",model:"gpt-4.1-mini"}
                ]
                Button { required property var modelData; text:modelData.name; focusable:true; onClicked:root.useProviderPreset(modelData) }
              }
            }
            Text { text:strings.t("ui.1be7ae4fc257"); color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            TextField { id:nameField; width:parent.width; enabled:!worker.running; placeholderText:strings.t("ui.cf44ec3f55f9") }
            Text { text:strings.t("ui.acd8a5043158"); color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            TextField { id:urlField; width:parent.width; enabled:!worker.running; placeholderText:strings.t("ui.45b8c916be37"); onTextChanged:root.providerModels=[] }
            Text { text:strings.t("ui.98fd0cbd9c31"); color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            TextField { id:modelField; width:parent.width; enabled:!worker.running; placeholderText:strings.t("ui.38719c9968ae") }
            Text { text:strings.t("ui.5df1d83e18c6"); color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            TextField { id:keyField; width:parent.width; enabled:!worker.running; placeholderText:strings.t("ui.56e405ce9660"); password:true }
            Button { text:worker.running && root.operation==="provider_models" ? strings.t("ui.8323dbe97067") : strings.t("ui.941d9a6e3599"); focusable:true; enabled:!worker.running
              onClicked: { root.providerModels=[]; root.modelsUrl=root.urlInput.text.trim(); root.notice=strings.t("ui.88bac863358a"); root.request({action:"provider_models",id:root.editingProvider,url:root.modelsUrl,key:root.keyInput.text}) }
            }
            ListView {
              width:parent.width; height:root.providerModels.length ? Style.space(180) : 0; visible:height>0; clip:true; model:root.providerModels
              delegate:Button { required property string modelData; width:ListView.view.width; text:modelData; leftAlign:true; focusable:true; onClicked: { root.modelInput.text=modelData; root.providerModels=[]; root.notice=strings.t("ui.c87e978ae67e") } }
            }
            Button { text:root.confirmProviderDelete ? strings.t("ui.3aa69add90c9") : strings.t("ui.7ede0f419d9b"); visible:root.editingProvider!==""; enabled:!worker.running && root.providers.length>1; focusable:true; onClicked:root.confirmProviderDelete=!root.confirmProviderDelete }
            Column { width:parent.width; spacing:Style.space(5); visible:root.confirmProviderDelete
              Text { width:parent.width; text:strings.t("ui.dc3a7409c40d"); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground }
              Button { text:strings.t("ui.93069c474f43"); bordered:true; focusable:true; enabled:!worker.running; onClicked:root.request({action:"delete_provider",id:root.editingProvider}) }
            }
          }
          Column {
            width:parent.width; spacing:Style.space(8); visible:root.page==="models"
            PanelSectionHeader { text:strings.t("ui.c56d98478a7a") }
            Text { width:parent.width; visible:root.models.length===0; text:strings.t("ui.c6a8bccb939e"); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground }
            Repeater { model:root.models; Button { required property string modelData; width:parent.width; text:root.currentModel===modelData ? strings.t("model.current").arg(modelData) : modelData; selected:root.currentModel===modelData; enabled:!worker.running; leftAlign:true; focusable:true; onClicked:root.request({action:"model",value:modelData}) } }
          }
          Column {
            width:parent.width; spacing:Style.space(10); visible:root.page==="history"
            PanelSectionHeader { text:strings.t("ui.9f14a3f4dd5f") }
            Text { visible:root.history.length===0; text:strings.t("ui.77cf867de771"); textFormat:Text.PlainText; color:Commons.Color.foreground }
            Repeater { model:root.history
              Column { required property var modelData; width:parent.width; spacing:Style.space(3)
                Text { width:parent.width; text:strings.t("history.metadata").arg(String(modelData.date).slice(0,16).replace("T"," ")).arg(root.profileLabel(modelData.profile)).arg(modelData.success ? "" : strings.t("history.raw")); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground; opacity:0.7; font.pixelSize:Style.font.caption }
                Text { width:parent.width; text:String(modelData.output); textFormat:Text.PlainText; color:Commons.Color.foreground; font.pixelSize:Style.font.body; wrapMode:Text.Wrap }
                Button { text:root.confirmHistoryDelete===modelData.id ? strings.t("ui.3aa69add90c9") : strings.t("ui.8f22c9908ed4"); focusable:true; enabled:!worker.running; onClicked:root.confirmHistoryDelete=root.confirmHistoryDelete===modelData.id ? 0 : modelData.id }
                Row { visible:root.confirmHistoryDelete===parent.modelData.id; spacing:Style.space(5)
                  Button { text:strings.t("ui.3c06abe11651"); bordered:true; focusable:true; enabled:!worker.running; onClicked:root.request({action:"delete_history",id:parent.parent.modelData.id}) }
                }
                PanelSeparator {}
              }
            }
          }
          Column {
            width:parent.width; spacing:Style.space(10); visible:root.page==="stats"
            PanelSectionHeader { text:strings.t("ui.174fd6f85c7c") }
            Text { width:parent.width; text:strings.t("ui.19bca5ca7164"); textFormat:Text.PlainText; wrapMode:Text.Wrap; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            Flow { width:parent.width; spacing:Style.space(5)
              Repeater { model:[{days:7,label:strings.t("ui.f297b996dedc")},{days:30,label:strings.t("ui.00a0a58be6ba")},{days:90,label:strings.t("ui.0e9926eb9f4d")},{days:0,label:strings.t("ui.778fc8f99453")}]
                Button { required property var modelData; text:modelData.label; selected:root.statsDays===modelData.days; enabled:!worker.running; focusable:true; onClicked:root.loadStats(modelData.days) }
              }
            }
            Text { width:parent.width; visible:root.statsLoaded && root.stats.total===0; text:strings.t("ui.fc715f64e03c"); wrapMode:Text.Wrap; color:Commons.Color.foreground }
            Column {
              width:parent.width; spacing:Style.space(10); visible:root.statsLoaded && root.stats.total>0
              GridLayout {
                width:parent.width; columns:width < Style.space(320) ? 1 : 2; columnSpacing:Style.space(12); rowSpacing:Style.space(12)
                Column {
                  Layout.fillWidth:true; Layout.preferredWidth:1; Layout.alignment:Qt.AlignTop; spacing:Style.space(6)
                  PanelSectionHeader { text:strings.t("ui.a8364e81abf5") }
                  DonutChart { anchors.horizontalCenter:parent.horizontalCenter; width:Math.min(Style.space(130),parent.width); values:[root.stats.success,root.stats.total-root.stats.success]; centerText:Math.round(root.stats.success*100/root.stats.total)+"%" }
                  Flow { width:parent.width; spacing:Style.space(8)
                    Repeater { model:[{label:strings.t("ui.51991a5d111a"),color:root.chartColors[0]},{label:strings.t("ui.dc366956319c"),color:root.chartColors[1]}]
                      Row { required property var modelData; spacing:Style.space(4)
                        Rectangle { width:Style.space(10); height:width; radius:width/2; color:parent.modelData.color }
                        Text { text:parent.modelData.label; textFormat:Text.PlainText; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
                      }
                    }
                  }
                  Text { width:parent.width; text:strings.tn("stats.summary",root.stats.total).arg(Commons.I18n.formatNumber(root.stats.total)).arg(Commons.I18n.formatNumber(root.stats.characters)); textFormat:Text.PlainText; wrapMode:Text.Wrap; horizontalAlignment:Text.AlignHCenter; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
                  Text { width:parent.width; text:strings.tn("stats.failed",root.stats.total-root.stats.success).arg(Commons.I18n.formatNumber(root.stats.total-root.stats.success)); textFormat:Text.PlainText; horizontalAlignment:Text.AlignHCenter; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
                }
                Column {
                  Layout.fillWidth:true; Layout.preferredWidth:1; Layout.alignment:Qt.AlignTop; spacing:Style.space(6)
                  PanelSectionHeader { text:strings.t("ui.4b06c1bc5958") }
                  DonutChart { anchors.horizontalCenter:parent.horizontalCenter; width:Math.min(Style.space(130),parent.width); values:root.profileStats().map(function(p){return p.count}); colors:root.profileStats().map(function(p,i){return root.chartColor(i)}); centerText:String(root.stats.total) }
                  Flow { width:parent.width; spacing:Style.space(8)
                    Repeater { model:root.profileStats()
                      Row { required property var modelData; required property int index; spacing:Style.space(4)
                        Rectangle { width:Style.space(10); height:width; radius:width/2; color:root.chartColor(parent.index) }
                        Text { text:strings.t("profile.count").arg(parent.modelData.label).arg(Commons.I18n.formatNumber(parent.modelData.count)); textFormat:Text.PlainText; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
                      }
                    }
                  }
                }
              }
              PanelSectionHeader { text:strings.t("trend.title").arg(strings.t(root.statsDays===7 ? "trend.day" : (root.statsDays===0 ? "trend.month" : "trend.week"))) }
              Text { width:parent.width; text:root.statsDays===0 ? strings.t("ui.ff65ade50549") : (root.statsDays===7 ? strings.t("ui.89c6a3a1ae26") : strings.t("ui.4eae05cb3a18")); textFormat:Text.PlainText; color:Commons.Color.foreground; opacity:0.7; font.pixelSize:Style.font.caption }
              Flickable {
                id:trendViewport
                width:parent.width; height:Style.space(150); contentWidth:trendChart.width; contentHeight:height; clip:true; boundsBehavior:Flickable.StopAtBounds
                Row {
                  id:trendChart
                  width:Math.max(trendViewport.width,root.stats.trend.length*Style.space(48)); height:trendViewport.height; spacing:Style.space(3)
                  property int maximum:Math.max(1,Math.max.apply(null,root.stats.trend.map(function(x) { return x.count })))
                  Repeater { model:root.stats.trend
                    Column { required property var modelData; width:Math.max(0,(trendChart.width-trendChart.spacing*(root.stats.trend.length-1))/root.stats.trend.length); height:trendChart.height; spacing:Style.space(3)
                      Text { width:parent.width; height:Style.space(18); text:parent.modelData.count ? String(parent.modelData.count) : ""; textFormat:Text.PlainText; horizontalAlignment:Text.AlignHCenter; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
                      Item { width:parent.width; height:Math.max(0,parent.height-Style.space(45))
                        Rectangle { anchors.bottom:parent.bottom; anchors.horizontalCenter:parent.horizontalCenter; width:Math.max(2,parent.width*0.65); height:Math.max(1,parent.height*parent.parent.modelData.count/trendChart.maximum); radius:Style.space(2); color:parent.parent.modelData.count ? Commons.Color.accent : Qt.rgba(0.5,0.5,0.5,0.25) }
                      }
                      Text { width:parent.width; text:root.statsDays===0 ? parent.modelData.label : parent.modelData.label.slice(5).replace("-","/"); textFormat:Text.PlainText; horizontalAlignment:Text.AlignHCenter; elide:Text.ElideRight; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
                    }
                  }
                }
              }
              Text { width:parent.width; visible:trendChart.width>width; text:strings.t("ui.85afda89c192"); textFormat:Text.PlainText; color:Commons.Color.foreground; font.pixelSize:Style.font.caption }
            }
          }
        }
      }
      Flow {
        id:actions
        width:parent.width; spacing:Style.space(8)
        visible:(root.page==="profiles" && (root.postprocessEnabled || root.dirty)) || root.page==="provider"
        Button { text:strings.t("ui.86865c582c88"); visible:root.page==="profiles"; bordered:true; focusable:true; enabled:root.dirty && !worker.running; onClicked:root.request({action:"prompt",profile:root.profile,text:root.editor.text}) }
        Button { text:strings.t("ui.80684c792b3b"); visible:root.page==="profiles"; focusable:true; enabled:root.dirty && !worker.running; onClicked:root.editor.text=root.savedPrompt }
        Button { text:strings.t("ui.84c118967add"); visible:root.page==="provider"; bordered:true; focusable:true; enabled:root.providerDirty && !worker.running; onClicked:root.request({action:"provider",id:root.editingProvider,name:root.nameInput.text,url:root.urlInput.text,model:root.modelInput.text,key:root.keyInput.text}) }
        Button { text:strings.t("ui.80684c792b3b"); visible:root.page==="provider"; focusable:true; enabled:root.providerDirty && !worker.running; onClicked:root.editProvider(root.editingProvider) }
      }
    }
  }
}
