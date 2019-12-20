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

declare namespace   rdf             = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";

declare function local:collectContainerMembers($containeruri)
{
    let $query := "
        CONSTRUCT {
            $containeruri <http://www.w3.org/ns/ldp#contains> ?resources
        } WHERE {
            ?resources <info:lc/ldp/container> $containeruri 
        }
        "
    let $vars := 
        map:new((
            map:entry("containeruri", sem:iri($containeruri))
        ))
    let $rdf := sem:sparql($query, $vars)
    return $rdf
};

declare function local:processRDFXML($rdfxml, $acceptType, $uribase, $hostbase)
{
    let $rdfxml-str := xdmp:quote($rdfxml)
    let $rdfxml-str := fn:replace($rdfxml-str, $uribase, $hostbase)
    let $rdfxml := xdmp:unquote($rdfxml-str)

    let $rdfParseType := xs:string($shared:contenttypes/contentType[mimeType = $acceptType]/rdfParseType)
    let $rdfParseType := 
        if ($rdfParseType eq "") then
            "rdfxml"
        else
            $rdfParseType
    let $rdf := 
        if ($rdfParseType eq "rdfxml") then
            $rdfxml
        else
            sem:rdf-serialize(sem:rdf-parse($rdfxml, "rdfxml"), $rdfParseType)
    return $rdf
};

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

let $uriinfo := shared:getUriInfo()
let $uribase := map:get($uriinfo, "uribase")
let $uripath := map:get($uriinfo, "uripath")
let $uri := map:get($uriinfo, "uri")
let $mldocuri := map:get($uriinfo, "mldocuri")

let $containerisroot := map:get($uriinfo, "containerisroot")
let $containerpath := map:get($uriinfo, "containerpath")
let $containeruri := map:get($uriinfo, "containeruri")

let $hostbase := map:get($uriinfo, "hostbase")

let $_ := xdmp:log($uriinfo)

let $view := xdmp:get-request-field("view")

return
    if ( $is-admin eq fn:false() or $login eq fn:false() ) then
        (
            xdmp:set-response-code(401, "401 Unauthorized"),
            "401 Unauthorized"
        )
    else if ($uripath eq '/') then
        let $container-members := local:collectContainerMembers($uri)
        let $rdfxml := sem:rdf-serialize($container-members, "rdfxml")
        let $acceptType := headers:get-acceptType()
        let $content := local:processRDFXML($rdfxml, $acceptType, $uribase, $hostbase)
        let $content := 
            if ($acceptType eq "text/html") then
                let $div := 
                    <div class="container">
                        <div class="row">
                            <div class=".col-md-12">
                                <pre>
                                    <code>{$content}</code>
                                </pre>
                            </div>
                        </div>
                        <div class="row">
                            <div class=".col-md-12">
                                <table class="table">
                                <tbody>
                                    <tr>
                                        <td>Contains: </td>
                                        <td>
                                            {
                                                for $t in $container-members
                                                let $avalue := xs:string(sem:triple-object($t))
                                                let $avalue := fn:replace($avalue, $uribase, $hostbase)
                                                return 
                                                    (
                                                        <a href="{$avalue}">{$avalue}</a>,
                                                        <br />
                                                    )
                                            }
                                        </td>
                                    </tr>
                                </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                return shared:produceBasicHTMLPage($div)
            else
                $content
        return
            (
                xdmp:set-response-code(200, "200 OK"),
                xdmp:set-response-content-type($acceptType),
                $content
            )
    else if ( fn:doc-available($mldocuri) eq fn:false() ) then
        (
            xdmp:set-response-code(404, "404 Not Found"),
            "404 Not Found - Resource Not Found"
        )
    else if ($view eq "mets") then
        (
            xdmp:set-response-code(200, "200 OK"),
            xdmp:set-response-content-type("application/xml"),
            fn:doc($mldocuri)
        )
    else
        (: 
        Since we're not dealing with binaries presently, we an assume 
        everything is a container.
        :)
        let $container-members := local:collectContainerMembers($uri)
        let $container-members-rdfxml := sem:rdf-serialize($container-members, "rdfxml")
        
        let $doc := fn:doc($mldocuri)
        let $rdfxml := $doc/mets:mets/mets:dmdSec[@ID="rdf"]/mets:mdWrap[fn:last()]/mets:xmlData/child::node()[fn:name()]
        let $rdfxml := 
            element rdf:RDF {
                $rdfxml/child::node()[fn:name()],
                $container-members-rdfxml/child::node()[fn:name()]
            }
        let $acceptType := headers:get-acceptType()
        let $content := local:processRDFXML($rdfxml, $acceptType, $uribase, $hostbase)
        let $content := 
            if ($acceptType eq "text/html") then
                let $div := 
                    <div class="container">
                        <div class="row">
                            <div class=".col-md-12">
                                <table class="table">
                                <tbody>
                                    <tr>
                                        <td>URI: </td><td>{fn:replace($uri, $uribase, $hostbase)}</td>
                                    </tr>
                                    <tr>
                                        <td>Last modified: </td><td>{xs:string($doc/mets:mets/mets:metsHdr/@LASTMODDATE)}</td>
                                    </tr>
                                    <tr>
                                        <td>View mets: </td><td><a href="{$uripath}.mets.xml">{$uripath}.mets.xml</a></td>
                                    </tr>
                                    <tr>
                                        <td>Container: </td><td><a href="{$containerpath}">{$containerpath}</a></td>
                                    </tr>
                                </tbody>
                                </table>
                            </div>
                        </div>
                        <div class="row">
                            <div class=".col-md-12">
                                <pre>
                                    <code>{$content}</code>
                                </pre>
                            </div>
                        </div>
                        <div class="row">
                            <div class=".col-md-12">
                                <table class="table">
                                <tbody>
                                    <tr>
                                        <td>Contains: </td>
                                        <td>
                                            {
                                                for $t in $container-members
                                                let $avalue := xs:string(sem:triple-object($t))
                                                let $avalue := fn:replace($avalue, $uribase, $hostbase)
                                                return 
                                                    (
                                                        <a href="{$avalue}">{$avalue}</a>,
                                                        <br />
                                                    )
                                            }
                                        </td>
                                    </tr>
                                </tbody>
                                </table>
                            </div>
                        </div>
                    </div>
                return shared:produceBasicHTMLPage($div)
            else
                $content
        return
            (
                xdmp:set-response-code(200, "200 OK"),
                xdmp:set-response-content-type($acceptType),
                $content
            )

