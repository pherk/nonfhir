xquery version "3.1";

module namespace nschedule="http://eNahar.org/ns/nonfhir/nschedule";

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";

declare namespace fhir   = "http://hl7.org/fhir";

declare variable $nschedule:data-perms := "rwxrwxr-x";
declare variable $nschedule:data-group := "spz";
declare variable $nschedule:perms      := "rwxr-xr-x";

declare variable $nschedule:history    := "/db/apps/eNaharHistory/data/Cals";
declare variable $nschedule:schedule-base := "/db/apps/eNaharData/data/schedules";

declare function nschedule:update-schedule($request as map(*)){
    let $user := sm:id()//sm:real/sm:username/string()
    let $collection := $request?parameters?collection
    let $payload := $request?body/node()
    (: let $stored := xmldb:store($config:page-root, $user || '-todos.xml' , $payload) :)
    return <stored>{$stored}</stored>
};

(:~
 : GET: enahar/schedules/{uuid}
 : get cal by id
 : 
 : @param $id  uuid
 : 
 : @return <cal/>
 :)
declare function nschedule:read-schedule($request as map(*)) as item()
{
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid   := $request?parameters?id
    let $schedules := collection($nschedule:schedule-base)/cal[id[@value=$uuid]]
    return
        if (count($schedules)=1)
        then $schedules
        else  error(404, 'schedules: uuid not valid.')
};

(:~
 : GET: enahar/schedule?query
 : get schedules
 :
 : @param $type   string
 : @param $name   string
 : @param $active  boolean
 : @return bundle of <cal/>
 :)
declare function nschedule:search-schedule($request as map(*)){
    let $user   := sm:id()//sm:real/sm:username/string()
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $elems  := $request?parameters?_elements
    let $type   := $request?parameters?type
    let $name   := $request?parameters?name
    let $active := $request?parameters?active
    let $lll := util:log-app('ERROR','exist-core', $request?parameters)
    let $hits0 := if ($type and $type!='')
        then collection($nschedule:schedule-base)/schedule[type[@value=$type]][active[@value=$active]]
        else collection($nschedule:schedule-base)/schedule[active[@value="true"]]
    let $valid := if ($name)
        then $hits0
        else $hits0/schedule[matches(name/@value,$name)]

    let $sorted-hits :=
        for $c in $hits0
        order by lower-case($c/name/@value/string())
        return
            if (string-length($elems)>0)
            then
                <Schedule>
                    {$c/id}
                    {$c/type}
                    {$c/name}
                    {$c/ff}
                </Schedule>
            else $c
    return
        mutil:prepareResourceBundleXML($sorted-hits, 1, "*")
};
