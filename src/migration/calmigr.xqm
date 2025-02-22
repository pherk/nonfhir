xquery version "3.1";

module namespace calmigr = "http://eNahar.org/ns/nonfhir/cal-migration";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


declare function calmigr:update-2.0($c as item())
{
    let $version := ($c/meta/versionID/@value/string(),$c/meta/versionId/@value/string())[1]
    let $loguid  := $c/lastModifiedBy/reference/@value/string()
    let $lognam  := $c/lastModifiedBy/display/@value/string()
    let $lastUpd := $c/lastModified/@value/string()
    let $identifier := if ($c/identifier)
        then
            <identifier>
                <use value="official"/>
                <system value="http://eNahar.org/ns/system/ical-id"/>
                <value value="Schedule/{substring-after($c/identifier/value/@value,"enahar/schedules/")}"/>
            </identifier>
        else ()
    let $active  := $c/active/@value/string()
    let $cutype := if ($c/cutype)
        then
            <cutype>
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-usertype"/>
                    <code value="{if ($c/cutype//code/@value='person') then 'individual' else 'role'}"/>
                </coding>
            </cutype>
        else
            <cutype>
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-usertype"/>
                    <code value="schedule"/>
                </coding>
            </cutype>
    let $caltype := if ($c/caltype)
        then
            <caltype>
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-caltype"/>
                    <code value="{$c/caltype/@value/string()}"/>
                </coding>
            </caltype>
        else
            <caltype>
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-caltype"/>
                    <code value="primary"/>
                </coding>
            </caltype>
    let $serviceType := if ($c/owner/group and $c/owner/group/@value!='')
        then
            <serviceType>
                <coding>
                    <system value="http://eNahar.org/ns/system/service-type"/>
                    <code value="{$c/owner/group/@value/string()}"/>
                </coding>
            </serviceType>
        else ()
    let $active  := $c/active/@value/string()
    let $actor   := if ($c/owner)
        then
            <actor>
              {$c/owner/reference}
              {$c/owner/display}
            </actor>
        else ()
    let $name    := ($c/summary/@value/string(), $c/name/@value/string())[1]
    let $comment := $c/description/@value/string()
    let $location   := if ($c/location)
        then
            <location>
              <reference value="Location/{substring-after($c/location/reference/@value,'metis/locations/')}"/>
              {$c/location/display}
            </location>
        else ()
    return
    <ICal xml:id="{$c/@xml:id/string()}">
        {$c/id}
        <meta>
            <versionId value="{$version}"/>
                <extension url="https://eNahar.org/ns/extension/lastModifiedBy">
                    <valueReference>
                        <reference value="{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>
                <lastUpdated value="{$lastUpd}"/>
        </meta>
        {$identifier}
        <active value="{$active}"/>
        {$cutype}
        {$caltype}
        {$serviceType}
        <specialty>
            <coding>
                <system value="http://hl7.org/fhir/ValueSet/c80-practice-codes"/>
                <code value="94538003"/>
            </coding>
        </specialty>
        {$actor}
        <name value="{$name}"/>
        <comment value="{$comment}"/>
        {$c/timezone}
          {$location}
        { if (local-name($c)="cal")
        then
            for $s in $c/schedule
            return
                calmigr:update-schedule-2.0($s)
        else calmigr:update-schedule-2.0($c)
        }
    </ICal>
};

declare function calmigr:update-schedule-2.0($s as item())
{
    let $wasGlobal :=if ($s/global)
          then (
                 $s/global/type
                , <scheduleReference>
                    <reference value="Schedule/{substring-after($s/global/reference/@value,"enahar/schedules/")}"/>
                    {$s/global/display}
                  </scheduleReference>
                )
          else ()
    let $appLetter := if ($s/appLetter)
        then
        <appLetter>
            <altName value="{$s/appLetter/alt-name/@value/string()}"/>
            {$s/appLetter/template}
        </appLetter>
        else ()
    let $period := if ($s/period)
        then
            <period>
                {
                  if ($s/period/start/@value!="") then $s/period/start else ()
                , if ($s/period/end/@value!="") then $s/period/end else ()
                }
            </period>
        else ()
    let $location := if ($s/location)
        then
            <location>
              <reference value="Location/{substring-after($s/location/reference/@value,'metis/locations/')}"/>
              {$s/location/display}
            </location>
        else ()
    let $note := if($s/note/@value!='')
        then
            <note>
                <text value="{$s/note/@value/string()}"/>
            </note>
        else ()
    let $css  := if ($s/fc)
        then
        <css>
            {$s/fc/className}
            {$s/fc/backgroundColor}
            {$s/fc/textColor}
            {$s/fc/editable}
        </css>
        else ()
    let $pph := if ($s/timing/parallel-per-hour) then <parallelPerHour value="{$s/timing/parallel-per-hour/@value/string()}"/> else ()
    let $timing := if ($s/timing)
        then
        <timing>
            {$s/timing/pre}
            {$s/timing/exam}
            {$s/timing/post}
            {$s/timing/overbookable}
            {$s/timing/query}
            {$s/blocking}
            {$pph}
        </timing>
        else ()
    return
    <schedule>
        {$wasGlobal}
        {$s/isSpecial}
        {$s/ff}
        {$period}
        <venue>
          <priority value="normal"/>
          {$location}
        </venue>
        {$note}
        {$css}
        {$appLetter}
        {$timing}
        {
        for $a in $s/agenda
        return
            calmigr:update-schedule-2.0($a)
        }
        {
        for $e in $s/event
        return
            calmigr:update-event-2.0($e)
        }
    </schedule>
};

declare function calmigr:update-event-2.0($e as element(event))
{
    let $name := $e/title/@value/string()
    let $note := if($e/note/@value!='')
        then
            <note>
                <text value="{$e/note/@value/string()}"/>
            </note>
        else ()
    let $rrule := if ($e/rrule)
        then
        <rrule>
        { 
          $e/rrule/freq
        , if ($e/rrule/byYear and $e/rrule/byYear/@value!="") then $e/rrule/byYear else ()
        , if ($e/rrule/byMonth and $e/rrule/byMonth/@value!="") then $e/rrule/byMonth else ()
        , if ($e/rrule/byWeekNo and $e/rrule/byWeekNo/@value!="") then <byWeek value="{$e/rrule/byWeekNo/@value/string()}"/> else ()
        , if ($e/rrule/byDay and $e/rrule/byDay/@value!="") then $e/rrule/byDay else ()
        }
        </rrule>
        else ()
    let $location := if ($e/venue/location)
        then
            <location>
              <reference value="Location/{substring-after($e/venue/location/reference/@value,'metis/locations/')}"/>
              {$e/venue/location/display}
            </location>
        else ()
    return
        <event>
        {$e/name}
        {$e/summary}
        {$e/description}
        {$e/start}
        {$e/end}
        {$note}
        <venue>
            <priority value="{$e/venue/priority/@value/string()}"/>
            {$location}
        </venue>
        {$rrule}
        {$e/rdate}
        {$e/exdate}
        </event>
};
