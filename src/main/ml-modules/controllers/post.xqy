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

let $uriinfo := shared:getUriInfo()
let $uribase := map:get($uriinfo, "uribase")
let $uripath := map:get($uriinfo, "uripath")
let $uri := map:get($uriinfo, "uri")
let $mldocuri := map:get($uriinfo, "mldocuri")

let $containerisroot := map:get($uriinfo, "containerisroot")
let $containerdocuri := map:get($uriinfo, "containerdocuri")
let $containerpath := map:get($uriinfo, "containerpath")
let $containeruri := map:get($uriinfo, "containeruri")

let $location := map:get($uriinfo, "location")

let $_ := xdmp:log($uriinfo)

return
    if ( $is-admin eq fn:false() or $login eq fn:false() ) then
        (
            xdmp:set-response-code(401, "401 Unauthorized"),
            "401 Unauthorized"
        )
    else if ( fn:doc-available($mldocuri) ) then
        (
            xdmp:set-response-code(403, "403 Forbidden"),
            "403 Forbidden - Cannot updated existing resource via POST; Cannot reuse URI."
        )
    else if ( $containerisroot or fn:doc-available($containerdocuri) ) then
        let $content-type := map:get($headers, "content-type")
        let $bodytype := xs:string($shared:contenttypes/contentType[mimeType = $content-type][1]/bodyType)
        let $bodytype := 
            if ($bodytype eq "") then
                "binary"
            else
                $bodytype
        let $content := xdmp:get-request-body($bodytype)
        
        (: F it.  Just ignore binary right now. :)
        let $content-str := 
            if ($bodytype eq "xml") then
                xdmp:quote($content)
            else
                $content
        let $content-str := fn:replace($content-str, '<>', fn:concat('<', $uri, '>'))
        
        let $rdfParseType := xs:string($shared:contenttypes/contentType[mimeType = $content-type][1]/rdfParseType)
        
        let $rdf := 
            if ($rdfParseType ne "") then
                sem:rdf-parse($content-str, $rdfParseType)
            else
                "binary"
        
        let $rdfstore := sem:in-memory-store($rdf)
        let $query := "
            ASK { 
                # Note: If this pattern is not matched, it will return 'false'.
                # It seems counter-intuitive, but that is what we want.
                ?s ?p ?o . 
                FILTER( isIRI(?s) ) .
                FILTER( ?s != $uri ) .
            }
            "
        let $vars := 
            map:new((
                map:entry("uri", $uri)
            ))
        let $is-multiple-resources := sem:sparql($query, $vars, (), $rdfstore)
        
        (: Also would need to check for no server-managed or spec-managed triples :)
        
        let $rdfxml := sem:rdf-serialize($rdf, "rdfxml")
        let $rdfxml-hash := xdmp:md5($rdfxml)
        let $metsHdr := <mets:metsHdr LASTMODDATE="{fn:current-dateTime()}"/>
        let $mdWrap := 
            <mets:mdWrap MDTYPE="OTHER" CREATED="{fn:current-dateTime()}" CHECKSUM="{$rdfxml-hash}">
                <mets:xmlData>{sem:rdf-serialize($rdf, "rdfxml")}</mets:xmlData>
            </mets:mdWrap>
            
        let $ldp-triples := 
            (
                sem:triple( sem:iri($uri), sem:iri("info:lc/ldp/container"), sem:iri($containeruri) )    
            )
        let $mdWrap-semtriples := 
            <mets:mdWrap MDTYPE="OTHER" CREATED="{fn:current-dateTime()}">
                <mets:xmlData>{sem:rdf-serialize($ldp-triples, "triplexml")}</mets:xmlData>
            </mets:mdWrap>
                
        return
            if ($is-multiple-resources eq fn:true()) then
                (
                    xdmp:set-response-code(409, "409 Conflict - Single Subject violation"),
                    "409 Conflict - Single Subject violation"
                )  
            else if ( fn:doc-available($mldocuri) ) then
                let $doc := fn:doc($mldocuri)
                
                let $existing-mdWrap := $doc/mets:mets/mets:dmdSec[@ID="rdf"]/mets:mdWrap[fn:last()]
                let $_ := xdmp:node-insert-after($existing-mdWrap, $mdWrap)
                
                let $existing-metsHdr := $doc/mets:mets/mets:metsHdr
                let $_ := xdmp:node-replace($existing-metsHdr, $metsHdr)
                return (xdmp:set-response-code(204, "204 Updated"), ())
            else
                let $doc := 
                    <mets:mets 
                        PROFILE="metadataRecord" 
                        OBJID="{$mldocuri}" 
                        xsi:schemaLocation="http://www.loc.gov/METS/ http://www.loc.gov/standards/mets/mets.xsd" 
                        xmlns:idx="info:lc/xq-modules/lcindex" 
                        xmlns:xlink="http://www.w3.org/1999/xlink" 
                        xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" 
                        xmlns:mets="http://www.loc.gov/METS/" 
                        xmlns:semtriples="http://marklogic.com/semantic" 
                        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
                        {$metsHdr}
                        <mets:dmdSec ID="rdf">
                            {$mdWrap}
                        </mets:dmdSec>
                        <mets:dmdSec ID="semtriples">
                            {$mdWrap-semtriples}
                        </mets:dmdSec>
                        <mets:structMap>
                            <mets:div TYPE="record" DMDID="rdf semtriples"/>
                        </mets:structMap>
                    </mets:mets>
        
                let $_ := 
                    xdmp:document-insert(
                        $mldocuri, 
                        $doc,
                        (
                            xdmp:permission("mlfapi-reader", "read"),
                            xdmp:permission("mlfapi-writer", "update"),
                            xdmp:permission("mlfapi-writer", "insert")
                        )
                    )
        
                return 
                    (
                        xdmp:set-response-code(201, "201 Created"), 
                        xdmp:add-response-header("Location", $location),
                        ()
                    )

    else if ( fn:doc-available($containerdocuri) eq fn:false() ) then
        (
            xdmp:set-response-code(404, "404 Not Found"),
            "401 Not Found"
        )
    else
        (
            xdmp:set-response-code(400, "400 Bad Request"),
            "400 Bad Request"
        )

