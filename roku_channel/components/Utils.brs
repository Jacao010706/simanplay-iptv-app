' Utilitários compartilhados (render thread e tasks).

' Codifica texto para URL (UTF-8). Não usa roUrlTransfer, então funciona em qualquer thread.
function urlEncode(value as dynamic) as string
    s = anyToStr(value)
    hexDigits = "0123456789ABCDEF"
    bytes = CreateObject("roByteArray")
    bytes.FromAsciiString(s)
    out = ""
    for i = 0 to bytes.Count() - 1
        b = bytes[i]
        isAlnum = (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)
        isSafe = (b = 45 or b = 46 or b = 95 or b = 126) ' - . _ ~
        if isAlnum or isSafe then
            out = out + Chr(b)
        else
            out = out + "%" + Mid(hexDigits, (b >> 4) + 1, 1) + Mid(hexDigits, (b and 15) + 1, 1)
        end if
    end for
    return out
end function

' Monta "base?k=v&k2=v2" a partir de um assocarray
function buildUrl(base as string, params as object) as string
    url = base
    sep = "?"
    if Instr(1, base, "?") > 0 then sep = "&"
    if params <> invalid then
        for each k in params
            url = url + sep + k + "=" + urlEncode(params[k])
            sep = "&"
        end for
    end if
    return url
end function

' Converte "#RRGGBB" / "RRGGBB" em "0xRRGGBBFF" (formato de cor do SceneGraph)
function sgColor(hex as string, fallback as string) as string
    h = hex
    if Left(h, 1) = "#" then h = Mid(h, 2)
    if Len(h) <> 6 then h = fallback
    return "0x" + UCase(h) + "FF"
end function

' Texto a partir de string/número/boolean (invalid vira "")
function anyToStr(v as dynamic) as string
    if v = invalid then return ""
    t = type(v)
    if t = "roString" or t = "String" then return v
    if t = "roInteger" or t = "Integer" or t = "roInt" or t = "LongInteger" or t = "roLongInteger" then return StrI(v).Trim()
    if t = "roFloat" or t = "Float" or t = "roDouble" or t = "Double" then return Str(v).Trim()
    if t = "roBoolean" or t = "Boolean" then
        if v then return "true"
        return "false"
    end if
    return ""
end function
