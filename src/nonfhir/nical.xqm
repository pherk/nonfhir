xquery version "3.1";

module namespace nical="http://eNahar.org/ns/nonfhir/nical";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors ="http://e-editiones.org/roaster/errors";
import module namespace date   = "http://eNahar.org/ns/lib/date";
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config = "http://eNahar.org/ns/nonfhir/config" at "../modules/config.xqm";
import module namespace query  = "http://eNahar.org/ns/nonfhir/query" at "../modules/query.xqm";

declare namespace fhir   = "http://hl7.org/fhir";


(:~
 : GET: /ICal/{uuid}
 : get ICalendar by id
 : 
 : @param $id  uuid
 : 
 : @return <ICal/>
 :)
declare function nical:read-ical($request as map(*)) as item()
{
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid   := $request?parameters?id
    let $cals := collection($config:ical-data)/ICal[id[@value=$uuid]]
    return
      if (count($cals)=1) then
        switch ($accept)
        case "application/xml" return 
                $cals
        case "application/json" return 
                mutil:resource2json($cals)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nical: ", map { "info": "invalid uuuid"})
};

(:~
 : GET: /ICal?query
 : get ICalendar actor
 :
 : @param $actor   string
 : @param $specialty   string
 : @param $active  boolean
 : @return bundle of <ICal/>
 :)
declare function nical:search-ical($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := query:analyze($request?parameters?_elements, "string")
    let $actor  := $request?parameters?actor
    let $cutype := $request?parameters?cutype
    let $caltype  := $request?parameters?caltype
    let $service  := $request?parameters?serviceType
    let $schedule := $request?parameters?schedule
    let $period := $request?parameters?period
    let $fillSpecial := $request?parameters?fillSpecial
    let $active := query:analyze($request?parameters?active, "boolean", true())
    let $oref := concat('metis/practitioners/', $actor)
    let $coll := collection($config:ical-data)
    let $hits0 := if (count($actor)>0)
        then $coll/ICal[actor/reference[@value=$oref]][active[@value=$active]]
        (: from PractitionerRole/code mapping? specialty :)
        else if (count($service)>0)
        then $coll/ICal[serviceType//code[@value=$service]][active[@value=$active]]
        else $coll/ICal[active[@value=$active]]

    let $matched :=
        for $c in $hits0
        order by lower-case($c/actor/display/@value/string())
        return
            if (count($elems)>0)
            then
                <ICal>
                  {$c/id}
                { for $p in $c/*[not(self::id)]
                  return
                    if (local-name($p)=$elems) then $p else ()
                }
                </ICal>
            else $c
    return
        switch ($accept)
        case "application/xml" return 
                mutil:prepareResultBundleXML($matched,1,"*")
        case "application/json" return
                mutil:prepareResultBundleJSON($matched,1,"*")
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
};

(:~
 : PUT: /ICal/{$uuid}
 : Update an existing calendar or store a new one. 
 : 
 : @param $content
 :)
declare function nical:update-ical($request as map(*)){
    let $user := sm:id()//sm:real/sm:username/string()
    let $accept := $request?accept
    let $realm := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid   := $request?parameters?id
    let $content := $request?body/node()

    let $isNew   := not($content/ICal/@xml:id)
    let $cid   := if ($isNew)
        then "cal-" || substring-after($content/ICal/actor/reference/@value,'metis/practitioners/')
        else             
            let $id := $content/ICal/id/@value/string()
            let $cals := collection($config:ical-data)/ICal[id[@value = $id]]
            let $move := mutil:moveToHistory($cals, $config:icalHistory)
            return
                $id

    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/ICal/meta/versionId/@value/string()) + 1
    let $elems := $content/ICal/*[not(self::meta or self::version or self::id)]
    let $uuid := if ($isNew)
        then $cid
        else "cal-" || util:uuid()
    let $cudir := switch($content//*:cutype//*:code/@value/string())
        case 'individual' return 'Individual'
        case 'room'   return 'Room'
        case 'role'   return 'Role'
        case 'schedule' return 'Schedule'
        default return error('invalid cutype')
    let $data :=
        <ICal xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                <versionId value="{$version}"/>
                <extension url="https://eNahar.org/ns/extension/lastModifiedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
                <lastUpdated value="{date:now()}"/>
            </meta>
            {$elems}
        </ICal>
        

    let $lll := util:log-app('TRACE','apps.nabu',$data)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:ical-data, $file, $data)
            , sm:chmod(xs:anyURI($config:ical-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:ical-data || '/' || $file), $config:data-group)))
        return
          switch ($accept)
          case "application/xml" return $data
          case "application/json" return mutil:resource2json($data)
          default return $data
    } catch * {
        error($errors:UNAUTHORIZED, 'permission denied. Ask the admin.') 
    }
};


(:~
 : Validate an existing ical.
 : 
 :)
(: 
declare
    %rest:GET
    %rest:path("enahar/icals/{$uuid}/validate")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}")
    %rest:query-param("lognam", "{$lognam}")
    %rest:query-param("mode",   "{$mode}", "full") 
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function nical:validateCalXML(
          $uuid as xs:string*
        , $realm as xs:string* 
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $mode as xs:string*
        ) as item()+
{
    let $coll := collection($config:ical-data)/ICal[id[@value=$uuid]]
    let $cals := $coll/ICal[id[@value=$uuid]]
    return
        if (count($cals)=1)
        then 
            let $log := util:log-app("DEBUG", 'apps.eNahar', $cals)
            let $result := icalv:validateCalendar($cals)
            return
            (
                mutil:rest-response(200, 'schedule valid.')
            ,
                $result
            )
        else  
            (
                mutil:rest-response(404, 'icals: uuid not valid.')
            ,
                <result>
                    <error/>
                    <info value="{concat('icals: ',$uuid, ': found', count($cals), ' cals')}"/> 
                </result>
            )
};

:)

declare function local:parse-epoch($time as xs:string*) as item()+
{
let $now := current-dateTime()
return
    ( $now, $now + xs:dayTimeDuration('P90D'))
};




(:~
 : PATCH: enahar/{$actor}/schedules
 : add schedule, no duplicates
 : delete schedule
 : 
 : @param $sid   schedule id
 : @param $name  name of schedule
 : 
 : @return <cal/>
 :)
(: 
declare
    %rest:POST
    %rest:path("enahar/icals/{$actor}/schedules")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("sid",    "{$sid}","")
    %rest:query-param("name",   "{$sdisp}","")
    %rest:query-param("type",   "{$stype}","")
    %rest:query-param("action", "{$action}","add")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function nical:updateScheduleXML(
          $actor  as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $sid as xs:string*
        , $sdisp as xs:string*
        , $stype as xs:string*
        , $action as xs:string*
        ) as item()
{
    let $log := util:log-app("TRACE", 'apps.eNahar', $actor)
    let $today := current-dateTime()
    let $oref := concat('metis/practitioners/',$actor)
    let $sref := concat('enahar/schedules/', $sid)
    let $coll := collection($config:ical-data)/ICal[id[@value=$uuid]]
    let $cals := $coll/ICal[actor/reference/@value=$oref]
    return
        if (count($cals)=1)
        then 
            (: 
                meeting or service can have active or inactive agenda
            :)
            let $schedule := $cals/schedule[global/reference/@value=$sref]
            let $log := util:log-app("TRACE", 'apps.eNahar', $schedule)
            let $agenda := $schedule/agenda[nical:isActiveAt(.,$today)]
            let $log := util:log-app("TRACE", 'apps.eNahar', $action)
            let $doit := switch($action)
                case 'add' return
                    if ($schedule) (: already there :)
                    then if ($agenda) (: open new agenda if needed :)
                        then ()
                        else ()
                    else
                        let $insert := 
                                if ($cals/schedule[global/type/@value=$stype][last()])
                                then $cals/schedule[global/type/@value=$stype][last()]
                                else $cals/lastModified
                        let $log := util:log-app("TRACE", 'apps.eNahar', $insert)
                        return
                        system:as-user('vdba', 'kikl823!', (
                              update insert 
                                    <schedule>
                                        <global>
                                            <reference value="{$sref}"/>
                                            <display value="{$sdisp}"/>
                                            <type value="{$stype}"/>
                                        </global>
                                        <note value=""/>
                                        {
                                            if ($stype='meeting')
                                            then () (: agenda not needed :)
                                            else
                                                <agenda>
                                                    <period>
                                                    <start value="{adjust-dateTime-to-timezone(current-dateTime(),())}"/>
                                                    <end value=""/>
                                                    </period>
                                                    <note value=""/>
                                                </agenda>
                                        }
                                    </schedule>
                                    following $insert
                            ))
                case 'delete' return
                    if ($schedule/global/type/@value='meeting')
                    then
                        system:as-user('vdba', 'kikl823!', (
                              update delete $schedule
                            ))
                    else () (: agenda will be closed :)
                default return ()
            return
                mutil:rest-response(200, 'icals: schedule updated.')
        else if (count($cals>1))
        then
            let $log := util:log-app("TRACE", 'apps.eNahar', $actor)
            return
                mutil:rest-response(404, 'icals: only one cal is allowed.')
        else
            mutil:rest-response(404, 'icals: uuid not valid.')
};
:)

(:~
 : GET: /Service
 : get services
 : 
 : @param $actor   owner display value
 : @param $specialty   specialty
 : @param $sched   schedule
 : 
 : @return bundle of <services/>
 :)
declare function nical:search-service($request as map(*))
{
    let $user   := sm:id()//sm:real/sm:username/string()
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := $request?parameters?_elements
    let $actor  := $request?parameters?actor
    let $specialty  := $request?parameters?specialty
    let $schedule := $request?parameters?schedule
    let $period := $request?parameters?period
    let $fillSpecial := $request?parameters?fillSpecial
    let $active := $request?parameters?active
    let $passed := true() (: from period :)
    let $lll := util:log-app('DEBUG', 'apps.eNahar', $actor)
    let $lll := util:log-app('DEBUG', 'apps.eNahar', $schedule)
    let $oref := concat('metis/practitioners/', $actor)
    let $sref := concat('enahar/schedules/', $schedule)
    let $coll := collection($config:ical-data)
    let $gcals := if ($specialty='' and $actor='')
        then $coll/ICal[active[@value="true"]]
        else if ($actor!='')
        then $coll/ICal[actor/reference[@value=$oref]][active[@value="true"]]
        else $coll/ICal[specialty//code[@value=$specialty]][active[@value="true"]]
    let $valid := if ($schedule='')
        then $gcals
        else $gcals/schedule[global/reference[@value=$sref]]/.. (: tricky: match any cal with a certain schedule :)

    let $sorted-hits :=
        for $qcal in $valid
        order by lower-case($qcal/actor/display/@value/string())
        return
            <ICal>
            { $qcal/*[not(self::schedule)] }
            {   (: filter schedule :)
                if ($schedule='')
                then $qcal/schedule[global/reference/@value ne 'enahar/schedules/worktime']
                else 
                    (
                        $qcal/schedule[global/reference/@value=$sref]
                    ,   $qcal/schedule[global/type/@value='meeting']
                    ,   if ($fillSpecial='true')
                        then $qcal/schedule[global/isSpecial/@value='true'][global/ff/@value='true'][global/reference/@value!=$sref]
                        else ()
                    )
            }
            </ICal>
    let $lll := util:log-app('DEBUG', 'apps.eNahar', $sorted-hits/actor/display/@value/string())
    return
        switch ($accept)
        case "application/xml" return 
                mutil:prepareResultBundleXML($sorted-hits,1,"*")
        case "application/json" return
                mutil:prepareResultBundleJSON($sorted-hits,1,"*")
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
};
