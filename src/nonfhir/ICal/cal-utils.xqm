xquery version "3.1";

(: 
 : calendar utilities
 : 
 : @version 1.0
 : @since
 : @created 2018-07-29
 : 
 : @copyright Peter Herkenrath 2018-2025
 :)
module namespace cal-util = "http://eNahar.org/ns/nonfhir/cal-util";

import module namespace ice   = "http://eNahar.org/ns/lib/ice";
import module namespace xqtime= "http://eNahar.org/ns/lib/xqtime";
import module namespace date  = "http://eNahar.org/ns/lib/date";

declare function local:less($a as xs:string*, $b as xs:dateTime)
{
  if ($a)
  then if ($a="")
    then true()
    else xs:dateTime($a) <= $b
  else true()
};

declare function local:greater($a as xs:string*, $b as xs:dateTime)
{
  if ($a)
  then if ($a="")
    then true()
    else xs:dateTime($a) > $b
  else true()
};


declare function cal-util:filterValidAgendas($agendas as element(schedule)+, $start as xs:dateTime, $end as xs:dateTime) as element(schedule)*
{
   $agendas[local:less(period/start/@value/string(),$end)][local:greater(period/end/@value/string(),$start)]
};

declare function cal-util:filterValidAgendas($agendas as item()*, $date as xs:date) as item()*
{
let $dt := dateTime($date,xs:time("08:00:00"))
let $res := $agendas[local:less(period/start/@value/string(),$dt)][local:greater(period/end/@value/string(),$dt)]
return
    $res
(: 
    if (count($res)>1)
    then let $log := util:log-system-out('eNahar: overlapping agenda!')
        return ()
    else $res
:)
};
(:~
 : event2tp
 : converts event to tp elements
 : 
 : @param $date   date
 : @param $events sequence of events
 : 
 : @return sequence of tp
 :)
declare function cal-util:event2tp($date as xs:date, $events as element(event)*) as element(tp)*
{
    for $e in $events
    return
        let $start := dateTime($date, xs:time($e/start/@value))
        let $end   := dateTime($date, xs:time($e/end/@value))
        let $info  := ($e/venue/location/display/string(),"no room")[1] 
        return
            xqtime:new($start,$end,$info)
};

declare %private function cal-util:hd2tp($date, $events as element(Event)*) as element(tp)*
{
    for $e in $events
    let $lll := util:log-app('TRACE','apps.nabu',$events)
    let $start := dateTime($date,xs:time(tokenize($e/start/@value,'T')[2]))
    let $end   := dateTime($date,xs:time(tokenize($e/end/@value,'T')[2]))
    return
        xqtime:new($start,$end,"hd")
};

(:~
 : leaves2tp
 : converts leaves to tp elements
 : 
 : @param $events sequence of events
 : 
 : @return sequence of tp
 :)
declare %private function cal-util:leave2tp($leaves as element(Event)*) as element(tp)*
{
    for $l in $leaves
    return
    if ($l)
    then
        let $start := date:iso2dateTime($l/period/start/@value)
        let $end   := date:iso2dateTime($l/period/end/@value)
        return
            xqtime:new($start,$end,"leave")
    else ()
};

(:~
 : isHoliday
 : check if date is holiday 
 : allDay and non-allDay holidays included
 : 
 : @param $date  date
 : @param $hds   sequence of holidays
 : 
 : return event
 :)
declare function cal-util:isHoliday($date as xs:date, $hds as element(Event)*) as element(Event)?
{
    let $result := filter(
            $hds,
            function($e){
                ($date = date:iso2date($e/period/start/@value)) and $e/type[@value=('official','traditional')]
            })
    return
        $result
};

(:~
 : isAllDayHoliday
 : check if allDay=true 
 : 
 : @param $hd
 : 
 : return event
 :)
declare function cal-util:isAllDayHoliday($e as element(Event)?) as xs:boolean
{
    if ($e and
            (
                $e/type/@value=('official')  
            or 
                ($e/type/@value=('traditional') and 
                 tokenize($e/period/start/@value,'T')[2]<='08:00:00' and tokenize($e/period/end/@value,'T')[2]>='20:00:00')
            )
        )
    then true()
    else false()
};
        
(:~
 : isAllDayLeave
 : check if date falls in allDay leave 
 : 
 : @param $date   date
 : @param $leaves list of leaves
 : 
 : return boolean
 :)
declare function cal-util:isAllDayLeave($date as xs:date, $leaves as element(Event)*) as xs:boolean
{
    let $allday := $leaves[allDay/@value='true']
    return
        count($allday[xs:date(tokenize(period/start/@value,'T')[1])<=$date][xs:date(tokenize(period/end/@value,'T')[1])>=$date])>0
};

(:~
 : isAllDayLeave
 : check if date falls in allDay leave 
 : 
 : @param $date   date
 : @param $actor  uref
 : @param $leaves list of leaves
 : 
 : return boolean
 :)
declare function cal-util:isAllDayLeave(
          $date as xs:date
        , $actor as xs:string
        , $leaves as element(Event)*
        ) as xs:boolean
{
    let $m0 := $leaves[actor/reference[@value=$actor]]
    let $m1 := $m0[allDay/@value='true']
    let $m2 := $m1[xs:date(tokenize(period/start/@value,'T')[1])<=$date][xs:date(tokenize(period/end/@value,'T')[1])>=$date]
    return
        count($m2)>0
};

(:~
 : filterPartialLeaves
 : check if slot falls in partial leave 
 : 
 : @param $date   date
 : @param $actor  uref
 : @param $leaves list of leaves
 : 
 : return element(tp)*
 :)
declare function cal-util:filterPartialLeaves(
      $rawTPs as element(tp)*
    , $date as xs:date
    , $actor as xs:string
    , $leaves as element(Event)*
    , $hd as element(Event)?
    , $meetings as element(tp)*
    ) as item()*
{
    let $partialLeaves := $leaves[actor/reference[@value=$actor]][allDay/@value="false"][xs:date(tokenize(period/start/@value,'T')[1])<=$date][xs:date(tokenize(period/end/@value,'T')[1])>=$date]
    let $pltps := cal-util:leave2tp($partialLeaves)
     let $lll := util:log-app('TRACE','apps.nabu',$date)
    let $absent := if ($hd)
        then (cal-util:hd2tp($date,$hd),$pltps,$meetings)
        else ($pltps, $meetings)
    let $lll := util:log-app('TRACE','apps.nabu',$absent)
    let $lll := util:log-app('TRACE','apps.nabu',$rawTPs)
    return
        if (count($absent)>0)
        then xqtime:subtractPeriods($rawTPs, $absent)
        else $rawTPs
};
