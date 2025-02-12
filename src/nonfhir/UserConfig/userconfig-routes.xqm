xquery version "3.1";

(: 
 : Defines all the RestXQ endpoints used by the XForms.
 :)
module namespace r-userconfig = "http://enahar.org/exist/restxq/nabu/userconfig";

import module namespace config  = "http://enahar.org/exist/apps/nabu/config"    at "../../modules/config.xqm";
import module namespace nutil   = "http://eNahar.org/ns/nabu/util"    at "../../modules/nutils.xqm";
import module namespace bundle = "http://eNahar.org/ns/nabu/Bundle/util"    at "../Bundle/utils.xqm";
import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "../../FHIR/meta/serialize-fhir-resources.xqm";
import module namespace ju = "http://joewiz.org/ns/xquery/json-util" at "../../modules/json-util.xqm";
import module namespace parse = "http://enahar.org/exist/apps/nabu/parse" at "../../FHIR/meta/parse-fhir-resources.xqm";

declare namespace fo     = "http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  = "http://exist-db.org/xquery/xslfo";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare default element namespace "http://hl7.org/fhir";

(:~
 : GET: /nabu/UserConfig/{$id}/_history
 : get userconfig history with id $id
 : 
 : @param $id  doc id
 : 
 : @return  userconfig bundle
 :
declare
    %rest:GET
    %rest:path("/nabu/UserConfig/{$id}/_history")
    %rest:produces("application/xml", "text/xml")
function r-userconfig:userconfigHistoryByID(
      $id as xs:string*
    )
{
    let $coll := $r-userconfig:coll | collection($r-userconfig:history)
    let $hits  := $coll/UserConfig[id/@value=$id] 
    return
        bundle:prepareHistoryBundleXML($id, $hits)
};

 :~
 : GET: /nabu/UserConfig/{$id}/_history/{$vid}
 : get userconfig history with id $id and version $vid
 : 
 : @param $id userconfig id
 : @param $vid version id
 : 
 : @return  userconfig bundle
 : 
declare
    %rest:GET
    %rest:path("/nabu/UserConfig/{$id}/_history/{$vid}")
    %rest:query-param("start",  "{$start}", "1")
    %rest:query-param("length", "{$length}", "*")
    %rest:produces("application/xml", "text/xml")
function r-userconfig:userconfigVersionByID($id as xs:string*, $vid as xs:string*,
            $start as xs:string*, $length as xs:string*)
{
    let $coll := $r-userconfig:coll | collection($r-userconfig:history)
    let $hits  := $coll/fhir:UserConfig[fhir:id[@value=$id]][meta/versionId/@value=$vid]
    return
        bundle:prepareHistoryBundleXML($id, $hits)
};
:)

(:~
 : Search Parameters FHIR 4.3
 : status	token	in-progress | completed | suspended | rejected | failed	UserConfig.status
 : subject	reference	Focus of message	UserConfig.subject
 :)

(:~
 : GET: UserConfig
 : List UserConfig for subject
 : 
 : @param   $subject       ref
 : @param   $status        ('active')
 : @param   $format        ('full', 'count')
 : 
 : @return  bundle <UserConfig/>
 : 
 :)
declare
    %rest:GET
    %rest:path("nabu/UserConfig")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam",   "{$lognam}",  "")      
    %rest:query-param("identifier", "{$identifier}", "")
    %rest:query-param("active",  "{$active}", "")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/xml", "text/xml")
function r-userconfig:userconfigsXML(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $identifier as xs:string*
        ,   $active as xs:string*
        ,   $format as xs:string*
        ) as item()
{
  try{
    let $ll := util:log-app('TRACE','apps.nabu',count($r-userconfig:coll/fhir:UserConfig))

    let $matched0 := 
        if ($identifier="")
        then $r-userconfig:coll/fhir:UserConfig
        else $r-userconfig:coll/fhir:UserConfig[fhir:identifier[fhir:value/@value=$identifier]]
    let $ll := util:log-app('TRACE','apps.nabu',concat($identifier,': ',count($matched0)))
    let $matched := if ($active="")
        then $matched0
        else $matched0[fhir:active[@value=$active]]
    return
        bundle:resources2BundleXML($matched)
    } catch * {
        nutil:rest-response(401, concat('UserConfig: not found : ', $identifier))
    }
};
(:~
 : GET: nabu/UserConfig
 : List UserConfig for subject
 : 
 : @param   $subject       ref
 : @param   $active        true
 : @param   $format        ('full', 'count')
 : 
 : @return  bundle <UserConfig/>
 : 
 :)
declare
    %rest:GET
    %rest:path("nabu/UserConfig")
    %rest:query-param("realm", "{$realm}")
    %rest:query-param("loguid","{$loguid}")
    %rest:query-param("lognam",   "{$lognam}",  "")      
    %rest:query-param("identifier", "{$identifier}", "")
    %rest:query-param("active",  "{$active}", "")
    %rest:query-param("_format", "{$format}", "full")
    %rest:produces("application/json")
function r-userconfig:userconfigsJSON(
            $realm as xs:string*
        ,   $loguid as xs:string*
        ,   $lognam as xs:string*
        ,   $identifier as xs:string*
        ,   $active as xs:string*
        ,   $format as xs:string*
        ) as item()
{
  try{
    let $ll := util:log-app('TRACE','apps.nabu',count($r-userconfig:coll/fhir:UserConfig))

    let $matched0 := 
        if ($identifier="")
        then $r-userconfig:coll/fhir:UserConfig
        else $r-userconfig:coll/fhir:UserConfig[fhir:identifier[fhir:value/@value=$identifier]]
    let $ll := util:log-app('TRACE','apps.nabu',concat($identifier,': ',count($matched0)))
    let $matched := if ($active="")
        then $matched0
        else $matched0[fhir:active[@value=$active]]
    return
        serialize:resource2json(bundle:resources2BundleXML($matched), false(), "4.3")
    } catch * {
        nutil:rest-response(401, concat('UserConfig: not found : ', $identifier))
    }
};


declare %private function r-userconfig:doPUT(
      $content as item()
    , $realm as xs:string
    , $loguid as xs:string
    , $lognam as xs:string
    ) as item()+
{
    let $lll := util:log-app('TRACE','apps.nabu',$content)
    let $pid := $content/id/@value/string()
    let $id  := if ($pid and string-length($pid)>0)
        then
            (: lookup resource, and move it to history :)
            let $uc := $r-userconfig:coll/fhir:UserConfig[fhir:id[@value = $pid]]
            return
                if (count($uc)>0)
                then let $move := r-userconfig:moveToHistory($uc)
                    return $pid
                else if (count($uc)=0)
                then $pid
                else util:uuid()
        else util:uuid()

    let $version := if ($pid=$id) (: is new? :)
        then let $vid := $content/meta/versionId/@value
            return if ($vid)
                then xs:integer($vid) + 1
                else "0"
        else "0"
    let $base := $content/fhir:*[not(
                                    self::id
                                    or self::meta
                                )]
    let $meta := $content/meta/fhir:*[not(
                                        self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $data := 
        <UserConfig xmlns="http://hl7.org/fhir">
            <id value="{$id}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension/lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
            </meta>
            {$base}
        </UserConfig>
        
    let $lll := util:log-app('TRACE','apps.nabu',$data)

    let $file := $id || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-userconfig:nabu-userconfigs, $file, $data)
            , sm:chmod(xs:anyURI($r-userconfig:nabu-userconfigs || '/' || $file), $r-userconfig:data-perms)
            , sm:chgrp(xs:anyURI($r-userconfig:nabu-userconfigs || '/' || $file), $r-userconfig:data-group)))
        return
            $data
    } catch * {
        nutil:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function r-userconfig:doPOST(
      $content as item()
    , $realm as xs:string
    , $loguid as xs:string
    , $lognam as xs:string
    ) as item()+
{
    let $pid := $content/id/@value/string()
    let $id  := if ($pid and string-length($pid)>0)
        then
            (: lookup resource, and move it to history :)
            let $uc := $r-userconfig:coll/fhir:UserConfig[fhir:id[@value = $pid]]
            return
                if (count($uc)>0)
                then let $move := r-userconfig:moveToHistory($userconfigs)
                    return $pid
                else if (count($uc)=0)
                then $pid
                else util:uuid()
        else util:uuid()

    let $version := if ($pid=$id) (: is new? :)
        then let $vid := $content/meta/versionId/@value
            return if ($vid)
                then xs:integer($vid) + 1
                else "0"
        else "0"
    let $base := $content/fhir:*[not(
                                    self::id
                                    or self::meta
                                )]
    let $meta := $content/meta/fhir:*[not(
                                        self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $data := 
        <UserConfig xmlns="http://hl7.org/fhir">
            <id value="{$id}"/>
            <meta>
                {$meta}
                <versionId value="{$version}"/>
                <lastUpdated value="{current-dateTime()}"/>
                <extension url="http://eNahar.org/nabu/extension/lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
            </meta>
            {$base}
        </UserConfig>
        
    let $lll := util:log-app('TRACE','apps.nabu',$data)

    let $file := $id || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($r-userconfig:nabu-userconfigs, $file, $data)
            , sm:chmod(xs:anyURI($r-userconfig:nabu-userconfigs || '/' || $file), $r-userconfig:data-perms)
            , sm:chgrp(xs:anyURI($r-userconfig:nabu-userconfigs || '/' || $file), $r-userconfig:data-group)))
        return
            (
              nutil:rest-response(200, 'userconfig sucessfully stored.')
            , $data
            )
    } catch * {
        nutil:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : PUT: nabu/UserConfig
 : Update an existing userconfig or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/UserConfig")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:consumes("application/json")
function r-userconfig:putUserConfigJSON(
      $content as xs:base64Binary*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
    let $json := util:binary-to-string($content)
    let $realm := ($realm,"kikl-spz")[1]
    let $loguid := ($loguid,"u-admin")[1]
    let $lognam := ($lognam,"putbot")[1]
    let $pmap := ju:json-to-xml(fn:parse-json($json))
    let $r := parse:resource-to-FHIR($pmap, "4.3")
let $lll := util:log-app('TRACE','apps.nabu',$r)
    return
        if ($r)
        then
            let $xml := r-userconfig:doPUT($r, $realm, $loguid, $lognam)
            return
                (
                 nutil:rest-response(200, 'userconfig sucessfully stored.')
                , '{"response": "ok"}'
                )
        else
            nutil:rest-response(422, 'no content? Ask the admin.') 
};

(:~
 : PUT: nabu/UserConfig
 : Update an existing userconfig or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare
    %rest:PUT("{$content}")
    %rest:path("nabu/UserConfig")
    %rest:query-param("realm",  "{$realm}")
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:consumes("application/xml")
function r-userconfig:putUserConfigXML(
      $content as document-node()*
    , $realm as xs:string*
    , $loguid as xs:string*
    , $lognam as xs:string*
    ) as item()+
{
let $lll := util:log-app('TRACE','apps.nabu',$content)
    let $content := if($content/fhir:*)
        then $content
        else document {nutil:addNamespaceToXML($content/*,"http://hl7.org/fhir") }

    let $realm := ($realm,"kikl-spz")[1]
    let $loguid := ($loguid,"u-admin")[1]
    let $lognam := ($lognam,"putbot")[1]
    return
        if ($content/fhir:*)
        then
            let $xml := r-userconfig:doPUT($content/fhir:*, $realm, $loguid, $lognam)
            return
                (
                 nutil:rest-response(200, 'userconfig sucessfully stored.')
                , $xml
                )
        else
            nutil:rest-response(422, 'no content? Ask the admin.') 
};
