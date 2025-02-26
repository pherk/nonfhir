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

declare function cal2event:cal2xml(
          $services as element(cal)*
        , $start as xs:dateTime
        , $end as xs:dateTime
        , $hds as element(event)*
        , $leaves as element(leave)*
        , $schedules as element(schedule)*
        , $fillSpecial as xs:boolean
        ) as item()*
{
    let $meetings := $schedules[type[@value='meeting']]
    let $refdss   := $schedules[type[@value='service']]
    let $lll := util:log-app('TRACE','apps.eNahar',count($meetings))
    let $lll := util:log-app('TRACE','apps.eNahar',count($services))
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
        <day>
            <date value="{$date}"/>
        {
            if (cal-util:isAllDayHoliday($hd)) 
            then    ()
            else
                for $s in distinct-values($services/schedule/global/reference/@value)
                let $sdisp   := head($services/schedule/global[reference/@value=$s]/display/@value/string())
                let $agendas := if ($fillSpecial and cal2event:isSpecialAmb($services/schedule/global[reference/@value=$s]))
                    then if ($date >= $nowd1 and $date <= $nowd14)
                         then cal-util:filterValidAgendas(
                                      $services/schedule[global/reference/@value=$s]/agenda
                                    , $now1
                                    , min(($now14,$end)))
                         else ()
                    else cal-util:filterValidAgendas(
                                      $services/schedule[global/reference/@value=$s]/agenda
                                    , $start
                                    , $end)
                let $timing  := $refdss/../schedule[identifier/value[@value=$s]]/timing
                return
                    if (count($agendas)>0)
                    then
                        <schedule ref="{$s}" display="{$sdisp}">
                        { $timing }
                        {
                            for $a in distinct-values($services/owner/reference/@value)
                            let $acal := $services[owner/reference/@value=$a]
                            let $name := $acal/owner/display/@value/string()
                            let $isAllDayLeave := cal-util:isAllDayLeave($date, $a, $leaves)
                            return
                                if ($isAllDayLeave)
                                then ()
                                else
        let $lll := util:log-app('TRACE','apps.eNahar',$date) 
                                    let $shifts    := cal-util:filterValidAgendas($acal/schedule[global/reference/@value=$s]/agenda,$date)/event
                                    let $rrEvents  := (ice:match-rdates(dateTime($date,xs:time("00:00:00")),$shifts)
                                                      ,ice:match-rrules(dateTime($date,xs:time("00:00:00")), $shifts))

        let $lll := util:log-app('TRACE','apps.eNahar',$rrEvents) 

                                    let $exEvents  := ice:match-exdates($date,$shifts)
                                    let $rawEvents := functx:distinct-nodes($rrEvents[not(.=$exEvents)])
                                    let $rawTPs    := cal-util:event2tp($date, $rawEvents)
(: 
        let $lll := util:log-app('TRACE','apps.eNahar',$rawTPs)
:)
                                    let $mes  := meeting:events($acal,$date,$meetings)
                                    let $validTPs  := cal-util:filterPartialLeaves($rawTPs,$date,$a,$leaves,$hd,$mes)
  
        let $lll := util:log-app('TRACE','apps.eNahar',$validTPs)

                                    return
                                        if (count($validTPs)>0)
                                        then 
                                            <actor ref="{$a}" display="{$name}">
                                                {   
                                                    if ($acal/schedule[global/reference/@value=$s]/timing)
                                                    then
                                                        cal2event:merge(
                                                          $refdss[identifier/value/@value=$s]/timing/*
                                                        , $acal/schedule[global/reference/@value=$s]/timing/*
                                                        )
                                                    else ()
                                                }
                                                { $validTPs }
                                            </actor>
                                        else
                                            ()
                        }
                        </schedule>
                    else ()
        }
        </day>
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

declare function cal2event:cal2fc-events(
          $cal as element(cal)
        , $start as xs:dateTime
        , $end as xs:dateTime
        , $hds as element(event)*
        , $leaves as element(leave)*
        , $schedules as element(schedule)*
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
    for $ups in ($cal/schedule[global/type/@value='service'], $meetings)
    let $isService := $ups/global/type/@value='service'
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
            , "title" : $title
            , "description": $desc
            , "period" : map {"start" : $start, "end": $end}
            , "location": map {"display" : "3.xxx"}
            , "rendering" : map {
                    "class": "blue"
                  , "backgroundColor": "lightblue"
                  , "textColor": "black"
                  , "rendering": "background"
                  , "editable": false
                  , "allDay": false
                  }
            }
    else ()
};

