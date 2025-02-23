xquery version "3.1";

module namespace nschedule="http://eNahar.org/ns/nonfhir/nschedule";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors ="http://e-editiones.org/roaster/errors";
import module namespace date   ="http://eNahar.org/ns/lib/date";
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config = "http://eNahar.org/ns/nonfhir/config" at "../modules/config.xqm";

declare namespace fhir   = "http://hl7.org/fhir";

declare variable $nschedule:data-perms := "rwxrwxr-x";
declare variable $nschedule:data-group := "spz";
declare variable $nschedule:perms      := "rwxr-xr-x";

declare variable $nschedule:schedule-data := "/db/apps/eNaharData/data/schedules";
declare variable $nschedule:scheduleHistory    := "/db/apps/eNaharHistory/data/Schedule";

declare function nschedule:update-schedulexxx($request as map(*)){
    let $user := sm:id()//sm:real/sm:username/string()
    let $collection := $request?parameters?collection
    let $payload := $request?body/node()
    (: let $stored := xmldb:store($config:page-root, $user || '-todos.xml' , $payload) :)
    return <stored>{$stored}</stored>
};

(:~
 : GET: /Schedule/{uuid}
 : get schedule by id
 : 
 : @param $id  uuid
 : 
 : @return <schedule/>
 :)
declare function nschedule:read-schedule($request as map(*)) as item()
{
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $uuid   := $request?parameters?id
    let $schedules := collection($config:ical-data)/cal[id[@value=$uuid]]
    return
        if (count($schedules)=1) then
        switch ($accept)
        case "application/xml" return $schedules
        case "application/json" return mutil:resource2json($schedules)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nschedule: ", map { "info": "invalid uuid"})
};

(:~
 : GET: enahar/schedule?query
 : get schedules
 :
 : @param $type   string
 : @param $name   string
 : @param $active  boolean
 : @return bundle of <cal/>
 :)
declare function nschedule:search-schedule($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := $request?parameters?_elements
    let $type   := $request?parameters?type
    let $name   := $request?parameters?name
    let $group  := $request?parameters?group
    let $active := $request?parameters?active
    let $lll := util:log-app('TRACE','app.nabu', $request?parameters)
    let $hits0 := if ($type and $type!='')
        then collection($config:ical-data)/schedule[type[@value=$type]][active[@value=$active]]
        else collection($config:ical-data)/schedule[active[@value="true"]]
    let $valid := if ($name)
        then $hits0
        else $hits0/schedule[matches(name/@value,$name)]

    let $sorted-hits :=
        for $c in $hits0
        order by lower-case($c/name/@value/string())
        return
            if (string-length($elems)>0)
            then
                <ICal>
                    {$c/id}
                    {$c/type}
                    {$c/name}
                    {$c/ff}
                </ICal>
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
                          "resourceType" : "ICal"
                        , "id" : $service/id/@value/string()
                        , "text" : $service/name/@value/string()
                        }
                      }
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
};
 
(:~
 : PUT: /Schedule/{uuid}
 : Update an existing calendar or store a new one.
 : 
 : @param $content
 :)
declare function nschedule:update-schedule($request as map(*))
{
    let $user := sm:id()//sm:real/sm:username/string()
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $content:= $request?parameters?body/node()
    let $isNew   := not($content/schedule/@xml:id)
    let $cid   := if ($isNew)
        then switch($content/schedule/type/@value) 
             case 'meeting' return "me-" || $content/schedule/name/@value/string()
             default return 'sched-' || $content/schedule/name/@value/string()
        else 
            let $id := $content/schedule/id/@value/string()
            let $scheds := collection($config:ical-data)/schedule[id[@value = $id]]
            let $move := mutil:moveToHistory($scheds, $config:icalHistory)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/schedule/meta/versionId/@value/string()) + 1
    let $elems := $content/schedule/*[not(
                   self::meta
                or self::id
                or self::identifier
                )]
    let $uuid := if ($isNew)
        then switch($content/schedule/type/@value) 
             case 'meeeting' return "me-" || util:uuid()
             default return 'sched-' || util:uuid()
        else $cid
    let $meta := $content/schedule/meta/*[not(
                   self::versionID
                or self::lastUpdated
                or self::extension
                )]
    let $data :=
        <schedule xml:id="{$uuid}">
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
        </schedule>
        
(:
    let $lll := util:log-app('TRACE','apps.nabu',$data)
:)

    let $file := $uuid || ".xml"
    return
    try {
        system:as-user('vdba', 'kikl823!', (
            xmldb:store($nschedule:schedule-data, $file, $data)
            , sm:chmod(xs:anyURI($nschedule:schedule-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($nschedule:schedule-data || '/' || $file), $config:data-group)))
    } catch * {
        error($errors:UNAUTHORIZED, "Permission denied", map { "info": "ask the admin"})
    }
};

