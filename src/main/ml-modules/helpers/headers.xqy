xquery version "1.0";

module namespace headers = 'info:lc/mlfapi/headers#';

declare namespace xdmp = "http://marklogic.com/xdmp";
declare namespace map = "http://marklogic.com/xdmp/map";

declare variable $headers:headers := map:map();

declare function headers:get-acceptType() as xs:string 
{
    let $accepts := fn:tokenize(map:get($headers:headers, "accept"), ",")
    let $accept-value := 
        if (fn:count($accepts) eq 1) then
            let $a := 
                if (fn:contains($accepts[1], ";")) then
                    fn:normalize-space(fn:substring-before($accepts[1], ";"))
                else
                    $accepts[1]
            return 
                if ( $a eq "" or $a eq "*/*" ) then
                    "text/turtle"
                else 
                    fn:replace($a , '\+' , '%2B')
        else
            let $accept-values := 
                for $a in $accepts
                let $avalue := 
                    if (fn:contains($a, ";")) then
                        fn:tokenize($a, ";")[1]
                    else
                        $a
                let $avalue := fn:normalize-space($avalue)
                let $qvalue := 
                    if (fn:contains($a, ";")) then
                        let $semicolon := fn:normalize-space(fn:tokenize($a, ";")[2])
                        return
                            if ( fn:starts-with($semicolon, "q=") ) then
                                xs:decimal(fn:replace($semicolon, "q=", ""))
                            else
                                xs:decimal(1.0)
                    else
                        xs:decimal(1.0)
                order by $qvalue descending
                return $avalue
            return
                if ( fn:count($accept-values) > 0 and $accept-values[1] ne "" and $accept-values[1] ne "*/*" ) then
                    fn:replace($accept-values[1] , '\+' , '%2B')
                else 
                    "text/turtle"
    return $accept-value
};

declare function headers:get() as map:map 
{
    if ( fn:count(map:keys($headers:headers)) > 0 ) then
        $headers:headers
    else
        let $header-names := xdmp:get-request-header-names()
        let $_ := 
            for $hname in $header-names
            let $hn := fn:lower-case($hname)
            return 
                if ( map:get($headers:headers, $hn) ) then
                    map:put($headers:headers, $hn, (map:get($headers:headers, $hn), xdmp:get-request-header($hn)))
                else
                    map:put($headers:headers, $hn, xdmp:get-request-header($hn))
        return $headers:headers
};

declare function headers:auth-details() as map:map
{
    if ( map:get($headers:headers, "authorization") ) then
        let $value := map:get($headers:headers, "authorization")
        let $creds := xdmp:base64-decode(fn:replace($value, "Basic ", ""))
        return
            if ( fn:contains($creds, ":") ) then
                let $cred_parts := fn:tokenize($creds, ":")
                return
                    map:new((
                        map:entry("user", $cred_parts[1]),
                        map:entry("password", $cred_parts[2])
                    ))
            else
                map:map()
    else
        map:map()
};


