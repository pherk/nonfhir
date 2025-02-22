xquery version "3.1";
(: parse FHIR resource using XQuery 3.1's JSON support
 : see http://www.w3.org/TR/xpath-functions-31/#json
 : caveats:
 : - base props are partially validated (occurence, order)
 : - props of complex elements are not validated
 : 
 : @version 0.1 partially validating, adding id attribute for complex elements
 :)
module namespace parse = "http://enahar.org/exist/apps/nabu/parse";

import module namespace ju = "http://joewiz.org/ns/xquery/json-util" at "../../modules/json-util.xqm";
import module namespace inventory = "http://enahar.org/exist/apps/nabu/inventory" at "../../FHIR/meta/inventory.xqm";

declare namespace fhir   = "http://hl7.org/fhir";

declare function parse:resource-to-FHIR(
      $xml as item()*
    , $fhir_version as xs:string) as item()
{
    if ($xml)
    then
        let $rt := $xml/*:string[@key='resourceType']
        return
            if ($rt)
            then
                let $domain := inventory:domainInfo($rt,$fhir_version)
                let $lll := util:log-app("TRACE","apps.nabu",$domain)
                return 
                    element {QName("http://hl7.org/fhir",$xml/*:string[@key='resourceType'])} {
                      for $de in $domain/element
                      let $lll := util:log-app("TRACE","apps.nabu",$de)
                      let $es := $xml/*[./@key=$de/@name/string()]
                      let $lll := util:log-app("TRACE","apps.nabu",$es)
                      return
                          if ($es) (: multiple json element with same key should not happen :)
                          then
                            parse:element-to-property($es, $de/@type, $fhir_version)
                          else () (: element of domain not in xml :)
                    }
            else <no-resourcetype/>
    else <noitems/>
};

declare %private function parse:element-to-property($e, $detype, $fhir_version) as item()*
{
(:~
 : invert control analog to serialize
 : for $d in domain/*
 : return
 :  <p/>
 :)
 let $lll := util:log-app("TRACE","apps.nabu",$e)
 return
    switch (local-name($e))
    case 'string' return
            if ($e/@key='div')
            then
                parse:narrativeDiv($e/string())
            else
            element {QName("http://hl7.org/fhir",$e/@key)} {
                attribute value {$e/string()}
            }
    case 'boolean' return
            element {QName("http://hl7.org/fhir",$e/@key)} {
                attribute value {$e/string()}
            }
    case 'number' return
            element {QName("http://hl7.org/fhir",$e/@key)} {
                attribute value {$e/string()}
            }
    case 'map' return
        element {QName("http://hl7.org/fhir",$e/@key)} {
                if ($e/*[@key='id'])
                then attribute id {$e/*:string[@key='id']/string()}
                else ()
            , for $sub in $e/*[not(@key='id')]
                let $subdomain := inventory:domainInfo($sub/@key,$fhir_version)
                let $lll := util:log-app("TRACE","apps.nabu",$subdomain)
              return
                parse:element-to-property($sub, $subdomain, $fhir_version)
        }
    case 'array' return
        for $m in $e/*
        return
            element {QName("http://hl7.org/fhir",$e/@key)} {
                if ($e/@key='extension')
                then attribute url {$m/*:string[@key='url']/string()}
                else if ($m/*[@key='id'])
                then attribute id {$m/*:string[@key='id']/string()}
                else ()
            ,   if ($m/*/@key)
                then
                  for $sub in $m/*[not(@key=('url','id'))]
                  let $subdomain := inventory:domainInfo($sub/@key,$fhir_version)
                  let $lll := util:log-app("TRACE","apps.nabu",$subdomain)
                  return
                    parse:element-to-property($sub,$subdomain, $fhir_version)
                else
                    switch(local-name($m))
                    case "string" return attribute value {$m/string()}
                    case "boolean" return attribute value {$m/string()}
                    default return error(QName('http://eNahar.org/exist/apps/nabu/parse','array'), 'Unused value', $m)
            }
    default return error(QName('http://eNahar.org/exist/apps/nabu/parse','array'), 'Unused prop', local-name($e))
};

declare %private function parse:narrativeDiv(
      $d as xs:string
    ) as item()*
{
    if (string-length($d)>0)
    then
        let $ed := replace($d,"&amp;lt;",'&#60;')
        let $ed1 := replace($ed,"&amp;gt;",'&#62;')
        let $lll := util:log-app("TRACE","apps.nabu",$ed1)
        return
            fn:parse-xml($ed1)
    else ()
};
(:~ 
 : JSON escaping replaces the characters
 :
 :  quotation mark : 22 : 34 : "
 :  backspace : 8 : 8 : \b
 :  form-feed : 0C : 12 : \f
 :  newline : 0A : 10 : \n
 :  carriage return : 0D : 13 : \r
 :  tab : 9 : 9 : \t
 :  reverse solidus : 5C: 92 : \
 :  solidus : 2F : 47 : /
 :  and any other codepoint in the range 1-31 or 127-159 by an escape in the form \uHHHH where HHHH is the hexadecimal representation of the codepoint value.
 :)
declare %private function parse:escapeControlChars(
        $s as xs:string?
        ) as xs:string?
{
    string-join((
    for $c in string-to-codepoints($s)
    return
        switch($c)
        case  8 return '\\b'
        case  9 return '\\t'
        case 10 return '\\n'
        case 12 return '\\f'
        case 13 return '\\r'
        case 34 return '\"'
        default return codepoints-to-string($c)
    ),'')
};

(:
let $json := parse-json('{"resourceType" : "Patient","id" : "p-21666",
"meta" : {"versionId" : "5",
"extension" : [{"url" : "#lastModifiedBy", "valueReference" : {"reference" : "metis/practitioners/u-pmh", "display" : "Herkenrath, Peter"}}],
"lastUpdated" : "2017-05-11T16:24:56.978+02:00"},
"multipleBirthInteger" : "",
"multipleBirthBoolean" : "false",
"identifier" : [{"use" : "usual", "type" : {}, "system" : "http://uk-koeln.de/#patient-orbis-pnr", "value" : "", "assigner" : {"reference" : "metis/organizations/ukk", "display" : "Unikliniken Köln"}}],
"name" : [{"use" : "official", "family" : "Vauseweh", "given" : "Nick"}],
"gender" : "male",
"birthDate" : "2000-02-17",
"deceasedBoolean" : "false",
"address" : [{"id":"attrtest", "use" : "home", "line" : "Johann-Heinrich- Platz 4", "city" : "Köln", "state" : "NW", "postalCode" : "50935", "country" : "DEU", "period" : {"start" : "", "end" : ""}, "preferred" : "true"}],
"telecom" : [{"use" : "home", "system" : "phone", "value" : "0221 - 44 66 25", "preferred" : "true"}, {"use" : "home", "system" : "mobil", "value" : "0163-56 91 054", "preferred" : "true"}, {"use" : "home", "system" : "mobil", "value" : "0178-8043235 Vater", "preferred" : "true"}],
"extension" : [{"url" : "#patient-presenting-problem", "valueString" : "17.03.2017 keine Termine mehr bei Ellerich Bö Muskeldystrophie Duchenne; normalerweise in Essen gewesen, aber nicht ganz zufrieden; gerne lieber bei uns versorgt ri"}, {"url" : "#patient-insurance", "medical-insurance" : ""}],
"managingOrganization" : {"reference" : "metis/organizations/ukk-oe0734", "display" : "SPZ OE0734"},
"active" : "true",
"communication" : [{"language" : {"coding" : {"system" : "urn:ietf:bcp:47", "code" : "de", "display" : "Deutsch"}, "text" : "Deutsch"},
	"preferred" : "true"}]}')
	
let $pmap := ju:json-to-xml($json)
let $p := local:resource-to-FHIR($pmap)
return
   $p
:)