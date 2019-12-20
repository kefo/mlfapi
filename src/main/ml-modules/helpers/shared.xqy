xquery version "1.0";

module namespace shared = 'info:lc/mlfapi/shared#';

import module namespace headers      = "info:lc/mlfapi/headers#" at "../helpers/headers.xqy";

declare namespace xdmp = "http://marklogic.com/xdmp";
declare namespace map = "http://marklogic.com/xdmp/map";

declare variable $shared:uriinfo := map:map();

declare variable $shared:contenttypes :=
    <contentTypes>
        <contentType>
            <mimeType>text/html</mimeType>
            <bodyType>binary</bodyType>
            <rdfParseType>turtle</rdfParseType>
        </contentType>
        <contentType>
            <mimeType>text/plain</mimeType>
            <mimeType>application/n-triples</mimeType>
            <bodyType>text</bodyType>
            <rdfParseType>ntriple</rdfParseType>
        </contentType>
        <contentType>
            <mimeType>text/turtle</mimeType>
            <mimeType>text/n3</mimeType>
            <mimeType>text/rdf+n3</mimeType>
            <mimeType>application/n3</mimeType>
            <bodyType>text</bodyType>
            <rdfParseType>turtle</rdfParseType>
        </contentType>
        <contentType>
            <mimeType>application/rdf+xml</mimeType>
            <mimeType>application/rdf%2Bxml</mimeType>
            <bodyType>xml</bodyType>
            <rdfParseType>rdfxml</rdfParseType>
        </contentType>
    </contentTypes>;
    
declare function shared:containerPath($uripath-parts, $position)
{
    let $next-position := $position - 1
    let $uparts := 
        for $up at $pos in $uripath-parts
        where $pos <= $next-position
        return $up
    let $containerpath := fn:concat('/', fn:string-join($uparts, '/'))
    let $containerdocuri := fn:concat($containerpath, ".xml")
    let $uribase := "info:lc"
    let $containeruri := fn:concat($uribase, $containerpath) 
    return
        if ( fn:doc-available($containerdocuri) ) then
            let $_ := map:put($shared:uriinfo, "containeruri", $containeruri)
            let $_ := map:put($shared:uriinfo, "containerdocuri", $containerdocuri)
            let $_ := map:put($shared:uriinfo, "containerpath", $containerpath)
            let $_ := map:put($shared:uriinfo, "containerisroot", fn:false())
            return ()
        else if ( $next-position eq 0 ) then
            let $containerpath := '/'
            let $containeruri := fn:concat($uribase, $containerpath) 
            let $_ := map:put($shared:uriinfo, "containeruri", $containeruri)
            let $_ := map:put($shared:uriinfo, "containerisroot", fn:true())
            let $_ := map:put($shared:uriinfo, "containerpath", '/')
            return ()
        else
            shared:containerPath($uripath-parts, $next-position)
};

declare function shared:getUriInfo() as map:map 
{
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
    let $_ := map:put($shared:uriinfo, "hostbase", $hostbase)
    
    let $uribase := "info:lc"
    let $uripath := fn:normalize-space(xdmp:get-request-field("uripath"))
    let $uripath := fn:replace($uripath, '^/', '')
    let $uripath := fn:replace($uripath, '/$', '')

    let $slug := 
        if ( xdmp:get-request-method() eq "POST" ) then
            let $headers := headers:get()
            return
                if ( fn:empty(map:get($headers, "slug")) eq fn:true() ) then
                    let $str := fn:concat($uripath, fn:current-dateTime(), xs:string(xdmp:random(10000)))
                    return xdmp:md5($str)
                else
                    map:get($headers, "slug")
        else
            ()
            
    let $uripath := 
        if ( fn:not(fn:empty($slug)) ) then
            fn:concat($uripath, "/", $slug)
        else
            $uripath
    let $uripath := 
        if ( fn:starts-with($uripath, '/') ) then
            $uripath
        else
            fn:concat("/", $uripath)
    

    let $uri := fn:concat($uribase, $uripath) 
    let $mldocuri := fn:concat($uripath, ".xml")
    
    let $uripath-parts := fn:tokenize($uripath, '/')
    let $uripath-parts := 
        for $up in $uripath-parts
        where $up ne ""
        return $up
    let $_ := xdmp:log("Parts: ")
    let $_ := xdmp:log($uripath-parts)
    let $_ := 
        if ( fn:count($uripath-parts) eq 0 ) then
            let $containerpath := '/'
            let $containeruri := fn:concat($uribase, $containerpath) 
            let $_ := map:put($shared:uriinfo, "containeruri", $containeruri)
            let $_ := map:put($shared:uriinfo, "containerisroot", fn:true())
            let $_ := map:put($shared:uriinfo, "containerpath", '/')
            return ()
        else if ( xdmp:get-request-method() eq "POST" ) then
            (: 
                POST requests are different.  If the immediate parent doesn't exist, 
                then the request needs to eventually fail.
                So we don't want to find the existing containter.  We need to
                operate on the assumption that the immediate parent is its
                parent.
            :)
            let $next-position := fn:count($uripath-parts) - 1
            let $uparts := 
                for $up at $pos in $uripath-parts
                where $pos <= $next-position
                return $up
            let $containerpath := fn:concat('/', fn:string-join($uparts, '/'))
            let $containerdocuri := fn:concat($containerpath, ".xml")
            let $uribase := "info:lc"
            let $containeruri := fn:concat($uribase, $containerpath) 
            
            let $_ := map:put($shared:uriinfo, "containeruri", $containeruri)
            let $_ := map:put($shared:uriinfo, "containerdocuri", $containerdocuri)
            let $_ := map:put($shared:uriinfo, "containerpath", $containerpath)
            let $_ := map:put($shared:uriinfo, "containerisroot", fn:false())
            return ()
        else
            shared:containerPath($uripath-parts, fn:count($uripath-parts))
    
    let $_ := map:put($shared:uriinfo, "uribase", $uribase)
    let $_ := map:put($shared:uriinfo, "uripath", $uripath)
    let $_ := map:put($shared:uriinfo, "uri", $uri)
    let $_ := map:put($shared:uriinfo, "mldocuri", $mldocuri)
    let $_ := map:put($shared:uriinfo, "location", fn:replace($uri, $uribase, $hostbase))
    
    return $shared:uriinfo
    
};

declare function shared:produceBasicHTMLPage($div)
{
    <html>
        <head>
            <!-- Required meta tags -->
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no" />

            <!-- Bootstrap CSS -->
            <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous" />
        </head>
        <body>{$div}</body>
    </html>  
};
