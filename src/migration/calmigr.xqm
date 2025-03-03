xquery version "3.1";

module namespace calmigr = "http://eNahar.org/ns/nonfhir/cal-migration";

import module namespace date = "http://eNahar.org/ns/lib/date";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


declare function calmigr:update-2.0($c as item())
{
    let $version := ($c/meta/versionID/@value/string(),$c/meta/versionId/@value/string())[1]
    let $loguid  := ($c/lastModifiedBy/reference/@value/string(), "metis/practitioners/u-admin")[1]
    let $lognam  := ($c/lastModifiedBy/display/@value/string(), "migbot")[1]
    let $lastUpd := ($c/lastModified/@value/string(), xs:string(date:now()))[1]
    let $identifier := if ($c/identifier)
        then
            <identifier xmlns="http://hl7.org/fhir">
                <use value="official"/>
                <system value="http://eNahar.org/ns/system/ical-id"/>
                <value value="Schedule/{substring-after($c/*:identifier/*:value/@value,"enahar/schedules/")}"/>
            </identifier>
        else ()
    let $active  := $c/active/@value/string()
    let $cutype := if ($c/cutype)
        then
            <cutype xmlns="http://hl7.org/fhir">
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-usertype"/>
                    <code value="{if ($c/*:cutype//*:code/@value='person') then 'individual' else 'role'}"/>
                </coding>
            </cutype>
        else
            <cutype xmlns="http://hl7.org/fhir">
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-usertype"/>
                    <code value="schedule"/>
                </coding>
            </cutype>
    let $caltype := if ($c/caltype/@value)
        then
            <caltype xmlns="http://hl7.org/fhir">
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-caltype"/>
                    <code value="{$c/*:caltype/@value/string()}"/>
                </coding>
            </caltype>
        else if ($c/caltype/coding)
        then
            <caltype xmlns="http://hl7.org/fhir">
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-caltype"/>
                    <code value="{$c/*:caltype//*:code/@value/string()}"/>
                </coding>
            </caltype>
        else if (local-name($c)='schedule')
        then
            <caltype xmlns="http://hl7.org/fhir">
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-caltype"/>
                    <code value="{$c/*:type/@value/string()}"/>
                </coding>
            </caltype>
          else
            <caltype xmlns="http://hl7.org/fhir">
                <coding>
                    <system value="http://eNahar.org/ns/system/ical-caltype"/>
                    <code value="primary"/>
                </coding>
            </caltype>
    let $serviceType := if ($c/owner/group and $c/owner/group/@value!='')
        then
            <serviceType xmlns="http://hl7.org/fhir">
                <coding>
                    <system value="http://eNahar.org/ns/system/service-type"/>
                    <code value="{$c/*:owner/*:group/@value/string()}"/>
                </coding>
            </serviceType>
        else ()
    let $active  := $c/active/@value/string()
    let $actor   := if ($c/owner)
        then
            <actor xmlns="http://hl7.org/fhir">
              <reference value="{$c/*:owner/*:reference/@value/string()}"/>
              <display value="{$c/*:owner/*:display/@value/string()}"/>
            </actor>
        else ()
    let $name    := ($c/summary/@value/string(), $c/name/@value/string())[1]
    let $comment := $c/description/@value/string()
    let $location   := if ($c/location)
        then
            <location xmlns="http://hl7.org/fhir">
              <reference value="Location/{substring-after($c/*:location/*:reference/@value,'metis/locations/')}"/>
              <display value="{$c/*:location/*:display/@value/string()}"/>
            </location>
        else ()
    return
    <ICal xml:id="{$c/@xml:id/string()}" xmlns="http://hl7.org/fhir">
        <id value="{$c/*:id}"/>
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
        <serviceCategory>
          <coding>
            <system value="http://hl7.org/fhir/ValueSet/service-category"/>
            <code value="SPZ"/>
          </coding>
        </serviceCategory>
        {$serviceType}
        <specialty>
            <coding>
                <system value="http://hl7.org/fhir/ValueSet/c80-practice-codes"/>
                <code value="94538003"/>
            </coding>
        </specialty>
        {$actor}
        <organization>
          <reference value="Organization/kikl-spz"/>
          <display value="UKK SPZ"/>
        </organization>
        <name value="{$name}"/>
        <comment value="{$comment}"/>
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
                  <type xmlns="http://hl7.org/fhir" value="{$s/*:global/*:type/@value/string()}"/>
                , <basedOn xmlns="http://hl7.org/fhir">
                    <reference value="Schedule/{substring-after($s/*:global/*:reference/@value,"enahar/schedules/")}"/>
                    <display value="{$s/*global/*:display/@value/string()}"/>
                  </basedOn>
                )
          else ()
    let $appLetter := if ($s/appLetter)
        then
        <appLetter xmlns="http://hl7.org/fhir">
           <reference value="Template/{$s/*:appLetter/*:template/*:name/@value/string()}"/>
           <altName value="{$s/*:appLetter/*:alt-name/@value/string()}"/>
        </appLetter>
        else ()
    let $period := if ($s/period)
        then
            <period xmlns="http://hl7.org/fhir">
                {
                  if ($s/*:period/*:start/@value!="") then 
                    <start xmlns="http://hl7.org/fhir" value="{$s/*:period/*:start/@value/string()}"/> else ()
                , if ($s/period/end/@value!="") then 
                    <end xmlns="http://hl7.org/fhir" value="{$s/*:period/*:end/@value/string()}"/> else ()
                }
            </period>
        else ()
    let $location := if ($s/location)
        then
            <location xmlns="http://hl7.org/fhir">
              <reference value="Location/{substring-after($s/*:location/*:reference/@value,'metis/locations/')}"/>
              <display value="{$s/*:location/*:display/@value/string()}"/>
            </location>
        else ()
    let $note := if($s/note/@value!='')
        then
            <note xmlns="http://hl7.org/fhir">
                <text value="{$s/*:note/@value/string()}"/>
            </note>
        else ()
    let $rendering  := if ($s/fc)
        then
        <rendering xmlns="http://hl7.org/fhir">
            <className value="{$s/*:fc/*:className/@value/string()}"/>
            <backgroundColor value="{$s/*:fc/*:backgroundColor/@value/string()}"/>
            <textColor value="{$s/*:fc/*:textColor/@value/string()}"/>
            <editable value="{$s/*:fc/*:editable/@value/string()}"/>
        </rendering>
        else ()
    let $pph := if ($s/timing/parallel-per-hour) then
        <parallelPerHour xmlns="http://hl7.org/fhir" value="{$s/*:timing/*:parallel-per-hour/@value/string()}"/> else ()
    let $timing := if ($s/timing)
        then
        <timing xmlns="http://hl7.org/fhir">
            <pre value="{$s/*:timing/*:pre/@value/string()}"/>
            <exam value="{$s/*:timing/*:exam/@value/string()}"/>
            <post value="{$s/*:timing/*:post/@value/string()}"/>
            <overbookable value="{$s/*:timing/*:overbookable/@value/string()}"/>
            <query value="{$s/*:timing/*:query/@value/string()}"/>
            <blocking value="{$s/*:blocking/@value/string()}"/>
            {$pph}
        </timing>
        else ()
    return
    <schedule xmlns="http://hl7.org/fhir">
        {$wasGlobal}
        <isSpecial value="{$s/*:isSpecial/@value/string()}"/>
        <ff value="{$s/*:ff/@value/string()}"/>
        {$period}
        <timezone value="MEZ"/>
        <venue>
          <priority value="normal"/>
          {$location}
        </venue>
        {$note}
        {$rendering}
        {$appLetter}
        {$timing}
        {
        for $a in $s/*:agenda
        return
            calmigr:update-schedule-2.0($a)
        }
        {
        for $e in $s/*:event
        return
            calmigr:update-event-2.0($e)
        }
    </schedule>
};

declare function calmigr:update-event-2.0($e as element(event))
{
    let $note := if($e/note/@value!='')
        then
            <note xmlns="http://hl7.org/fhir">
                <text value="{$e/*:note/@value/string()}"/>
            </note>
        else ()
    let $rrule := if ($e/rrule)
        then
        <rrule xmlns="http://hl7.org/fhir">
        { 
          <freq value="{$e/*:rrule/*:freq/@value/string()}"/>
        , if ($e/rrule/byYear and $e/rrule/byYear/@value!="") then 
              <byYear value="{$e/*:rrule/*:byYear/@value/string()}"/> else ()
        , if ($e/rrule/byMonth and $e/rrule/byMonth/@value!="") then
              <byMonth value="{$e/*:rrule/*:byMonth/@value/string()}"/> else ()
        , if ($e/rrule/byWeekNo and $e/rrule/byWeekNo/@value!="") then
              <byWeek value="{$e/*:rrule/*:byWeekNo/@value/string()}"/> else ()
        , if ($e/rrule/byDay and $e/rrule/byDay/@value!="") then
              <byDay value="{$e/*:rrule/*:byDay/@value/string()}"/> else ()
        }
        </rrule>
        else ()
    let $location := if ($e/venue/location)
        then
            <location xmlns="http://hl7.org/fhir">
              <reference value="Location/{substring-after($e/*:venue/*:location/*:reference/@value,'metis/locations/')}"/>
              <display value="{$e/*:venue/*:location/*:display/@value/string()}"/>
            </location>
        else ()
    return
        <event xmlns="http://hl7.org/fhir">
          <name value="{$e/*:name/@value/string()}"/>
          <summary value="{$e/*:summary/@value/string()}"/>
          <description value="{$e/*:description/@value/string()}"/>
          <start value="{$e/*:start/@value/string()}"/>
          <end value="{$e/*:end/@value/string()}"/>
          {$note}
          <venue>
            <priority value="{$e/*:venue/*:priority/@value/string()}"/>
            {$location}
          </venue>
          {$rrule}
          { for $d in $e/*:rdate/* return <rdate value="{$d/@value/string()}"/> }
          { for $d in $e/*:exdate/* return <exdate value="{$d/@value/string()}"/> }
        </event>
};
