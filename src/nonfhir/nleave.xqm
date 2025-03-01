xquery version "3.1";

module namespace nleave = "http://eNahar.org/ns/nonfhir/nleave";

import module namespace config="http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace query  = "http://eNahar.org/ns/nonfhir/query" at "../modules/query.xqm";
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace date  ="http://eNahar.org/ns/lib/date";

declare namespace fhir   = "http://hl7.org/fhir";


(:~
 : GET: nonfhir/Leave/{uuid}
 : get leave by id
 :
 : @param $id  uuid
 :
 : @return <leave/>
 :)
declare function nleave:read-leave($request as map(*)) as item()
{
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := $request?parameters?_elements
    let $uuid   := $request?parameters?id
    let $leaves := collection($config:leave-data)/Event[id[@value=$uuid]]
    return
      if (count($leaves)=1) then 
          switch ($accept)
          case "application/xml" return 
                  $leaves
          case "application/json" return 
                  mutil:resource2json($leaves)
          default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nholiday: ", map { "info": "invalid uuuid"})
};

(:~
 : GET: nonfhir/Leave?query
 : get leave owner
 :
 : @param $owner   string
 : @param $group   string
 : @param $active  boolean
 : @return bundle of <leave/>
 :)
declare function nleave:search-leave($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $accept := $request?parameters?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $format := $request?parameters?_format
    let $elems  := query:analyze($request?parameters?_elements,"string")
    let $actor  := query:analyze($request?parameters?actor,"reference")
    let $group  := query:analyze($request?parameters?group, "string")
    let $period := query:analyze($request?parameters?period, "date")
    let $status := query:analyze($request?parameters?status, "token")
    let $coll := collection($config:leave-data)
    let $now := date:now()
    let $tmax := if (count($period[prefix/@value="le"])=1)
	        then $period[prefix/@value="le"]/value/@value
	        else error($errors:BAD_REQUEST, "query should define only one period of time", map { "info": $period})
    let $tmin := if (count($period[prefix/@value="ge"])=1)
	        then $period[prefix/@value="ge"]/value/@value
	        else error($errors:BAD_REQUEST, "query should define only one period of time", map { "info": $period})
    let $hits0 := if (count($actor)=0)
        then $coll/Event[code//code[@value='leave']][period[start[@value le $tmax]][end[@value ge $tmin]]][status[coding/code/@value=$status]]
        else let $oref := concat('metis/practitioners/', $actor)
            return 
                $coll/Event[code//code[@value='leave']][actor/reference[@value=$oref]][period[start[@value le $tmax]][end[@value ge $tmin]]][status[coding/code/@value=$status]]
    let $sorted-hits :=
        for $c in $hits0
        order by lower-case($c/actor/display/@value/string())
        return
(: TODO analyze elements id, owner, schedule :)
            if (count($elems)>0)
            then
                <Event>
                  {$c/id}
                { for $p in $c/*[not(self::id)]
                  return
                    if (local-name($p)=$elems) then $p else ()
                }
                </Event>
            else $c
    return
      switch ($accept)
      case "application/xml" return
        mutil:prepareResultBundleXML($sorted-hits, 1, "*")
      case "application/json" return
        mutil:prepareResultBundleJSON($sorted-hits, 1, "*")
      default return
       if ($format = "d3") then
        let $actors = ()  (: from groups or so :)
        return
        map {
          "items" : array {
 (: TODO line 424 too much computing, ranks can be precomputed :)
         for $item at $i in $sorted-hits
            let $rank := index-of($actors//*:reference/@value/string(), $item/actor/reference/@value/string()) - 1
            let $start := if ($item/allDay/@value='true')
                then xs:string(fn:dateTime(date:iso2date($item/period/start/@value),xs:time('00:00:00')))
                else $item/period/start/@value/string()
            let $end := if ($item/allDay/@value='true')
                then xs:string(fn:dateTime(date:iso2date($item/period/start/@value),xs:time('23:59:59')))
                else $item/period/end/@value/string()
            let $class := if (xs:dateTime($start) > $now)
                then 
                    switch($item/status//code/@value)
                    case 'confirmed' return 'confirmed'
                    default return 'tentative'
                else 'past'
            order by $item/period/start/@value/string()
            return
               map {
                     "resourceType" : "Event"
                   , "id" : $i
                   , "title" : $item/summary/@value/string()
                   , "period" : map {"start" : $start, "end" : $end}
                   , "rendering" : map {
                          "class" : $class
                          }
                   }
            },
            "lanes" : array {
            for $a at $i in $actors/*:user
            return
                map {
                      "id" : xs:integer($i) - 1
                    , "label" : $a//*:display/@value/string()
                }
            }
        }
        else 
        mutil:prepareResultBundleJSON($sorted-hits, 1, "*")
};

(:~
 : PUT: nonfhir/Leave
 : Update an existing leaveendar or store a new one.
 :
 : @param $content
 :)
declare function nleave:update-leave($request as map(*)){
    let $user := sm:id()//sm:real/sm:username/string()
    let $realm := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid   := $request?parameters?id
    let $content := $request?body/node()

    let $isNew   := not($content/leave/@xml:id)
    let $cid   := if ($isNew)
        then "l-" || substring-after($content/Event/actor/reference/@value,'Practitioner/')
        else
            let $id := $content/Event/id/@value/string()
            let $leaves := collection($config:leave-data)/Event[id[@value = $id]]
            let $move := mutil:moveToHistory($leaves, $config:leavehistory)
            return
                $id

    let $version := if ($isNew)
        then "0"
        else xs:integer($content/Event/meta/versionId/@value/string()) + 1
    let $elems := $content/leave/*[not(
                    self::meta
                or  self::id
                or  self::period
                )]
    let $meta := $content//meta/fhir:*[not(
                                               self::fhir:versionId
                                            or self::fhir:lastUpdated
                                            or self::fhir:extension
                                            )]
    let $period := $content//period
    let $uuid := if ($isNew)
        then $cid
        else "l-" || util:uuid()
    let $data :=
           <Event xml:id="{$uuid}">
               <id value="{$cid}"/>
               <meta>
                   <versionId value="{$version}"/>
                   <extension url="https://eNahar.org/nabu/extension/lastModifiedBy">
                       <valueReference>
                           <reference value="Practitioner/{$loguid}"/>
                           <display value="{$lognam}"/>
                       </valueReference>
                   </extension>
                   <lastUpdated value="{date:now()}"/>
               </meta>
            { $elems }
            { $period }
           </Event>

    let $lll := util:log-app('DEBUG','apps.nabu',$data)

    let $file := $uuid || ".xml"
    return
    try {
        let $store := system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:leave-data, $file, $data)
            , sm:chmod(xs:anyURI($config:leave-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:leave-data || '/' || $file), $config:data-group)))
        return
            $data
    } catch * {
        error(401, 'permission denied. Ask the admin.')
    }
};

