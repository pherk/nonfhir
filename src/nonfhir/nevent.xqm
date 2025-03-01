xquery version "3.1";

module namespace nevent ="http://eNahar.org/ns/nonfhir/nevent";

import module namespace config = "http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace query  = "http://eNahar.org/ns/nonfhir/query" at "../modules/query.xqm";
import module namespace nical  = "http://eNahar.org/ns/nonfhir/nical" at "../nonfhir/nical.xqm";
import module namespace nholiday = "http://eNahar.org/ns/nonfhir/nholiday" at "../nonfhir/nholiday.xqm";
import module namespace nleave = "http://eNahar.org/ns/nonfhir/nleave" at "../nonfhir/nleave.xqm";
import module namespace cal2event = "http://eNahar.org/ns/nonfhir/cal2event" at "../nonfhir/ICal/cal2event.xqm";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace date  ="http://eNahar.org/ns/lib/date";

declare namespace fhir   = "http://hl7.org/fhir";
 
(:~
 : GET: /ICalEvent
 : get events
 : 
 : @param $owner   actor ref aka user id
 : @param $group   group
 : @param $sched   schedule
 : @param $rangeStart timeMin
 : @param $rangeEnd   timeMax
 : 
 : @return bundle
 :)
declare function nevent:search-event($request as map(*))
{
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elements:= query:analyze($request?parameters?_elements, "string")
    let $actor  := query:analyze($request?actor, "string")
    let $group  := query:analyze($request?parameters?group, "string")
    let $schedule := query:analyze($request?parameters?schedule, "string")
    let $period := query:analyze($request?parameters?period, "date")
    let $fillSpecial := query:analyze($request?parameters?fillSpecial, "boolean")
    let $now := date:now()
    let $e := if (count($period[prefix/@value="le"])=1)
	        then $period[prefix/@value="le"]/value/@value
	        else error($errors:BAD_REQUEST, "query should define only one period of time", map { "info": $period})
    let $s := if (count($period[prefix/@value="ge"])=1)
	        then $period[prefix/@value="ge"]/value/@value
	        else error($errors:BAD_REQUEST, "query should define only one period of time", map { "info": $period})
    (: get all user cals with selected schedules :)
    let $services:= nical:search-service($request)//ICal
 
    let $lll := util:log-app('TRACE', 'apps.eNahar', $services)

    let $hds       := nholiday:search-holiday($request)//Event
    let $leaves    := nleave:search-leave(map:put($request, "status", ('confirmed','tentative')))//Event
(: 
    let $lll := util:log-app('TRACE', 'apps.eNahar', $leaves)
:)
    (: get all relevant schedules :)
    let $refdss    := distinct-values($services/basedOn/reference/@value)
    let $schedules := collection($config:schedule-data)/ICal[identifier/value[@value=$refdss]][active[@value="true"]]
 
    let $lll := util:log-app('TRACE', 'apps.eNahar', $schedules/name)

    let $matched := cal2event:slot-events($services, $s, $e, $hds, $leaves, $schedules, $fillSpecial='true')
    return
        switch ($accept)
        case "application/xml" return 
                mutil:prepareResultBundleXML($matched,1,"*")
        case "application/json" return
                mutil:prepareResultBundleJSON($matched,1,"*")
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
(:
    let $services:= nical:servicesXML($realm, $loguid, $lognam, '1', '*', $actor, $group, $sched, 'false', 'false')/cal
    let $lll := util:log-app('DEBUG', 'eNahar', $services)
    let $hds    := r-hd:holidaysXML($rangeStart,$rangeEnd)/event
    let $leaves := r-leave:leavesXML(
                      $realm, $loguid, $lognam
                    ,'1', '*'
                    , $actor, ''
                    , $rangeStart, $rangeEnd
                    , ('confirmed','tentative')
                    , '*')//leave 
    let $refdss    := distinct-values($services/schedule/global/reference/@value)
    let $schedules := collection($r-sched:schedule-base)/schedule[identifier/value/@value=$refdss][active[@value="true"]]
    return
    <json:array xmlns:json="http://www.json.org">
    {
        for $service in $services
        let $las := $leaves[actor/reference/@value=$service/owner/reference/@value]
        return
            cal2event:cal2fc-events($service, $s, $e, $hds, $las, $schedules)
    }
    </json:array>
:) 
};
