xquery version "3.1";
(: 
 : Bundle creation only for testing, not usable otherwise
 : 
 :)
module namespace mutil ="http://eNahar.org/ns/nonfhir/util";

import module namespace date      = "http://eNahar.org/ns/lib/date";
import module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize" at "/db/apps/nabu/FHIR/meta/serialize-fhir-resources.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";
declare namespace fo     ="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo  ="http://exist-db.org/xquery/xslfo";
declare namespace   tei = "http://www.tei-c.org/ns/1.0";

(:~ moveToHistory
 : Move to history
 : 
 : @param $order
 : @return ()
 :)
declare function mutil:moveToHistory(
      $objects as element()*
    , $newpath as xs:string
    ) 
{
    for $o in $objects
    let $pathCurrent  := util:collection-name($o)
    let $nameCurrent  := util:document-name($o)
    return
        if ($pathCurrent = $newpath)
        then ()
        else (
            let $nameHistory    :=
                (:if (xmldb:get-child-resources($getf:colFhirHistory)[.=$nameCurrent])
                then concat(util:uuid(),'.xml')
                else :)$nameCurrent
            return
                system:as-user('vdba', 'kikl823!', 
                        xmldb:move($pathCurrent, $newpath, $nameHistory)
                    )
        )
};

declare function mutil:addNamespaceToXML($noNamespaceXML as element(*),$namespaceURI as xs:string) as element(*)
{
    element {fn:QName($namespaceURI,fn:local-name($noNamespaceXML))}
    {
         $noNamespaceXML/@*
        ,for $node in $noNamespaceXML/node()
            return
                if (exists($node/node()))
                then mutil:addNamespaceToXML($node,$namespaceURI)
                else if ($node instance of element()) 
                then element {fn:QName($namespaceURI,fn:local-name($node))}{$node/@*}
                else $node
    }
};

declare function mutil:rest-response(
      $code as xs:integer
    , $message as xs:string
    ) as element(rest:response)
{
    <rest:response>
        <http:response status="{$code}" message="{$message}">
            <http:header name="X-RXQ-Message" value="{$message}"/> 
        </http:response>
    </rest:response>
};

declare function mutil:prepareResultBundleXML(
      $hits as item()*
    , $start as xs:integer
    , $length as xs:string
    ) as element(fhir:Bundle)
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:text/fhir:div/@value/string() descending
            return
                $c
    return
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="bundle-example"/> 
            <meta> 
                <lastUpdated value="{date:now()}"/>
            </meta>  
            <type value="searchset"/>   
            <total value="{$count}"/> 
            <link> 
                <relation value="self"/> 
                <url value="https://example.com/base/PractitionerRole"/> 
            </link> 
            <link> 
                <relation value="next"/> 
                <url value="https://example.com/base/PractitionerRole?page=2"/> 
            </link> 
            <!-- interim: needed for paged tables in BetterForms -->
            <count>{$count}</count>
            <start>{$start}</start>
            <length>{$len1}</length>
            {
                for $r in subsequence($sorted-hits, $start, $len1) 
                return
                    <entry>
                        <fullUrl value=""/>
                        <resource>
                            {$r}
                        </resource>
                        <search>
                            <mode value="match"/>
                            <score value="1"/>
                        </search>
                    </entry>
            }
        </Bundle>
};

declare function mutil:resource2json($r as item())
{
  serialize:resource2json($r, false(), "4.3")
};

declare function mutil:prepareResultBundleJSON(
      $hits as item()*
    , $start as xs:integer
    , $length as xs:string
    ) as xs:string
{
    let $count := count($hits)
    let $len0  := if ($length="*")
        then $count
        else xs:integer($length)
    let $len1  := if ($count> $len0)
        then $len0
        else $count
    let $sorted-hits := for $c in $hits
            order by $c/fhir:text/*:div/@value/string() descending
            return
                $c
    return
        serialize:resource2json(
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="bundle-example"/> 
            <meta> 
                <lastUpdated value="{date:now()}"/>
            </meta>  
            <type value="searchset"/>   
            <total value="3"/> 
            <link> 
                <relation value="self"/> 
                <url value="https://example.com/base/PractitionerRole?patient=347&amp;_include=MedicationRequest.medication"/> 
            </link> 
            <link> 
                <relation value="next"/> 
                <url value="https://example.com/base/PractitionerRole?patient=347&amp;searchId=ff15fd40-ff71-4b48-b366-09c706bed9d0&amp;page=2"/> 
            </link> 
            {
                for $r in subsequence($sorted-hits, $start, $len1)
                return
                    <entry>
                        <fullUrl value="{concat('http://localhost:8080/exist/restxq/metis/PractitionerRole/',$r/fhir:id/@value)}"/>
                        <resource>
                            {$r}
                        </resource>
                        <search>
                            <mode value="match"/>
                            <score value="1"/>
                        </search>
                    </entry>
            }
        </Bundle>
        , false()
        , "4.3"
        )
};

declare function mutil:prepareHistoryBundleXML(
      $id as xs:string
    , $entries as item()*
    ) as element(fhir:Bundle)
{
    let $serverip := 'http://enahar.org'
    return
        <Bundle xmlns="http://hl7.org/fhir">
            <id/>
            <meta>
                <versionId value="0"/>
            </meta>
            <type value="history"/>
            <title/>
            <link rel="self"      href="{$serverip}/exist/restxq/metis/devices/{$id}/_history"/>
            <link rel="fhir-base" href="{$serverip}/exist/restxq/metis"/>
            <os:totalResults xmlns:os="http://a9.com/-/spec/opensearch/1.1/">{count($entries)}</os:totalResults>
            <published>{date:now()}</published>
            <author>
                <name>eNahar FHIR Server</name>
            </author>
            {
                for $e in $entries
                order by xs:integer($e/fhir:meta/fhir:versionId)
                return
                    <entry>
                        {$e/title}
                        <id>{$serverip}/metis/Device/{$id}/_history/{$e/fhir:meta/fhir:versionID/@value/string()}</id>
                        <updated>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</updated>
                        <published>{$e/fhir:meta/fhir:lastUpdated/@value/string()}</published>
                        <link rel="self" href="{$serverip}/metis/Device/{$id}/_history/{$e/fhir:meta/fhir:versionId/@value/string()}"/>
                        <content type="text/xml">
                            {$e}
                        </content>
                    </entry>
            }
        </Bundle>
};

