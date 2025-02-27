xquery version "3.1";
(: ~
 : Defines all the RestXQ endpoints used for holidays.
 : 
 : @author Peter Herkenrath
 : @version 0.1
 : 2015-03-28
 :)
module namespace nholiday ="http://eNahar.org/ns/nonfhir/nholiday";

import module namespace config="http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace query  = "http://eNahar.org/ns/nonfhir/query" at "../modules/query.xqm";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace date  ="http://eNahar.org/ns/lib/date";
import module namespace ice    = "http://eNahar.org/ns/lib/ice";   (: ice:match-rrules() :)

declare namespace xdb ="http://exist-db.org/xquery/xmldb";
declare namespace rest="http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

(:~
 : GET: /Holiday/{uuid}
 : get holiday by name
 : 
 : @param $id  uuid
 :)
declare function nholiday:read-holiday($request as map(*))
{
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid := $request?parameters?id
    let $hdes := collection($config:holiday-data)/ICal[id/@value=$uuid]
    return
      if (count($hdes)=1) then
        switch ($accept)
        case "application/xml" return $hdes
        case "application/json" return mutil:resource2json($hdes)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nholiday: ", map { "info": "invalid uuuid"})
};

(:~
 : GET: /Holiday
 : serch holidays
 : 
 : @param period
 : 
 : @return bundle of <events/>
 :)
declare function nholiday:search-holiday($request as map(*))
{
  let $lll := util:log-app("TRACE","apps.nabu", $request)
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elements:= query:analyze($request?parameters?_elements, "string")
    let $name   := query:analyze($request?parameters?name, "string")
    let $period := query:analyze($request?parameters?period, "date")
    let $type   := query:analyze($request?parameters?type, "string")
    let $hds    := collection($config:holiday-data)/ICal[caltype//code[@value='holiday']]
    let $events := if (count($name)>0)
        then $hds//event[name/@value=$name]
        else $hds//event
    let $now := date:now()
    let $tmax := if (count($period[prefix/@value="le"])=1)
	        then $period[prefix/@value="le"]/value/@value
	        else error($errors:BAD_REQUEST, "query should define only one period of time", map { "info": $period})
    let $tmin := if (count($period[prefix/@value="ge"])=1)
	        then $period[prefix/@value="ge"]/value/@value
	        else error($errors:BAD_REQUEST, "query should define only one period of time", map { "info": $period})
    let $s  := date:iso2date($tmin)
    let $e  := date:iso2date($tmax)
    let $nofd  := xs:integer(floor(($e - $s) div xs:dayTimeDuration('P1D')))
    let $matched :=
        for $d in (0 to $nofd)
        let $date  := $s + xs:dayTimeDuration('P1D')*$d
        let $hde := ice:match-rrules($date, $events)
        return
          if ($hde)
          then if ($accept="application/xml")
              then nholiday:fc-event($hde, $date, ())
              else
                let $attributes := 
                 ( 
                   <class>{$hds//className/@value/string()}</class>
                 , <backgroundColor>#006400</backgroundColor>
                 , <textColor>#ffffff</textColor>
                 , <editable>{$hds/editable/@value/string()}</editable>
                 )
                return
                  nholiday:fc-event($hde, $date, $attributes)
          else ()
    return
        switch ($accept)
        case "application/xml" return 
                mutil:prepareResultBundleXML($matched,1,"*")
        case "application/json" return
                mutil:prepareResultBundleJSON($matched,1,"*")
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
};

declare %private function nholiday:fc-event($e as element(Event), $date as xs:date, $attributes as item()*) as element(Event)?
{
  <Event>
    <id value="{$e/name/@value/string()}"/>
    <title value="{$e/description/@value/string()}"/>
    <type value="{$e/type/@value/string()}"/>
    <period>
      <start value="{if ($e/start)
                     then concat(xs:string($date), xs:string(xs:time(date:iso2dateTime($e/start/@value))))
                     else concat(xs:string($date),'T00:00:00')}"/>
      <end value="{if ($e/end)
                     then concat(xs:string($date), xs:string(xs:time(date:iso2dateTime($e/end/@value))))
                     else concat(xs:string($date),'T23:59:59')}"/>
    </period>
    <rendering>
      {$attributes/*[not( self::editable or  self::allDay) ]}
      <editable>false</editable>
      <allDay value="{$e/type/@value='official'}"/>
    </rendering>
  </Event>
};
