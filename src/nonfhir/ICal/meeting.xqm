xquery version "3.1";

(: 
 : converts meeting schedules in cal to events
 : 
 : @version 0.9
 : @since
 : @created 2018-07-29
 : 
 : @copyright Peter Herkenrath 2018-2025
 :)
module namespace meeting = "http://eNahar.org/ns/nonfhir/meeting";

import module namespace functx =  "http://www.functx.com";

import module namespace cal-util = "http://eNahar.org/ns/nonfhir/cal-util" at "../ICal/cal-utils.xqm";
import module namespace ical  = "http://eNahar.org/ns/lib/ical";
import module namespace ice   = "http://eNahar.org/ns/lib/ice";
import module namespace xqtime= "http://eNahar.org/ns/lib/xqtime";


declare function meeting:events(
          $cal as element(ICal)+
        , $date as xs:date
        , $meetings as element(ICal)*
        ) as element(tp)*
{
    let $lll := if (count($cal)>1)
        then
            util:log-app('ERROR','apps.eNahar',$cal)
        else
            ()
    let $mrefs := $cal/schedule[type/@value='meeting']/reference/@value/string()
    let $msas   := 
        for $mref in distinct-values($mrefs)
        return
            $meetings/../schedule[identifier/value[@value=$mref]]/schedule
    let $shifts     := cal-util:filterValidAgendas($msas,$date)/event
    let $rrEvents  := (ice:match-rdates($date,$shifts),ice:match-rrules($date, $shifts))
    (: let $lll := util:log-app('TRACE','apps.nabu',$rrEvents) :)
    let $exEvents  := ice:match-exdates($date,$shifts)
    let $rawEvents := functx:distinct-nodes($rrEvents[not(.=$exEvents)])
    let $rawTPs    := cal-util:event2tp($date, $rawEvents)
(: 
    let $lll := util:log-app('TRACE','apps.eNahar',$rawTPs)
:)
    return
        $rawTPs
};
