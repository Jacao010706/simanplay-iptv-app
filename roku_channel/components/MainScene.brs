' PRIMETV — canal Roku (SceneGraph).
' Fluxo: login -> menu (Ao Vivo / Filmes / Séries) -> categorias -> itens
'        (-> temporadas -> episódios, nas séries) -> player.
' Usa as mesmas rotas do app de TV do painel:
'   /api/tv-login  (descobre o servidor "si")
'   /api/xtream    (listas, API Xtream)
'   /api/stream    (redireciona para o vídeo sem expor o servidor)

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

    m.stack = []        ' pilha de telas: {kind, title, items, focus}
    m.busy = false
    m.reg = CreateObject("roRegistrySection", "primetv")
    m.un = m.reg.Read("un")
    m.pw = m.reg.Read("pw")
    m.si = m.reg.Read("si")

    if m.un <> "" and m.pw <> "" then
        doLogin()
    else
        askUser()
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
        setStatus("Pressione OK para entrar")
        showLoginPrompt()
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
    renderScreen({kind: "login", title: "Entrar", items: [{title: "Entrar com usuário e senha", action: "login"}], focus: 0}, true)
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
    m.reg.Flush()
    m.un = ""
    m.pw = ""
    m.stack = []
    setStatus("")
    askUser()
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
    renderScreen({kind: "menu", title: "Início", items: items, focus: 0}, true)
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

    if screen.kind = "login" then
        askUser()
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
            playStream("live", it.id, "m3u8", it.title)
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
                items.Push({title: anyToStr(s.name), id: anyToStr(s.stream_id), ext: ext})
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
    url = buildUrl(m.cfg.apiBase + "/api/stream", {si: m.si, type: kind, id: id, ext: ext, username: m.un, password: m.pw})
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
    params = {si: m.si, username: m.un, password: m.pw, action: action}
    for each k in extra
        params[k] = extra[k]
    end for
    request("/api/xtream", params, callback)
end sub

sub request(path as string, params as object, callback as string)
    m.busy = true
    task = CreateObject("roSGNode", "HttpTask")
    task.url = m.cfg.apiBase + path
    task.params = params
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
