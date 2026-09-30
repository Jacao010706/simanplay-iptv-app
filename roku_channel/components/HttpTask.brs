sub init()
    m.top.functionName = "doRequest"
end sub

sub doRequest()
    port = CreateObject("roMessagePort")
    xfer = CreateObject("roUrlTransfer")
    xfer.SetMessagePort(port)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.EnableEncodings(true)
    xfer.RetainBodyOnError(true)
    xfer.AddHeader("Accept", "application/json")
    xfer.SetUrl(buildUrl(m.top.url, m.top.params))

    result = {ok: false, code: 0, body: "", error: ""}
    started = false
    if m.top.body <> invalid and m.top.body <> "" then
        xfer.AddHeader("Content-Type", "application/json")
        started = xfer.AsyncPostFromString(m.top.body)
    else
        started = xfer.AsyncGetToString()
    end if
    if started then
        msg = wait(30000, port)
        if type(msg) = "roUrlEvent" then
            result.code = msg.GetResponseCode()
            result.body = msg.GetString()
            if result.code >= 200 and result.code < 300 then
                result.ok = true
            else if result.code < 0 then
                result.error = "Falha de rede (" + msg.GetFailureReason() + ")"
            else
                result.error = "Servidor respondeu " + anyToStr(result.code)
            end if
        else
            xfer.AsyncCancel()
            result.error = "O servidor demorou para responder"
        end if
    else
        result.error = "Não foi possível iniciar a conexão"
    end if
    m.top.result = result
end sub
