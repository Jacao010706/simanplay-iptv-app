' PRIMETV — canal Roku (SceneGraph).
' Fluxo: licença -> tela do aparelho (MAC + chave + listas do site, estilo IBO)
'        -> menu (Ao Vivo / Filmes / Séries) -> categorias -> itens
'        (-> temporadas -> episódios, nas séries) -> player.
' Listas do aparelho (mode "dev"): backend /license/device/xtream e /license/device/stream.
' Login com usuário e senha (mode "si"): rotas do painel /api/tv-login, /api/xtream, /api/stream.

sub init()
    m.cfg = appConfig()
    primary = sgColor(m.cfg.primaryHex, "E94BFF")

    m.top.backgroundColor = sgColor(m.cfg.bgHex, "0A0A0F")
    m.top.backgroundUri = ""
    m.top.findNode("bg").color = sgColor(m.cfg.bgHex, "0A0A0F")
    m.top.findNode("header").color = sgColor(m.cfg.surfaceHex, "1A1625")

    m.title = m.top.findNode("appTitle")
    m.title.text = m.cfg.appName
    m.title.color = primary
    m.crumb = m.top.findNode("breadcrumb")
    m.status = m.top.findNode("status")

    m.list = m.top.findNode("list")
    m.list.focusBitmapBlendColor = primary
    m.list.observeField("itemSelected", "onItemSelected")

    m.video = m.top.findNode("video")
    m.video.observeField("state", "onVideoState")

    m.devPanel = m.top.findNode("devPanel")
    m.top.findNode("devBox").color = sgColor(m.cfg.surfaceHex, "1A1625")
    m.devL1 = m.top.findNode("devL1")
    m.devMac = m.top.findNode("devMac")
    m.devL2 = m.top.findNode("devL2")
    m.devKey = m.top.findNode("devKey")
    m.devKey.color = primary
    m.devHelp = m.top.findNode("devHelp")
    m.devQr = m.top.findNode("devQr")
    m.devFoot = m.top.findNode("devFoot")
    m.poll = m.top.findNode("pollTimer")
    m.poll.observeField("fire", "onPollFire")

    m.stack = []        ' pilha de telas: {kind, title, items, focus}
    m.busy = false
    m.reg = CreateObject("roRegistrySection", "primetv")
    m.un = m.reg.Read("un")
    m.pw = m.reg.Read("pw")
    m.si = m.reg.Read("si")
    m.mode = "si"
    m.mac = ""
    m.key = ""
    m.pl = ""
    m.lists = []
    checkLicense()
end sub

' ─────────────────────────── Licença (teste grátis / plano) ───────────────────────────

sub checkLicense()
    code = m.reg.Read("code")
    body = {platform: "roku", app_version: "roku-1"}
    if code = "" then
        body.hw_id = CreateObject("roDeviceInfo").GetChannelClientId()
        m.licPath = "/license/register"
    else
        body.device_code = code
        m.licPath = "/license/check"
    end if
    setStatus("Verificando aparelho...")
    postJson(m.licPath, body, "onLicense")
end sub

sub onLicense()
    res = takeResult()
    if res = invalid then return
    if m.licPath = "/license/check" and (res.code = 404 or res.code = 400) then
        m.reg.Delete("code")
        m.reg.Flush()
        checkLicense()
        return
    end if
    data = invalid
    if res.body <> "" then data = ParseJson(res.body)
    lic = invalid
    if res.ok and data <> invalid and data.mac <> invalid then
        if data.device_code <> invalid then m.reg.Write("code", anyToStr(data.device_code))
        days = 0
        if data.days_left <> invalid then days = data.days_left
        lic = {mac: anyToStr(data.mac), key: anyToStr(data.device_key), allowed: (data.allowed = true), status: anyToStr(data.status), days: days, plan: anyToStr(data.plan)}
        lic.until = CreateObject("roDateTime").AsSeconds() + days * 86400
        m.reg.Write("lic", FormatJson(lic))
        m.reg.Flush()
        setStatus("")
    else
        lic = cachedLicense()
    end if
    applyLicense(lic)
end sub

' Sem internet: usa a última situação salva enquanto ainda estiver válida
function cachedLicense() as object
    raw = m.reg.Read("lic")
    c = invalid
    if raw <> "" then c = ParseJson(raw)
    if c = invalid then return {mac: "", key: "", allowed: true, status: "trial", days: 0, plan: "", offline: true}
    c.allowed = (c.allowed = true) and c.until > CreateObject("roDateTime").AsSeconds()
    c.offline = true
    return c
end function

sub applyLicense(lic as object)
    m.lic = lic
    if lic.mac <> "" then
        m.mac = lic.mac
        m.key = lic.key
    end if
    if not lic.allowed then
        showBlocked()
        return
    end if
    ' Clientes antigos com usuário/senha salvos continuam entrando direto
    if m.un <> "" and m.pw <> "" then
        m.mode = "si"
        doLogin()
        return
    end if
    showDevice(true)
end sub

sub showBlocked()
    m.stack = []
    setDeviceLayout(true)
    title = "Seu período de teste grátis terminou"
    if m.lic.plan <> "" then title = "Sua assinatura venceu"
    m.devL1.text = "MAC do aparelho"
    m.devMac.text = m.mac
    m.devL2.text = ""
    m.devKey.text = ""
    m.devHelp.text = title + Chr(10) + "Assine pelo celular com PIX:" + Chr(10) + "Mensal R$ 5 • Semestral R$ 8 • Anual R$ 13"
    m.devQr.uri = qrUrl("app")
    m.devFoot.text = "Aponte a câmera do celular para o QR Code." + Chr(10) + Chr(10) + "A TV libera sozinha depois do pagamento."
    if m.lic.offline = true then m.devFoot.text = "Sem conexão com o servidor. Verifique a internet."
    renderScreen({kind: "blocked", title: "Assinatura", items: [{title: "Já paguei — verificar", action: "check"}], focus: 0}, true)
    m.poll.duration = 15
    m.poll.control = "start"
end sub

' ─────────────────────────── Aparelho: MAC + chave + listas do site ───────────────────────────

function qrUrl(dest as string) as string
    return m.cfg.backendBase + "/license/qr.png?to=" + dest + "&mac=" + m.mac.Replace(":", "")
end function

sub setDeviceLayout(on as boolean)
    m.devPanel.visible = on
    if on then
        m.list.translation = [880, 170]
        m.list.itemSize = [950, 72]
    else
        m.list.translation = [90, 170]
        m.list.itemSize = [1740, 72]
    end if
end sub

sub showDevice(auto as boolean)
    m.mode = "si"
    m.stack = []
    setDeviceLayout(true)
    m.devL1.text = "MAC do aparelho"
    m.devL2.text = "Chave do aparelho"
    if m.mac <> "" then
        m.devMac.text = m.mac
        m.devKey.text = m.key
        m.devQr.uri = qrUrl("dispositivo")
    else
        m.devMac.text = "(sem conexão)"
        m.devKey.text = ""
    end if
    m.devHelp.text = "Para adicionar suas listas, acesse pelo celular:" + Chr(10) + "simanplay-iptv-admin-panel.vercel.app/dispositivo" + Chr(10) + "e digite o MAC e a chave acima."
    m.devFoot.text = "Ou aponte a câmera do celular para o QR Code."
    if m.lic <> invalid and m.lic.status = "trial" and m.lic.days > 0 then
        m.devFoot.text = m.devFoot.text + Chr(10) + Chr(10) + "Teste grátis: " + anyToStr(m.lic.days) + " dia(s) restante(s)"
    end if
    m.autoEnter = auto
    renderScreen({kind: "device", title: "Suas listas", items: deviceItems(), focus: 0}, true)
    loadLists()
    ' Enquanto esta tela está aberta, confere se o cliente cadastrou/alterou listas no site
    m.poll.duration = 20
    m.poll.control = "start"
end sub

function deviceItems() as object
    items = []
    for each p in m.lists
        kind = "Lista M3U"
        if p.type = "xtream" then kind = "Xtream"
        items.Push({title: anyToStr(p.name) + "   (" + kind + ")", action: "pl", pl: p})
    end for
    if items.Count() = 0 then items.Push({title: "Nenhuma lista ainda — cadastre pelo site (ao lado)", action: "refresh"})
    items.Push({title: "Atualizar listas", action: "refresh"})
    items.Push({title: "Entrar com usuário e senha", action: "login"})
    return items
end function

sub loadLists()
    if m.mac = "" or m.key = "" then
        setStatus("Sem conexão com o servidor. Verifique a internet.")
        return
    end if
    postJson("/license/device/login", {mac: m.mac, key: m.key}, "onLists")
end sub

sub onLists()
    res = takeResult()
    if res = invalid then return
    data = invalid
    if res.ok and res.body <> "" then data = ParseJson(res.body)
    if data <> invalid and data.playlists <> invalid then
        m.lists = data.playlists
        m.reg.Write("lists", FormatJson(m.lists))
        m.reg.Flush()
        setStatus("")
    else
        if m.lists.Count() = 0 then
            cached = ParseJson(m.reg.Read("lists"))
            if type(cached) = "roArray" then m.lists = cached
        end if
        setStatus("Sem conexão com o servidor. Tentando de novo...")
    end if
    if m.stack.Count() = 1 and m.stack[0].kind = "device" then
        m.stack[0].focus = m.list.itemFocused
        m.stack[0].items = deviceItems()
        renderScreen(m.stack[0], false)
    end if
    if m.autoEnter = true then
        m.autoEnter = false
        last = m.reg.Read("pl")
        for each p in m.lists
            if anyToStr(p.id) = last then
                openList(p)
                return
            end if
        end for
        if m.lists.Count() = 1 then openList(m.lists[0])
    end if
end sub

sub openList(p as object)
    m.poll.control = "stop"
    m.mode = "dev"
    m.pl = anyToStr(p.id)
    m.plName = anyToStr(p.name)
    m.reg.Write("pl", m.pl)
    m.reg.Flush()
    setDeviceLayout(false)
    setStatus("")
    showMenu()
end sub

sub onPollFire()
    if m.busy or m.stack.Count() = 0 or m.video.visible then return
    kind = m.stack[m.stack.Count() - 1].kind
    if kind = "device" then
        loadLists()
    else if kind = "blocked" then
        checkLicense()
    else
        m.poll.control = "stop"
    end if
end sub

' ─────────────────────────── Login ───────────────────────────

sub askUser()
    showKeyboard("Usuário", m.un, false, "onUserEntered")
end sub

sub onUserEntered()
    dlg = m.top.dialog
    if dlg = invalid then return
    if dlg.buttonSelected = 0 then
        m.un = dlg.text.Trim()
        dlg.close = true
        showKeyboard("Senha", "", true, "onPassEntered")
    else
        dlg.close = true
        setStatus("")
        showDevice(false)
    end if
end sub

sub onPassEntered()
    dlg = m.top.dialog
    if dlg = invalid then return
    if dlg.buttonSelected = 0 then
        m.pw = dlg.text
        dlg.close = true
        doLogin()
    else
        dlg.close = true
        showLoginPrompt()
    end if
end sub

sub showKeyboard(title as string, initial as string, secure as boolean, callback as string)
    dlg = CreateObject("roSGNode", "KeyboardDialog")
    dlg.title = title
    dlg.buttons = ["OK", "Cancelar"]
    dlg.text = initial
    if secure then dlg.keyboard.textEditBox.secureMode = true
    dlg.observeField("buttonSelected", callback)
    m.top.dialog = dlg
end sub

sub showLoginPrompt()
    m.stack = []
    setDeviceLayout(false)
    renderScreen({kind: "login", title: "Entrar", items: [{title: "Entrar com usuário e senha", action: "login"}, {title: "Voltar (MAC e listas)", action: "back"}], focus: 0}, true)
end sub

sub doLogin()
    if m.un = "" or m.pw = "" then
        askUser()
        return
    end if
    setStatus("Entrando...")
    request("/api/tv-login", {username: m.un, password: m.pw}, "onLoginResult")
end sub

sub onLoginResult()
    res = takeResult()
    if res = invalid then return
    data = invalid
    if res.body <> "" then data = ParseJson(res.body)
    if res.ok and data <> invalid and data.ok = true then
        m.si = "0"
        if data.si <> invalid then m.si = anyToStr(data.si)
        m.reg.Write("un", m.un)
        m.reg.Write("pw", m.pw)
        m.reg.Write("si", m.si)
        m.reg.Flush()
        m.mode = "si"
        setDeviceLayout(false)
        setStatus("")
        showMenu()
    else
        msg = "Usuário ou senha inválidos"
        if data <> invalid and data.detail <> invalid then msg = anyToStr(data.detail)
        if data <> invalid and data.error <> invalid then msg = anyToStr(data.error)
        if not res.ok and res.code <= 0 then msg = res.error
        setStatus(msg)
        m.stack = []
        showLoginPrompt()
    end if
end sub

sub logout()
    m.reg.Delete("un")
    m.reg.Delete("pw")
    m.reg.Delete("si")
    m.reg.Delete("pl")
    m.reg.Flush()
    m.un = ""
    m.pw = ""
    m.pl = ""
    setStatus("")
    ' Volta para a tela do aparelho (MAC + listas), sem entrar sozinho de novo
    showDevice(false)
end sub

' ─────────────────────────── Telas ───────────────────────────

sub showMenu()
    m.stack = []
    items = [
        {title: "TV ao Vivo", action: "live"}
        {title: "Filmes", action: "vod"}
        {title: "Séries", action: "series"}
        {title: "Trocar conta", action: "logout"}
    ]
    title = "Início"
    if m.mode = "dev" then
        items[3].title = "Trocar lista"
        title = "Início — " + m.plName
    end if
    renderScreen({kind: "menu", title: title, items: items, focus: 0}, true)
end sub

' push=true empilha a tela nova; false só redesenha a do topo
sub renderScreen(screen as object, push as boolean)
    if push then
        if m.stack.Count() > 0 then m.stack[m.stack.Count() - 1].focus = m.list.itemFocused
        m.stack.Push(screen)
    end if
    content = CreateObject("roSGNode", "ContentNode")
    for each it in screen.items
        n = content.CreateChild("ContentNode")
        n.title = it.title
    end for
    m.list.content = content
    if screen.focus <> invalid and screen.focus < screen.items.Count() then m.list.jumpToItem = screen.focus
    m.crumb.text = screen.title
    m.list.setFocus(true)
end sub

sub onItemSelected()
    if m.busy or m.stack.Count() = 0 then return
    screen = m.stack[m.stack.Count() - 1]
    idx = m.list.itemSelected
    if idx < 0 or idx >= screen.items.Count() then return
    it = screen.items[idx]

    if screen.kind = "device" then
        if it.action = "pl" then
            openList(it.pl)
        else if it.action = "refresh" then
            setStatus("Atualizando...")
            loadLists()
        else
            m.poll.control = "stop"
            setDeviceLayout(false)
            askUser()
        end if
    else if screen.kind = "blocked" then
        checkLicense()
    else if screen.kind = "login" then
        if it.action = "back" then
            showDevice(false)
        else
            askUser()
        end if
    else if screen.kind = "menu" then
        if it.action = "logout" then
            logout()
        else
            m.section = it.action
            m.sectionTitle = it.title
            loadCategories()
        end if
    else if screen.kind = "categories" then
        loadItems(it)
    else if screen.kind = "items" then
        if m.section = "series" then
            loadSeriesInfo(it)
        else if m.section = "live" then
            ext = "m3u8"
            if it.liveExt <> invalid then ext = it.liveExt
            playStream("live", it.id, ext, it.title)
        else
            playStream("movie", it.id, it.ext, it.title)
        end if
    else if screen.kind = "seasons" then
        showEpisodes(it)
    else if screen.kind = "episodes" then
        playStream("series", it.id, it.ext, it.title)
    end if
end sub

sub loadCategories()
    actions = {live: "get_live_categories", vod: "get_vod_categories", series: "get_series_categories"}
    setStatus("Carregando categorias...")
    xtream(actions[m.section], {}, "onCategories")
end sub

sub onCategories()
    arr = takeArray()
    if arr = invalid then return
    items = [{title: "Todas", id: ""}]
    for each c in arr
        if c.category_name <> invalid then items.Push({title: anyToStr(c.category_name), id: anyToStr(c.category_id)})
    end for
    renderScreen({kind: "categories", title: m.sectionTitle, items: items, focus: 0}, true)
end sub

sub loadItems(category as object)
    actions = {live: "get_live_streams", vod: "get_vod_streams", series: "get_series"}
    params = {}
    if category.id <> "" then params.category_id = category.id
    m.categoryTitle = category.title
    setStatus("Carregando " + category.title + "...")
    xtream(actions[m.section], params, "onItems")
end sub

sub onItems()
    arr = takeArray()
    if arr = invalid then return
    items = []
    for each s in arr
        if s.name <> invalid then
            if m.section = "series" then
                items.Push({title: anyToStr(s.name), id: anyToStr(s.series_id)})
            else
                ext = "mp4"
                if s.container_extension <> invalid and s.container_extension <> "" then ext = anyToStr(s.container_extension)
                item = {title: anyToStr(s.name), id: anyToStr(s.stream_id), ext: ext}
                if m.section = "live" and s.container_extension <> invalid and s.container_extension <> "" then item.liveExt = ext
                items.Push(item)
            end if
        end if
    end for
    if items.Count() = 0 then
        setStatus("Nenhum item nesta categoria")
        return
    end if
    setStatus(anyToStr(items.Count()) + " itens")
    renderScreen({kind: "items", title: m.sectionTitle + " › " + m.categoryTitle, items: items, focus: 0}, true)
end sub

sub loadSeriesInfo(serie as object)
    m.serieTitle = serie.title
    setStatus("Carregando " + serie.title + "...")
    xtream("get_series_info", {series_id: serie.id}, "onSeriesInfo")
end sub

sub onSeriesInfo()
    res = takeResult()
    if res = invalid then return
    data = invalid
    if res.body <> "" then data = ParseJson(res.body)
    if data = invalid or data.episodes = invalid then
        setStatus("Série sem episódios disponíveis")
        return
    end if
    m.episodes = data.episodes     ' {"1": [...], "2": [...]}
    seasons = []
    for each k in data.episodes
        seasons.Push({title: "Temporada " + k, id: k, n: Val(k)})
    end for
    seasons.SortBy("n")
    if seasons.Count() = 1 then
        showEpisodes(seasons[0])
        return
    end if
    setStatus("")
    renderScreen({kind: "seasons", title: m.serieTitle, items: seasons, focus: 0}, true)
end sub

sub showEpisodes(season as object)
    eps = m.episodes[season.id]
    items = []
    if eps <> invalid then
        for each e in eps
            ext = "mp4"
            if e.container_extension <> invalid and e.container_extension <> "" then ext = anyToStr(e.container_extension)
            label = "E" + anyToStr(e.episode_num)
            if e.title <> invalid then label = label + " - " + anyToStr(e.title)
            items.Push({title: label, id: anyToStr(e.id), ext: ext})
        end for
    end if
    setStatus("")
    renderScreen({kind: "episodes", title: m.serieTitle + " › " + season.title, items: items, focus: 0}, true)
end sub

' ─────────────────────────── Player ───────────────────────────

sub playStream(kind as string, id as string, ext as string, title as string)
    if m.mode = "dev" then
        url = buildUrl(m.cfg.backendBase + "/license/device/stream", {mac: m.mac, key: m.key, pl: m.pl, type: kind, id: id, ext: ext})
    else
        url = buildUrl(m.cfg.apiBase + "/api/stream", {si: m.si, type: kind, id: id, ext: ext, username: m.un, password: m.pw})
    end if
    content = CreateObject("roSGNode", "ContentNode")
    content.url = url
    content.title = title
    fmt = LCase(ext)
    if fmt = "m3u8" then
        content.streamFormat = "hls"
    else if fmt = "mp4" or fmt = "m4v" or fmt = "mov" then
        content.streamFormat = "mp4"
    else if fmt = "mkv" then
        content.streamFormat = "mkv"
    else if fmt = "ts" then
        content.streamFormat = "ts"
    end if
    if kind = "live" then content.live = true
    m.video.content = content
    m.video.visible = true
    m.video.setFocus(true)
    m.video.control = "play"
    setStatus("")
end sub

sub onVideoState()
    state = m.video.state
    if state = "error" then
        msg = "Não foi possível reproduzir"
        if m.video.errorMsg <> invalid and m.video.errorMsg <> "" then msg = msg + ": " + m.video.errorMsg
        closeVideo()
        setStatus(msg)
    else if state = "finished" then
        closeVideo()
    end if
end sub

sub closeVideo()
    m.video.control = "stop"
    m.video.visible = false
    m.list.setFocus(true)
end sub

' ─────────────────────────── Controle remoto ───────────────────────────

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back" then
        if m.video.visible then
            closeVideo()
            return true
        end if
        if m.stack.Count() > 1 then
            m.stack.Pop()
            renderScreen(m.stack[m.stack.Count() - 1], false)
            setStatus("")
            return true
        end if
        return false   ' na tela inicial, voltar sai do canal
    end if
    return false
end function

' ─────────────────────────── Rede ───────────────────────────

sub xtream(action as string, extra as object, callback as string)
    if m.mode = "dev" then
        params = {mac: m.mac, key: m.key, pl: m.pl, action: action}
    else
        params = {si: m.si, username: m.un, password: m.pw, action: action}
    end if
    for each k in extra
        params[k] = extra[k]
    end for
    if m.mode = "dev" then
        requestUrl(m.cfg.backendBase + "/license/device/xtream", params, "", callback)
    else
        request("/api/xtream", params, callback)
    end if
end sub

sub request(path as string, params as object, callback as string)
    requestUrl(m.cfg.apiBase + path, params, "", callback)
end sub

' POST com JSON no backend (licença e listas do aparelho)
sub postJson(path as string, body as object, callback as string)
    requestUrl(m.cfg.backendBase + path, {}, FormatJson(body), callback)
end sub

sub requestUrl(url as string, params as object, body as string, callback as string)
    m.busy = true
    task = CreateObject("roSGNode", "HttpTask")
    task.url = url
    task.params = params
    task.body = body
    task.observeField("result", callback)
    m.task = task
    task.control = "RUN"
end sub

' Resultado da última requisição (invalid = ainda não chegou)
function takeResult() as dynamic
    if m.task = invalid then return invalid
    res = m.task.result
    if res = invalid then return invalid
    m.busy = false
    m.task = invalid
    if not res.ok then setStatus("Erro: " + res.error)
    return res
end function

function takeArray() as dynamic
    res = takeResult()
    if res = invalid or not res.ok then return invalid
    data = ParseJson(res.body)
    if type(data) <> "roArray" then
        setStatus("Resposta inesperada do servidor")
        return invalid
    end if
    return data
end function

sub setStatus(text as string)
    m.status.text = text
end sub
