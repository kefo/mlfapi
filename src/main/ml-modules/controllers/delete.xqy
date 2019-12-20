xquery version "1.0";

(: IMPORTS :)
import module namespace sem = "http://marklogic.com/semantics" at "/MarkLogic/semantics.xqy";

import module namespace headers      = "info:lc/mlfapi/headers#" at "../helpers/headers.xqy";
import module namespace shared      = "info:lc/mlfapi/shared#" at "../helpers/shared.xqy";
import module namespace authenticate = "info:lc/mlfapi/authenticate#" at "../helpers/authenticate.xqy";

(: NAMESPACES :)
declare namespace mets = "http://www.loc.gov/METS/";
declare namespace xdmp  = "http://marklogic.com/xdmp";
declare namespace map   = "http://marklogic.com/xdmp/map";

let $headers := headers:get()
let $auth-details := headers:auth-details()

let $is-admin := 
    if ( fn:empty(map:get($auth-details, "user")) ) then
        fn:false()
    else
        authenticate:is-admin( map:get($auth-details, "user") )

let $login := 
    if ($is-admin) then
        authenticate:login(map:get($auth-details, "user"), map:get($auth-details, "password"))
    else
        fn:false()

let $protocol := xdmp:get-request-protocol()
let $hostname := xdmp:host-name(xdmp:host())
let $port := xs:string(xdmp:get-request-port())
let $port-str := 
    if ($protocol eq "http" and $port eq "80") then
        ""
    else if ($protocol eq "https" and $port eq "443") then
        ""
    else 
        fn:concat(":", $port)

let $hostbase := fn:concat($protocol, "://", $hostname, $port-str)

let $uriinfo := shared:getUriInfo()
let $uribase := map:get($uriinfo, "uribase")
let $uripath := map:get($uriinfo, "uripath")
let $uri := map:get($uriinfo, "uri")
let $mldocuri := map:get($uriinfo, "mldocuri")

return
    if ( $is-admin eq fn:false() or $login eq fn:false() ) then
        (
            xdmp:set-response-code(401, "401 Unauthorized"),
            "401 Unauthorized"
        )
    else if ( fn:doc-available($mldocuri) eq fn:false() ) then
        (
            xdmp:set-response-code(404, "404 Not Found"),
            "404 Not Found - Resource Not Found"
        )
    else
        let $_ := xdmp:document-delete($mldocuri)
        return
            (
                xdmp:set-response-code(204, "204 Deleted"),
                ()
            )

