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
            <note>
                <text value="{$e/note/@value/string()}"/>
            </note>
        else ()
    return
    <Event xml:id="{$e/@xml:id/string()}">
        {$e/id}
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
        <status value="{$e/status//code/@value/string()}"/>
        <code>
            <coding>
                <system value="http://eNahar.org/ns/system/event-code"/>
                <code value="leave"/>
            </coding>
        </code>
        {$e/actor}
        <type value="{if($e/allDay/@value='true') then 'allDay' else 'partial'}"/>
        <title value="{$e/summary/@value/string()}"/>
        {$e/description}
        {$e/period}
        <reasonCode>
          <coding>
            <system value="http://eNahar.org/ns/system/event-reason"/>
            {$e/cause/coding/*}
        </reasonCode>
        {$note}
        </Event>
};
