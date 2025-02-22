xquery version "3.1";

(:~
 : TODO: id attribute not serialized
 :)
(:~
: Defines function for serializing FHIR-XML-Resourcen
: @author Peter Herkenrath
: @version 1.1
: @see http://enahar.org
:
:)
module namespace serialize = "http://enahar.org/exist/apps/nabu/serialize";

import module namespace inventory = "http://enahar.org/exist/apps/nabu/inventory" at "../../FHIR/meta/inventory.xqm";

declare function serialize:resource2json(
          $r as item()
        , $isArray as xs:boolean
        , $fhir_version as xs:string
        ) as xs:string
{
    let $base-info   := inventory:baseInfo($fhir_version)
    let $domain      := local-name($r)
    let $domain-info := inventory:domainInfo($domain, $fhir_version)

let $lll := util:log-app('TRACE','apps.nabu', $r)
(: 
let $lll := util:log-app('TRACE','apps.nabu', $base-info)
let $lll := util:log-app('TRACE','apps.nabu', $domain-info)
:)

    let $res :=
        concat(
             '{'
            , '"resourceType" : "', $domain, '",'
            , string-join(reverse(serialize:resource2json2(head($r/*),tail($r/*),(), $isArray, $domain-info, $base-info, $fhir_version)), ',&#10;')
            , '}'
            )
    let $lll := util:log-app('TRACE','apps.nabu', $res)
    return
        $res
};

declare %private function serialize:domainElement(
        $domain as element(domain)
      , $name as xs:string
    ) as item()
{
    let $de := $domain/element[@name=$name]
    return
        if ($de)
        then $de
        else error(QName('http://eNahar.org/exist/apps/nabu/serialize',$domain/@name/string()), concat('Invalid element: ', $name))
};

declare %private function serialize:resource2json2(
      $head as item()
    , $tail as item()*
    , $acc as xs:string*
    , $isArray as xs:boolean
    , $domain as element(domain)
    , $base as item()
    , $fhir_version as xs:string
    ) as xs:string*
{
(: 
    let $lll := util:log-app('TRACE','apps.nabu', $head)
    let $lll := util:log-app('TRACE','apps.nabu', $domain)
:)
    let $name := local-name($head)
    let $lll := util:log-app('TRACE','apps.nabu', $name)
    (: check array feature of head, select all props with that name and serialiaze as array :)
    let $delem  := serialize:domainElement($domain,$name)
    let $lll := util:log-app('TRACE','apps.nabu', string-join(("delem ", $delem/@name),':'))
    let $item  := if ($isArray or $delem/@array='true')
        then serialize:property2json(($head, $tail[local-name(.)=$name]), $delem, $domain, $base, $fhir_version)
        else serialize:property2json(($head), $delem, $domain, $base, $fhir_version)
    let $rem := $tail[local-name(.)!=$name]
    let $newacc := ($item,$acc)
    return
        if (count($rem)>0)
        then
            serialize:resource2json2(head($rem),tail($rem), $newacc, $isArray, $domain, $base, $fhir_version)
        else
            $newacc
};

declare %private function serialize:property2json(
      $ps as item()*
    , $delem as element(element)
    , $domain as element(domain)
    , $base as item()
    , $fhir_version
    ) as xs:string*
{
    let $lll := util:log-app('TRACE','apps.nabu', $delem)
    return
    if ($delem/@sub='true')
        then
            serialize:backbone2json($ps, $delem, $domain, $base,$fhir_version)
        else
            serialize:propsOther2json($ps, $delem, $domain, $base, $fhir_version)
};

declare %private function serialize:backbone2json(
      $ps as item()*
    , $delem as element(element)
    , $domain as element(domain)
    , $base as item()
    , $fhir_version as xs:string
    ) as xs:string*
{
    let $json :=
            for $p in $ps
            return
                serialize:backboneElement($p, $domain, $base, $fhir_version)
    return
        if ($delem/@array='true')
        then
            concat('"', local-name(head($ps)), '" : [', string-join($json, ', '), ']')
        else
            concat('"', local-name(head($ps)), '" : ', string-join($json, ', '))
};

declare %private function serialize:propsOther2json(
      $ps as item()*
    , $delem as item()
    , $domain as element(domain)
    , $base as element(base)
    , $fhir_version as xs:string
    ) as xs:string*
{
    let $json := 
        for $p in $ps
        return
                    switch($delem/@class)
                    case 'primitive' return serialize:primitive3($p, $domain, $base)
                    case 'pseudo-primitive' return serialize:primitive3($p, $domain, $base)  (: patch for types not classified :)
                    case 'complex'   return serialize:complex($p, $delem/@type, $domain, $base)
                    case 'meta'      return concat('"error" : "', local-name($p), '"')
                    case 'special'   return serialize:special($p, $delem/@type, $domain, $base)
                    case 'resource-container' return serialize:resource2json($p/*, $delem/@array, $fhir_version)       (: Bundle contains such a thing :)
                    default          return concat('"error" : "', local-name($p), '"')
        
    return
        if ($delem/@array='true')
        then
            concat('"', local-name(head($ps)), '" : [', string-join($json, ', '), ']')
        else if (string-length($json)>0)
        then
            concat('"', local-name(head($ps)), '" : ', string-join($json, ', '))
        else ()
};

declare %private function serialize:baseProperty2json(
      $ps as item()*
    , $isArray as xs:boolean
    , $props as item()*
    , $base-info as item()
    ) as xs:string
{
    let $pname   := local-name(head($ps))
    let $type    := ($props[@name=$pname]/@type,'string')[1]
    let $class := inventory:baseTypeclass($type)
(:
let $lll := util:log-app('TRACE','apps.nabu', concat('base: ',$pname))
let $lll := util:log-app('TRACE','apps.nabu', $props)
let $lll := util:log-app('TRACE','apps.nabu', $type)
let $lll := util:log-app('TRACE','apps.nabu', $class)
:)
    let $json  := 
            for $p in $ps
            return
            switch($class)
                case 'primitive' return serialize:primitive($p, $base-info)
                case 'complex'   return serialize:complex($p, $type, $base-info, $base-info)
                default          return concat('"error" : "', $pname, '"')
    return
        if ($isArray)
        then
            concat('"', $pname, '" : [', string-join($json, ', '), ']')
        else
            concat('"', $pname, '" : ', string-join($json, ', '))
};

declare %private function serialize:backboneElement(
      $bb
    , $parent-domain as element(domain)
    , $base-info as item()
    , $fhir_version
    ) as xs:string
{
    let $bbname := local-name($bb)
let $lll := util:log-app('TRACE','apps.nabu', concat('backbone: ',$bbname))
let $lll := util:log-app('TRACE','apps.nabu', $parent-domain)
    let $subDomain := $parent-domain/element[@name=$bbname]/@type/string()
    let $bbDomain-info := inventory:domainInfo($subDomain, $fhir_version)
let $lll := util:log-app('TRACE','apps.nabu', $bbDomain-info)
    let $isArray := false()
    return
        concat(
              '{'
            , string-join(reverse(serialize:resource2json2(head($bb/*),tail($bb/*),(), $isArray, $bbDomain-info, $base-info,$fhir_version)), ',&#10;&#9;')
            , '}'
            )
};

declare %private function serialize:attributeElement(
      $pa
    , $base as element(base)
    ) as xs:string
{
    concat('"', name($pa), '" : "', serialize:escapeControlChars(string($pa)), '"')
};

declare %private function serialize:primitive(
      $p as item()
    , $base as element(base)
    ) as xs:string
{
    concat('"', serialize:escapeControlChars($p/@value), '"')
};

declare %private function serialize:primitive3(
      $p as item()
    , $domain as element(domain)
    , $base as element(base)
    ) as xs:string*
{
    let $lll := util:log-app('TRACE','apps.nabu', $p)
    let $delem  := serialize:domainElement($domain,local-name($p))
    return
        if ($delem/@type="boolean")
        then
            $p/@value/string()
        else if ($delem/@type=("integer","unsignedInt","positiveInt","decimal"))
        then $p/@value/string()
        else 
            concat('"', serialize:escapeControlChars($p/@value), '"')
};

declare %private function serialize:complex(
      $p as item()
    , $domain-type as  xs:string
    , $domain-info as item()
    , $base-info as item()
    ) as xs:string*
{
let $lll := util:log-app('TRACE','apps.nabu', concat('complex: ', local-name($p)))
let $lll := util:log-app('TRACE','apps.nabu', $p)
    let $props := $base-info/complex[@name=$domain-type]/element
(: 
let $lll := util:log-app('TRACE','apps.nabu', $props)
:)
    let $attrjson := if ($p/@*)
        then
            string-join(
            for $pa in $p/@*
            return
                serialize:attributeElement($pa,$base-info)
        , ', ')
        else ()
    let $propjson := if ($p/*)
        then
            let $distinct-props := distinct-values(for $pp in $p/* return local-name($pp))
let $lll := util:log-app('TRACE','apps.nabu', string-join($distinct-props,', '))
            return
            for $d in $distinct-props
            return
                if ($d='div')
                then serialize:convertXHTML($p/*[local-name(.)=$d])
                else
                    let $pp := $p/*[local-name(.)=$d]
                    let $prop := $props[@name=local-name(head($pp))]
                    return 
                        if ($prop)
                        then serialize:baseProperty2json($pp,$prop/@array, $props,$base-info)
                        else util:log-app("ERROR", 'apps.nabu', concat('serialize complex: illegal property: ', $d))
        else ()

    return
        if (count(($attrjson,$propjson))>0)
        then
            concat('{', string-join(($attrjson, $propjson),', '), '}')
        else concat('{ "error" : "missing properties:', local-name($p), '"}')
            (:
            error(QName('http://eNahar.org/exist/apps/nabu/serialize','Complex'), 'Missing properties', $p)
            :)
};

declare %private function serialize:special(
      $p as item()
    , $special-type as xs:string
    , $domain as element(domain)
    , $base-info as element(base)
    ) as xs:string*
{
let $lll := util:log-app('TRACE','apps.nabu', concat('special::',local-name($p)))
(: 
let $lll := util:log-app('TRACE','apps.nabu', concat('type= ',$special-type))
let $lll := util:log-app('TRACE','apps.nabu', $p)
let $lll := util:log-app('TRACE','apps.nabu', $domain)
let $lll := util:log-app('TRACE','apps.nabu', $base-info)
:)
    let $cont := $base-info/complex[@name=$special-type]
    let $attrs := $cont/attribute
    let $props := $cont/element
    let $attrjson := if ($p/@*)
        then
            string-join(
            for $pa in $p/@*
            return
                serialize:attributeElement($pa,$base-info)
        , ', ')
        else ()
    let $propjson := if ($p/*)
        then
            let $distinct-props := distinct-values(for $pp in $p/* return local-name($pp))
let $lll := util:log-app('TRACE','apps.nabu', string-join($distinct-props,', '))
            return
            for $d in $distinct-props
            return
                if ($d='div')
                then serialize:convertXHTML($p/*[local-name(.)=$d])
                else
                    let $pp := $p/*[local-name(.)=$d]
                    let $isArray := $props[@name=local-name($pp[1])]/@array

let $lll := util:log-app('TRACE','apps.nabu', $p)
let $lll := util:log-app('TRACE','apps.nabu', $d)
let $lll := util:log-app('TRACE','apps.nabu', $pp)
let $lll := util:log-app('TRACE','apps.nabu', $props)

                    return
                        serialize:baseProperty2json($pp,$isArray, $props,$base-info)
        else ()
    return
        if (count(($attrjson,$propjson))>0)
        then
            concat('{', string-join(($attrjson, $propjson),', '), '}')
        else error(QName('http://eNahar.org/exist/apps/nabu/serialize','Special'), 'Missing properties', $p)
};

(:~
 : convertXHTML
 : 
 :  <div xmlns="http://www.w3.org/1999/xhtml">
 :      <div class="composite-name">Vausi, Polousi, *2000-02-17</div>
 :  </div>
 : "<div xmlns=\"http://www.w3.org/1999/xhtml\"><div class=\"composite-name\">Vausi, Polausi, *2000-02-17</div>"
 : @return xs:string
 : 

 :)
declare %private function serialize:convertXHTML($div as item()) as xs:string
{
    let $key := '"div": '
    let $value :=
        (
            $key
        ,   '"'
        ,   serialize:transform($div, true(),true())
        ,   '"'
        )
    return
        string-join($value,'')
};

declare %private function serialize:transform($el as node(), $isDiv, $isTEIRoot as xs:boolean) as xs:string
{
    let $lll := util:log-app('TRACE','apps.nabu', $el)
    let $eln := name($el)
    let $xmlns := if ($isDiv or $isTEIRoot)
        then " xmlns=\""" || namespace-uri($el) || "\"""
        else ()
    let $isTEIRoot := $isDiv and $isTEIRoot
    let $attrs := for $a in $el/@*
        return
            ' ' || local-name($a) || "=\""" || $a/string() || "\"""
    let $value :=
        (
           "<", $eln, string-join(($xmlns,$attrs),''), ">"
        ,   for $node in $el/(* | text())
            return
                typeswitch($node)
                case element() return serialize:transform($node, false(),$isTEIRoot)
                case text()    return  $node
                default        return '(error: not handled)'
        ,   "</",$eln,">"
        )
    return
        string-join($value,'')
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
declare %private function serialize:escapeControlChars(
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