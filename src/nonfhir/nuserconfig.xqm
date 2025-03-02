xquery version "3.1";

module namespace nuc ="http://eNahar.org/ns/nonfhir/nuserconfig";

import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config = "http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';
import module namespace query  = "http://eNahar.org/ns/nonfhir/query" at '../modules/query.xqm';
(:
import module namespace parse = "http://eNahar.org/ns/lib/parse" at "../json/parse-fhir-resources.xqm";
:)
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
    let $uuid := $request?parameters?id
    let $ucs := collection($config:uconfig-data)/UserConfig[id/@value=$uuid]
    return
      if (count($ucs)=1) then
        switch ($accept)
        case "application/xml" return $ucs
        case "application/json" return mutil:resource2json($ucs)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nuserconfig: ", map { "info": "invalid uuuid"})
};

(:~
 : GET: /UserConfig?query
 : search userconfig
 :
 : @param $actor   string
 : @param $verified  boolean
 : @return bundle of <UserConfig/>
 :)
declare function nuc:search-userconfig($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := query:analyze($request?parameters?_elements,"string")
    let $identifier := query:analyze($request?parameters?identifier,"token")
    let $actor  := query:analyze($request?parameters?actor,"reference")
    let $active := query:analyze($request?parameters?active, "boolean", "true")
    let $verified := query:analyze($request?parameters?verified, "boolean", "true")
    let $coll := collection($config:uc-data)
    let $now := date:now()
    let $hits0 := if (count($identifier)>0)
        then $coll/UserConfig[identifier/value[@value=$identifier]]
        else if (count($actor)=0)
        then $coll/UserConfig[active[@value=$active]][verified[@value=$verified]]
        else let $oref := concat('metis/practitioners/', $actor)
            return 
                $coll/UserConfig[actor/reference[@value=$oref]][active[@value=$active]]
    let $sorted-hits :=
        for $c in $hits0
        order by lower-case($c/actor/display/@value/string())
        return
(: TODO analyze elements id, owner, schedule :)
            if (count($elems)>0)
            then
                <UserConfig xmlns="http://hl7.org/fhir">
                  {$c/id}
                { for $p in $c/*[not(self::id)]
                  return
                    if (local-name($p)=$elems) then $p else ()
                }
                </UserConfig>
            else $c
    return
      switch ($accept)
      case "application/xml" return
        mutil:prepareResultBundleXML($sorted-hits, 1, "*")
      case "application/json" return
          mutil:prepareResultBundleJSON($sorted-hits, 1, "*")
      default return
          error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
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
 : PUT: /UserConfig/{$id}
 : Update an existing userconfig or store a new one. The address XML is read
 : from the request body.
 : 
 : @return <response>
 :)
declare function nuc:putUserConfigJSON($request as map(*))
{
    let $uuid := $request?parameters?id
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
