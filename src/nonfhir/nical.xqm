xquery version "3.1";

module namespace nical="http://eNahar.org/ns/nonfhir/nical";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";

declare namespace fhir   = "http://hl7.org/fhir";

declare variable $nical:data-perms := "rwxrwxr-x";
declare variable $nical:data-group := "spz";
declare variable $nical:perms      := "rwxr-xr-x";
declare variable $nical:cals       := "/db/apps/eNaharData/data/calendars";
declare variable $nical:history    := "/db/apps/eNaharHistory/data/Cals";
declare variable $nical:schedule-base := "/db/apps/eNaharData/data/schedules";


(:~
 : GET: enahar/icals/{uuid}
 : get cal by id
 : 
 : @param $id  uuid
 : 
 : @return <cal/>
 :)
declare function nical:read-ical($request as map(*)) as item()
{
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid   := $request?parameters?id
    let $cals := collection($nical:cals)/cal[id[@value=$uuid]]
    return
        if (count($cals)=1)
        then $cals
        else  error(404, 'icals: uuid not valid.')
};

(:~
 : GET: enahar/ical?query
 : get cal owner
 :
 : @param $owner   string
 : @param $group   string
 : @param $active  boolean
 : @return bundle of <cal/>
 :)
declare function nical:search-ical($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $elems  := $request?parameters?_elements
    let $owner  := $request?parameters?owner
    let $group  := $request?parameters?group
    let $active := $request?parameters?active
    let $oref := concat('metis/practitioners/', $owner)
    let $coll := collection($nical:cals)
    let $hits0 := if ($owner != '')
        then $coll/cal[owner/reference[@value=$oref]][active[@value=$active]]
        else $coll/cal[owner/group[@value=$group]][active[@value=$active]]

    let $sorted-hits :=
        for $c in $hits0
        order by lower-case($c/owner/display/@value/string())
        return
(: TODO analyze elements id, owner, schedule :)
            if (string-length($elems)>0)
            then
                <cal>
                    {$c/id}
                    {$c/owner}
                </cal>
            else $c
    return
        mutil:prepareResourceBundleXML($sorted-hits, 1, "*")
};

(:~
 : PUT: enahar/ical
 : Update an existing calendar or store a new one. 
 : 
 : @param $content
 :)
declare function nical:update-ical($request as map(*)){
    let $user := sm:id()//sm:real/sm:username/string()
    let $realm := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $content := $request?body/node()

    let $isNew   := not($content/cal/@xml:id)
    let $cid   := if ($isNew)
        then "cal-" || substring-after($content/cal/owner/reference/@value,'metis/practitioners/')
        else             
            let $id := $content/cal/id/@value/string()
            let $cals := collection($nical:cals)/cal[id[@value = $id]]
(: 
            let $move := r-cal:moveToHistory($cals)
:)
            return
                $id

    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/cal/meta/versionID/@value/string()) + 1
    let $elems := $content/cal/*[not(self::meta or self::version or self::id)]
    let $uuid := if ($isNew)
        then $cid
        else "cal-" || util:uuid()
    let $cudir := switch($content//*:cutype//*:code/@value/string())
        case 'person' return 'individuals'
        case 'room'   return 'rooms'
        case 'role'   return 'roles'
        default return error('invalid cutype')
    let $data :=
        <cal xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                <versionID value="{$version}"/>
                <extension url="https://eNahar.org/ical/extension/lastModifiedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
                <lastUpdated value="{adjust-dateTime-to-timezone(current-dateTime())}"/>
            </meta>
            {$elems}
        </cal>
        

    let $lll := util:log-app('ERROR','exist-core',$data)

(: 
    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($nical:cals || '/' || $cudir  , $file, $data)
            , sm:chmod(xs:anyURI($nical:cals || '/' || $cudir || '/' || $file), $nical:data-perms)
            , sm:chgrp(xs:anyURI($nical:cals || '/' || $cudir || '/' || $file), $nical:data-group)))
        return
            $data
    } catch * {
        error(401, 'permission denied. Ask the admin.') 
    }
:)
    return $data
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
function r-cal:validateCalXML(
          $uuid as xs:string*
        , $realm as xs:string* 
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $mode as xs:string*
        ) as item()+
{
    let $cals := $r-cal:cals/cal[id[@value=$uuid]]
    return
        if (count($cals)=1)
        then 
            let $log := util:log-app("DEBUG", 'apps.eNahar', $cals)
            let $result := icalv:validateCalendar($cals)
            return
            (
                r-cal:rest-response(200, 'schedule valid.')
            ,
                $result
            )
        else  
            (
                r-cal:rest-response(404, 'icals: uuid not valid.')
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
 : PATCH: enahar/{$owner}/schedules
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
    %rest:path("enahar/icals/{$owner}/schedules")
    %rest:query-param("realm",  "{$realm}") 
    %rest:query-param("loguid", "{$loguid}","")
    %rest:query-param("lognam", "{$lognam}","")
    %rest:query-param("sid",    "{$sid}","")
    %rest:query-param("name",   "{$sdisp}","")
    %rest:query-param("type",   "{$stype}","")
    %rest:query-param("action", "{$action}","add")
    %rest:consumes("application/xml")
    %rest:produces("application/xml", "text/xml")
function r-cal:updateScheduleXML(
          $owner  as xs:string*
        , $realm as xs:string*
        , $loguid as xs:string*
        , $lognam as xs:string*
        , $sid as xs:string*
        , $sdisp as xs:string*
        , $stype as xs:string*
        , $action as xs:string*
        ) as item()
{
    let $log := util:log-app("TRACE", 'apps.eNahar', $owner)
    let $today := current-dateTime()
    let $oref := concat('metis/practitioners/',$owner)
    let $sref := concat('enahar/schedules/', $sid)
    let $cals := $r-cal:cals/cal[owner/reference/@value=$oref]
    return
        if (count($cals)=1)
        then 
            (: 
                meeting or service can have active or inactive agenda
            :)
            let $schedule := $cals/schedule[global/reference/@value=$sref]
            let $log := util:log-app("TRACE", 'apps.eNahar', $schedule)
            let $agenda := $schedule/agenda[r-cal:isActiveAt(.,$today)]
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
                r-cal:rest-response(200, 'icals: schedule updated.')
        else if (count($cals>1))
        then
            let $log := util:log-app("TRACE", 'apps.eNahar', $owner)
            return
                r-cal:rest-response(404, 'icals: only one cal is allowed.')
        else
            r-cal:rest-response(404, 'icals: uuid not valid.')
};
:)
