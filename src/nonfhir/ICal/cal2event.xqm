xquery version "3.1";

(:~
 : converts cal/agendas/events to events
 :)
module namespace cal2event = "http://eNahar.org/ns/nonfhir/cal2event";

import module namespace functx =  "http://www.functx.com";

import module namespace ice   = "http://eNahar.org/ns/lib/ice";
import module namespace date  = "http://eNahar.org/ns/lib/date";
(:~
import module namespace xqtime= "http://eNahar.org/ns/lib/xqtime";
:)
import module namespace cal-util = "http://eNahar.org/ns/nonfhir/cal-util" at "../ICal/cal-utils.xqm";
import module namespace meeting = "http://eNahar.org/ns/nonfhir/meeting" at "../ICal/meeting.xqm";


declare %private function cal2event:isSpecialAmb($g) as xs:boolean
{
    $g/isSpecial/@value='true' and $g/ff/@value='true'
};

declare function cal2event:slot-events(
          $services as element(ICal)*
        , $start as xs:dateTime
        , $end as xs:dateTime
        , $hds as element(Event)*
        , $leaves as element(Event)*
        , $schedules as element(ICal)*
        , $fillSpecial as xs:boolean
        ) as element(Event)*
{
    let $meetings := $schedules[type[@value='meeting']]
    let $refdss   := $schedules[type[@value='service']]
    let $lll := util:log-app('TRACE','apps.eNahar',count($meetings))
    let $lll := util:log-app('TRACE','apps.eNahar', count($services))
    let $lll := util:log-app('TRACE','apps.eNahar', count($services/schedule[type/@value=('service','worktime')]))
    let $lll := util:log-app('TRACE','apps.eNahar',$fillSpecial)
    let $nowd1 := date:today() + xs:dayTimeDuration("P1D")
    let $nowd14 := $nowd1 + xs:dayTimeDuration("P14D")
    let $now1 := date:noon() + xs:dayTimeDuration("P1D")
    let $now14 := $now1 + xs:dayTimeDuration("P14D")
    let $sa := xs:date(format-dateTime($start,"[Y0001]-[M01]-[D01]"))
    let $nofd  := xs:integer(floor(($end - $start) div xs:dayTimeDuration('P1D')))
    (: enumerate days in period :)
    for $d in (0 to $nofd)
    let $date  := xs:date(format-date($sa + xs:dayTimeDuration('P1D')*$d,"[Y0001]-[M01]-[D01]"))
    let $hd := cal-util:isHoliday($date, $hds)
    return
       if (cal-util:isAllDayHoliday($hd)) 
       then    ()
       else
          for $s in distinct-values($services/schedule[type/@value=('service','worktime')]/basedOn/reference/@value)
          let $sdisp   := head($services/schedule/basedOn[reference[@value=$s]]/display/@value/string())
    let $lll := util:log-app('TRACE','apps.eNahar',$sdisp)
          let $agendas := if ($fillSpecial and cal2event:isSpecialAmb($services/schedule[basedOn/reference[@value=$s]]))
                    then if ($date >= $nowd1 and $date <= $nowd14)
                         then cal-util:filterValidAgendas(
                                      $services/schedule[basedOn/reference[@value=$s]]/schedule
                                    , $now1
                                    , min(($now14,$end)))
                         else ()
                    else cal-util:filterValidAgendas(
                                      $services/schedule[basedOn/reference[@value=$s]]/schedule
                                    , $start
                                    , $end)
          let $timing  := $refdss/../schedule[identifier/value[@value=$s]]/timing
          return
            if (count($agendas)=0)
              then ()
              else
                for $a in distinct-values($services/actor/reference/@value)
                let $acal := $services/../ICal[actor/reference[@value=$a]]
                let $name := $acal/actor/display/@value/string()
                let $isAllDayLeave := cal-util:isAllDayLeave($date, $a, $leaves)
                return
                  if ($isAllDayLeave)
                  then ()
                  else
        let $lll := util:log-app('TRACE','apps.eNahar',$date) 
                    let $shifts    := cal-util:filterValidAgendas($acal/schedule[basedOn/reference[@value=$s]]/schedule,$date)/event
                    let $rrEvents  := (ice:match-rdates(dateTime($date,xs:time("00:00:00")),$shifts)
                                                      ,ice:match-rrules(dateTime($date,xs:time("00:00:00")), $shifts))
(:
        let $lll := util:log-app('TRACE','apps.eNahar',$rrEvents) 
:)
                    let $exEvents  := ice:match-exdates($date,$shifts)
                    let $rawEvents := functx:distinct-nodes($rrEvents[not(.=$exEvents)])
                    let $rawTPs    := cal-util:event2tp($date, $rawEvents)
(: 
        let $lll := util:log-app('TRACE','apps.eNahar',$rawTPs)
:)
                    let $mes  := meeting:events($acal,$date,$meetings)
                    let $validTPs  := cal-util:filterPartialLeaves($rawTPs,$date,$a,$leaves,$hd,$mes)
(:  
        let $lll := util:log-app('TRACE','apps.eNahar',$validTPs)
:)
                    return
                      if (count($validTPs)=0)
                      then ()
                      else
                        let $timing := if ($acal/schedule[basedOn/reference[@value=$s]]/timing)
                              then
                                  cal2event:merge(
                                          $refdss[identifier/value/@value=$s]/timing/*
                                        , $acal/schedule[basedOn/reference[@value=$s]]/timing/*
                                        )
                              else ()
                        for $tp in $validTPs
                        return
        <Event>
          <id value="{util:uuid()}"/>
          <extension url="http://eNahar.org/ns/extension/event-date">
            <valueDate value="{$date}"/>
          </extension>
          <status value="in-progress"/>
          <code>
            <coding>
             <system value="http://eNahar.org/ns/system/event-code"/>
              <code value="ical"/>
            </coding>
          </code>
          <basedOn>
            <reference value="{$s}"/>
            <display value="{$sdisp}"/>
          </basedOn>
          <type value="slot"/>
          <actor>
            <reference value="{$a}"/>
            <display value="{$name}"/>
          </actor>
          <period>
            <start value="{$tp/@start/string()}"/>
            <end value="{$tp/@end/string()}"/>
          </period>
          <location>
            <reference value=""/>
            <display value=""/>
          </location>
        </Event>
}; 

declare function cal2event:merge(
          $globals as item()*
        , $users as item()*
        ) as item()*
{
    let $empty := map {}
    let $params:= 
        map:merge(
                for $g in $globals
                return
                    map:entry(local-name($g),$g/@value/string())
            )
    let $puts := 
        for $u in $users
        return
            map:put($params, local-name($u), $u/@value/string())
    return
        for $k in map:keys($params)
        return
                element { $k } { attribute value { map:get($params,$k) }}
};

declare function cal2event:ical-events(
          $cal as element(ICal)
        , $start as xs:dateTime
        , $end as xs:dateTime
        , $hds as element(Event)*
        , $leaves as element(Event)*
        , $schedules as element(ICal)*
        ) as item()*
{
    let $meetings := $schedules[type/@value='meeting']
    let $refdss   := $schedules[type/@value='service']
    let $service-attributes := 
        map {
            "location": map {"display" : "3.xxx"}
          , "class": "yellow"
          , "backgroundColor": "yellow"
          , "textColor": "blue"
          , "rendering": "background"
          }
    let $meeting-attributes := 
        map {
            "location": map {"display" : "3.xxx"}
          , "class": "blue"
          , "backgroundColor": "lightblue"
          , "textColor": "black"
          , "rendering": "background"
          }
    let $s := xs:date(format-dateTime($start,"[Y0001]-[M01]-[D01]"))
    for $ups in ($cal/schedule[type/@value='service'], $meetings)
    let $isService := $ups/type/@value='service'
    let $title    := if ($ups/global)
        then $ups/global/display/@value/string() (: cal schedules :)
        else $ups/name/@value/string()           (: meeting schedules :)
    let $agendas := cal-util:filterValidAgendas($ups/agenda,$start,$end)
    let $attr := if ($isService)
        then $service-attributes
        else  $meeting-attributes
    return
        if (count($agendas)>0)
        then
            (:
            let $title := $ups/title
            let $description := ""
            let $class := $ups/className
            let $bc    := $ups/backgroundColor
            let $tc    := $ups/textColor
            let $edit  := $ups/editable
            let $url   := $ups/url
            :)
            let $nofd  := xs:integer(floor(($end - $start) div xs:dayTimeDuration('P1D')))
            (: enumerate days in period :)
            for $d in (0 to $nofd)
            let $date  := $s + xs:dayTimeDuration('P1D')*$d
            let $isAllDayLeave := cal-util:isAllDayLeave($date, $leaves) or cal-util:isHoliday($date, $hds)

            return
                if ($isAllDayLeave) then
                    ()
                else
                    let $shifts    := cal-util:filterValidAgendas($agendas,$date)/event

                    let $rrEvents  := (ice:match-rdates($date,$shifts),ice:match-rrules($date, $shifts))
                    let $exEvents  := ice:match-exdates($date,$shifts)
                    let $rawEvents := functx:distinct-nodes($rrEvents[not(.=$exEvents)])                    
(:                
                            let $rawTPs    := cal-util:event2tp($date, $rawEvents)
                            let $partialLeaves := $leaves/leave[actor/reference/@value=$a][allDay/@value="false"]
let $lll := util:log-system-out($partialLeaves)
                            let $validTPs  := if (count($partialLeaves)>0)
                                then xqtime:subtractPeriods($rawTPs, cal-util:leave2tp($partialLeaves))
                                else $rawTPs
                            return
                                if (count($validTPs)>0)
                                then
                                    <actor ref="{$a}">{ $validTPs }</actor>
                                else
                                    ()
:)                    
                    let $events := $rawEvents  (: no filtering for partial leaves, convert events to tp TODO :)
                    for $e in $events
                    return
                        cal2event:fc-eventJSON($e, $date, $title, " ", $attr)
        else ()
}; 

declare %private function cal2event:fc-eventJSON(
          $e as item()?
        , $date as xs:date
        , $title as xs:string
        , $desc as xs:string*
        , $attr as map(*)
        ) as item()?
{
    if ($e)
    then
        let $id := $e/name/@value/string()
        let $start := dateTime($date, xs:time($e/start/@value))
        let $end   := dateTime($date, xs:time($e/end/@value))
        return
            map {
              "resourceType" : "Event"
            , "id" : $id
            , "status" : "in-progress"
            , "code" : map {"coding" : map {"system" : "http://eNahar.org/ns/system-event-code", "code" : "ical"}}
            , "title" : $title
            , "description": $desc
            , "type" : "fullcalendar"
            , "period" : map {"start" : $start, "end": $end}
            , "location": map {"display" : "3.xxx"}
            , "rendering" : $attr
            }
    else ()
};

