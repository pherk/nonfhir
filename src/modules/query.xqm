xquery version "3.1";
(: 
 : analyze query string from http request
 : 
 :)
module namespace query ="http://eNahar.org/ns/nonfhir/query";

import module namespace date      = "http://eNahar.org/ns/lib/date";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace http = "http://expath.org/ns/http-client";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";


declare function query:analyze(
      $params as item()*
    , $type as xs:string
    , $default as item()+
    ) as item()+
{
  let $r := query:analyze($params,$type)
  return
    if (count($r)>0)
    then $r
    else $default
};

declare function query:analyze(
      $params as item()*
    , $type as xs:string
    ) as item()*
{
   for $s in $params
   return
     switch ($type)
     case "string"    return tokenize($s, ",")
     case "reference" return tokenize($s, ",")
     case "token"     return tokenize($s, ",")
     case "boolean"   return (for $bs in tokenize($s, ",") return xs:boolean($bs))[1]
     case "date"      return let $ds := tokenize($s, ",")
                           for $d in $ds
                           return query:analyzeDate($d)
     case "number"   return let $ds := tokenize($s, ",")
                           for $d in $ds
                           return query:prefix($d)
     default return tokenize($s,",")
};

declare function query:analyzeDate($d as xs:string) as item()
{
  let $r := query:prefix($d)
  let $p  := $r[1]
  let $md := $r[2]
  let $d := if (contains($md,"T"))
            then date:iso2dateTime($md)
            else date:iso2date($md)
  return
    <queryparam>
      <type value="date"/>
      <prefix value="{$p}"/>
      <value value="{xs:string($d)}"/>
    </queryparam>
};

declare function query:prefix($s as xs:string) as item()*
{
  let $two := substring($s,1,2)
  return
    if ($two = ("eq","le","lt","ge","gt","ne"))
    then ($two, substring($s,3))
    else ("eq", $s)
};


