xquery version "3.1";

module namespace nerror ="http://eNahar.org/ns/nonfhir/nerror";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors ="http://e-editiones.org/roaster/errors";
import module namespace date   ="http://eNahar.org/ns/lib/date";
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config = "http://eNahar.org/ns/nonfhir/config" at "../modules/config.xqm";

declare namespace fhir   = "http://hl7.org/fhir";

(:~
 : GET: /Error/{uuid}
 : get error by id
 : 
 : @param $id  uuid
 : 
 : @return <Error/>
 :)
declare function nerror:read-error($request as map(*)) as item()
{
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $uuid   := $request?parameters?id
    let $errors := collection($config:error-data)/Error[id[@value=$uuid]]
    return
        if (count($errors)=1) then
        switch ($accept)
        case "application/xml" return $errors
        case "application/json" return mutil:resource2json($errors)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nerror: ", map { "info": "invalid uuid"})
};

(:~
 : GET: Error?query
 : get errors
 :
 : @param $type   string
 : @param $name   string
 : @param $active  boolean
 : @return bundle of <Error/>
 :)
declare function nerror:search-error($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := $request?parameters?_elements
    let $type   := $request?parameters?type
    let $name   := $request?parameters?name
    let $serviceType := $request?parameters?serviceType
    let $active := query:analyze($request?parameters?active,'boolean', true())
    let $lll := util:log-app('TRACE','app.nabu', $request?parameters)
    let $coll  := collection($config:error-data)
    let $hits0 := if (count($type)>0)
        then $coll/Error[active[@value=$active]]
        else $coll/Error[active[@value=$active]]
    let $valid := if (count($name)>0)
        then $hits0[matches(name/@value,$name)]
        else $hits0

    let $sorted-hits :=
        for $c in $hits0
        order by lower-case($c/name/@value/string())
        return
            if (string-length($elems)>0)
            then
                <Error>
                  {$c/id}
                { for $p in $c/*[not(self::id)]
                  return
                    if (local-name($p)=$elems) then $p else ()
                }
                </Error>
            else $c
    return
        switch ($accept)
        case "application/xml" return 
                mutil:prepareResultBundleXML($sorted-hits,1,"*")
        case "application/json" return
    (:            mutil:prepareResultBundleJSON($sorted-hits,1,"*") :)
                array {
                  for $service in $sorted-hits
                  return
                    map {
                          "resourceType" : "Error"
                        , "id" : $service/id/@value/string()
                        , "text" : $service/name/@value/string()
                        }
                      }
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
};
 
(:~
 : PUT: /Error/{uuid}
 : Update an existing error or store a new one.
 : 
 : @param $content
 :)
declare function nerror:update-error($request as map(*))
{
    let $user := sm:id()//sm:real/sm:username/string()
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid   := $request?parameters?id
    let $content:= $request?parameters?body/node()
    let $isNew   := not($content/Error/@xml:id)
    let $cid   := if ($isNew)
        then "e-" || $content/Error/name/@value/string()
        else 
            let $id := $content/Error/id/@value/string()
            let $es := collection($config:error-data)/Error[id[@value = $id]]
            let $move := mutil:moveToHistory($es, $config:errorHistory)
            return
                $id
    let $version := if ($isNew) 
        then "0"
        else xs:integer($content/Error/meta/versionId/@value/string()) + 1
    let $elems := $content/Error/*[not(
                   self::meta
                or self::id
                or self::identifier
                )]
    let $uuid := if ($isNew)
        then 'e-' || util:uuid()
        else $cid
    let $meta := $content/Error/meta/*[not(
                   self::versionId
                or self::lastUpdated
                or self::extension
                )]
    let $data :=
        <Error xml:id="{$uuid}">
            <id value="{$cid}"/>
            <meta>
                <versionId value="{$version}"/>
                <extension url="http://eNahar.org/ns/extension/lastUpdatedBy">
                    <valueReference>
                        <reference value="metis/practitioners/{$loguid}"/>
                        <display value="{$lognam}"/>
                    </valueReference>
                </extension>    
                <lastUpdated value="{date:now()}"/>
            </meta>
            <identifier>
                <use value="official"/>
                <system value="http://eNahar.org/ns/extension/enahar-id"/>
                <value value="{$cid}"/>
            </identifier>
            {$elems}
        </Error>
        
(:
    let $lll := util:log-app('TRACE','apps.nabu',$data)
:)

    let $file := $uuid || ".xml"
    return
    try {
        system:as-user('vdba', 'kikl823!', (
            xmldb:store($nerror:error-data, $file, $data)
            , sm:chmod(xs:anyURI($nerror:error-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($nerror:error-data || '/' || $file), $config:data-group)))
    } catch * {
        error($errors:UNAUTHORIZED, "Permission denied", map { "info": "ask the admin"})
    }
};

