xquery version "3.1";
(: ~
 : Defines all the RestXQ endpoints used for holidays.
 : 
 : @author Peter Herkenrath
 : @version 0.1
 : 2015-03-28
 :)
module namespace nholiday ="http://eNahar.org/ns/nonfhir/nholiday";

import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config="http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';

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
    let $uuid := $request?parameters?uuid
    let $hdes := doc($config:holiday-data || "holidays.xml")//event[name/@value=$uuid]
    return
      if (count($hdes)=1) then
        switch ($accept)
        case "application/xml" return $hdes
        case "application/json" return serialize:resource2json($hdes, false(), "4.3")
        default return errors:error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else errors:error($errors:NOT_FOUND, "nholiday: ", map { "info": "invalid uuuid"})
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
    let $period := mutil:analyzeQuery($request?parameters?period, "date")
    let $hdes := doc($config:holiday-data || "holidays.xml")//event[name/@value=$uuid]
    let $now := date:now()
    let $tmax := if ($period)
	        then $period[prefix/@value="lt"]/value/@value
        	else $now
    let $tmin := if ($period)
	        then $period[prefix/@value="gt"]/value/@value
	        else $now
    let $s  := date:iso2date($tmin)
    let $e  := date:iso2date($tmax)
    let $nofd  := xs:integer(floor(($e - $s) div xs:dayTimeDuration('P1D')))
    let $events  := doc($config:holiday-data || "holidays.xml")//event
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
                   <class>{$hds/className/@value/string()}</class>
                 , <backgroundColor>{$hds/backgroundColor/@value/string()}</backgroundColor>
                 , <textColor>{$hds/textColor/@value/string()}</textColor>
                 , <editable>{$hds/editable/@value/string()}</editable>
                 )
                for $d in (0 to $nofd)
                let $date  := $s + xs:dayTimeDuration('P1D')*$d
                let $hde := ice:match-rrules($date, $events)
                return
                  nholiday:fc-event($hde, $date, $attributes)
          else ()
    return
        switch ($accept)
        case "application/xml" return 
                mutil:prepareResultBundleXML($matched,1,"*")
        case "application/json" return
                mutil:prepareResultBundleJSON($matched,1,"*")
        default return errors:error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
};

declare %private function nholiday:fc-event($e as element(event), $date as xs:date, $attributes as item()*) as element(event)?
{
  <event>
    <id value="{$e/name/@value/string()}"/>
    <title value="{$e/description/@value/string()}"/>
    <type value="{$e/type/@value/string()}"/>
    <start>{dateTime($date, xs:time(xs:dateTime($e/start/@value)))}</start>
    { if ($e/type/@value='official')
      then
        <allDay value="true"/>
      else
        (
          <end value="{if ($e/type/@value='traditional')
                       then dateTime($date, xs:time(xs:dateTime($e/end/@value)))
                       else concat($date,'T23:59:59')}"/>
        , <allDay value="false"/>
        )
    }
    <editable>false</editable>
    {$attributes/*[not( self::editable or  self::allDay) ]}
  </event>
};
