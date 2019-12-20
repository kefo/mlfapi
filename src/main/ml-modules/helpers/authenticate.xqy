xquery version "1.0";

module namespace authenticate = 'info:lc/mlfapi/authenticate#';

import module namespace admin = "http://marklogic.com/xdmp/admin" at "/MarkLogic/admin.xqy";

declare namespace xdmp = "http://marklogic.com/xdmp";
declare namespace map = "http://marklogic.com/xdmp/map";
declare namespace sec = "http://marklogic.com/xdmp/security";

declare function authenticate:login($user, $pass) as xs:boolean
{
    let $config := admin:get-configuration()
    let $groupid := admin:group-get-id($config, "Default")
    let $authentication-type := admin:appserver-get-authentication($config, admin:appserver-get-id($config, $groupid, "8284-mlfapi-filesystemdb"))
    
    return
        if ($authentication-type = "application-level") then
            xdmp:login($user, $pass)
        else
            (: Authentication set to something else so ML has taken care of it :)
            fn:true()
};

declare function authenticate:is-admin($user) as xs:boolean
{
    let $roleids := xdmp:user-roles($user)
    let $query := '
        xquery version "1.0-ml";
        import module namespace sec="http://marklogic.com/xdmp/security" at  "/MarkLogic/security.xqy";
        declare variable $roleids external;
        sec:get-role-names($roleids)
        '
    let $vars := 
        map:new((
            map:entry("roleids", $roleids)
        ))
    let $options := 
        <options xmlns="xdmp:eval">
            <database>{xdmp:security-database()}</database>
        </options>
    let $roles := xdmp:eval($query, $vars, $options)

    return 
        if ( $roles[. = "admin"] ) then
            fn:true()
        else
            fn:false()
};
