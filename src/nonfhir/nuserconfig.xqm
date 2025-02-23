xquery version "3.1";

module namespace nuc ="http://eNahar.org/ns/nonfhir/nuserconfig";

import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config="http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';

import module namespace parse = "http://eNahar.org/ns/lib/parse" at "../json/parse-fhir-resources.xqm";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace date  ="http://eNahar.org/ns/lib/date";

declare namespace fhir   = "http://hl7.org/fhir";

(:~
 : GET: /UserConfig/{uuuid}
 : get user configuration
 : 
 : 
 : @return <UserConfig/>
 :)
declare function nuc:read-userconfig($request as map(*)) as item()
{
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid := $request?parameters?uuid
    let $ucs := collection($config:uconfig-data)/UserConfig[id/@value=$uuid]
    return
      if (count($ucs)=1) then
        switch ($accept)
        case "application/xml" return $ucs
        case "application/json" return mutil:resource2json($ucs)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nuserconfig: ", map { "info": "invalid uuuid"})
};


declare %private function nuc:doPUT(
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
            let $uc := collection($config:uconfig-data)/fhir:UserConfig[fhir:id[@value = $pid]]
            return
                if (count($uc)>0)
                then let $move := mutil:moveToHistory($uc, $config:uconfigHistory)
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
                <lastUpdated value="{date:now()}"/>
                <extension url="http://eNahar.org/ns/extension/lastUpdatedBy">
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
            xmldb:store($config:uconfig-data, $file, $data)
            , sm:chmod(xs:anyURI($config:uconfig-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:uconfig-data || '/' || $file), $config:data-group)))
        return
            $data
    } catch * {
        mutil:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

declare %private function nuc:doPOST(
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
            let $uc := collection($config:uconfig-data)/fhir:UserConfig[fhir:id[@value = $pid]]
            return
                if (count($uc)>0)
                then let $move := mutil:moveToHistory($userconfigs, $config:uconfigHistory)
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
                <lastUpdated value="{date:now()}"/>
                <extension url="http://eNahar.org/ns/extension/lastUpdatedBy">
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
            xmldb:store($config:uconfig-data, $file, $data)
            , sm:chmod(xs:anyURI($config:uconfig-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:uconfig-data || '/' || $file), $config:data-group)))
        return
            (
              mutil:rest-response(200, 'userconfig sucessfully stored.')
            , $data
            )
    } catch * {
        mutil:rest-response(401, 'permission denied. Ask the admin.') 
    }
};

(:~
 : PUT: nabu/UserConfig
 : Update an existing userconfig or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare function nuc:putUserConfigJSON($request as map(*))
{
    let $json := util:binary-to-string($content)
    let $realm := ($realm,"kikl-spz")[1]
    let $loguid := ($loguid,"u-admin")[1]
    let $lognam := ($lognam,"putbot")[1]
    let $pmap := parse:json-to-xml(fn:parse-json($json))
    let $r := parse:resource-to-FHIR($pmap, "4.3")
let $lll := util:log-app('TRACE','apps.nabu',$r)
    return
        if ($r)
        then
            let $xml := nuc:doPUT($r, $realm, $loguid, $lognam)
            return
                (
                 mutil:rest-response(200, 'userconfig sucessfully stored.')
                , '{"response": "ok"}'
                )
        else
            mutil:rest-response(422, 'no content? Ask the admin.') 
};

(:~
 : PUT: /UserConfig/{$uuid}
 : Update an existing userconfig or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare function nuc:putUserConfigXML($request as map(*))
{
let $lll := util:log-app('TRACE','apps.nabu',$content)
    let $content := if($content/fhir:*)
        then $content
        else document {mutil:addNamespaceToXML($content/*,"http://hl7.org/fhir") }

    let $realm := ($realm,"kikl-spz")[1]
    let $loguid := ($loguid,"u-admin")[1]
    let $lognam := ($lognam,"putbot")[1]
    return
        if ($content/fhir:*)
        then
            let $xml := nuc:doPUT($content/fhir:*, $realm, $loguid, $lognam)
            return
                (
                 mutil:rest-response(200, 'userconfig sucessfully stored.')
                , $xml
                )
        else
            mutil:rest-response(422, 'no content? Ask the admin.') 
};
