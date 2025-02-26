xquery version "3.1";

module namespace nreport="http://eNahar.org/ns/nonfhir/nreport";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors ="http://e-editiones.org/roaster/errors";
import module namespace date   ="http://eNahar.org/ns/lib/date";
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config = "http://eNahar.org/ns/nonfhir/config" at "../modules/config.xqm";
import module namespace query  = "http://eNahar.org/ns/nonfhir/query" at "../modules/query.xqm";

declare namespace fhir   = "http://hl7.org/fhir";


(:~
 : GET: /Report/{uuid}
 : get Report by id
 : 
 : @param $id  uuid
 : 
 : @return <Report/>
 :)
declare function nreport:read-report($request as map(*)) as item()
{
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $uuid   := $request?parameters?id
    let $reports := collection($config:report-data)/Report[id[@value=$uuid]]
    return
        if (count($reports)=1) then
        switch ($accept)
        case "application/xml" return $reports
        case "application/json" return mutil:resource2json($reports)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nreport: ", map { "info": "invalid uuid"})
};

(:~
 : GET: enahar/report?query
 : get reports
 :
 : @param $type   string
 : @param $name   string
 : @param $active  boolean
 : @return bundle of <cal/>
 :)
declare function nreport:search-report($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := $request?parameters?_elements
    let $type   := $request?parameters?type
    let $name   := $request?parameters?name
    let $serviceType := $request?parameters?serviceType
    let $active := query:analyze($request?parameters?active,'boolean', true())
    let $lll := util:log-app('TRACE','app.nabu', $request?parameters)
    let $coll  := collection($config:report-data)
    let $hits0 := if (count($type)>0)
        then $coll/Report[active[@value=$active]][type[@value=$type]]
        else $coll/Report[active[@value=$active]]
    let $valid := if (count($name)>0)
        then $hits0[matches(name/@value,$name)]
        else $hits0

    let $sorted-hits :=
        for $c in $hits0
        order by lower-case($c/name/@value/string())
        return
            if (string-length($elems)>0)
            then
                <Report>
                  {$c/id}
                { for $p in $c/*[not(self::id)]
                  return
                    if (local-name($p)=$elems) then $p else ()
                }
                </Report>
            else $c
    return
        switch ($accept)
        case "application/xml" return 
                mutil:prepareResultBundleXML($sorted-hits,1,"*")
        case "application/json" return
    (:            mutil:prepareResultBundleJSON($sorted-hits,1,"*") :)
                array {
                  for $service in $sorted-hits
                  return
                    map {
                          "resourceType" : "Report"
                        , "id" : $service/id/@value/string()
                        , "text" : $service/name/@value/string()
                        }
                      }
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
};
 
(:~
 : PUT: /report/{uuid}
 : Update an existing calendar or store a new one.
 : 
 : @param $content
 :)
declare function nreport:update-report($request as map(*))
{
    let $user := sm:id()//sm:real/sm:username/string()
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid   := $request?parameters?id
    let $content:= $request?parameters?body/node()
    let $isNew   := not($content/Report/@xml:id)
    let $cid   := if ($isNew)
        then switch($content/Report/type/@value) 
             case 'meeting' return "me-" || $content/Report/name/@value/string()
             default return 'sched-' || $content/Report/name/@value/string()
        else 
            let $id := $content/Report/id/@value/string()
            let $rs := collection($config:report-data)/Report[id[@value = $id]]
            let $move := mutil:moveToHistory($rs, $config:reportHistory)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Report/meta/versionId/@value/string()) + 1
    let $elems := $content/Report/*[not(
                   self::meta
                or self::id
                or self::identifier
                )]
    let $uuid := if ($isNew)
        then 'r-' || util:uuid()
        else $cid
    let $meta := $content/Report/meta/*[not(
                   self::versionId
                or self::lastUpdated
                or self::extension
                )]
    let $data :=
        <Report xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                <versionId value="{$version}"/>
                <extension url="http://eNahar.org/ns/extension/lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>    
                <lastUpdated value="{date:now()}"/>
            </meta>
            <identifier>
                <use value="official"/>
                <system value="http://eNahar.org/ns/extension/enahar-id"/>
                <value value="{$cid}"/>
            </identifier>
            {$elems}
        </Report>
        
(:
    let $lll := util:log-app('TRACE','apps.nabu',$data)
:)

    let $file := $uuid || ".xml"
    return
    try {
        system:as-user('vdba', 'kikl823!', (
            xmldb:store($nreport:report-data, $file, $data)
            , sm:chmod(xs:anyURI($nreport:report-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($nreport:report-data || '/' || $file), $config:data-group)))
    } catch * {
        error($errors:UNAUTHORIZED, "Permission denied", map { "info": "ask the admin"})
    }
};

