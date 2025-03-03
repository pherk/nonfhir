xquery version "3.1";

module namespace leavemigr = "http://eNahar.org/ns/nonfhir/leave-migration";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


declare function leavemigr:update-2.0($e as item())
{
    let $version := ($e/meta/versionID/@value/string(),$e/meta/versionId/@value/string())[1]
    let $loguid  := $e/lastModifiedBy/reference/@value/string()
    let $lognam  := $e/lastModifiedBy/display/@value/string()
    let $lastUpd := $e/lastModified/@value/string()

    let $note := if($e/note/@value!='')
        then
            <note xmlns="http://hl7.org/fhir">
                <text value="{$e/*:note/@value/string()}"/>
            </note>
        else ()
    return
    <Event xml:id="{$e/@xml:id/string()}" xmlns="http://hl7.org/fhir">
        <id value="{$e/*:id/@value/string()}"/>
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
        <status value="{$e/*:status//*:code/@value/string()}"/>
        <code>
            <coding>
                <system value="http://eNahar.org/ns/system/event-code"/>
                <code value="leave"/>
            </coding>
        </code>
        <actor>
          <reference value="{$e/*:actor/*:reference/@value/string()}"/>
          <display value="{$e/*:actor/*:display/@value/string()}"/>
        </actor>
        <type value="{if($e/*:allDay/@value='true') then 'allDay' else 'partial'}"/>
        <title value="{$e/*:summary/@value/string()}"/>
        <description value="{$e/*:description/@value/string()}"/>
        <period>
        {
          if ($e/*:period/*:start/@value!="") then 
            <start xmlns="http://hl7.org/fhir" value="{$e/*:period/*:start/@value/string()}"/> else ()
        , if ($e/*:period/*:end/@value!="") then 
            <end xmlns="http://hl7.org/fhir" value="{$e/*:period/*:end/@value/string()}"/> else ()
        }
        </period>
        <reasonCode>
          <coding>
            <system value="http://eNahar.org/ns/system/event-reason"/>
            <code value="{$e/*:cause/*:coding/*:code/@value/string()}"/>
          </coding>
        </reasonCode>
        {$note}
        </Event>
};
