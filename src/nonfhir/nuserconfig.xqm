xquery version "3.1";

module namespace nuc ="http://eNahar.org/ns/nonfhir/nuserconfig";

import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config="http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';
(:
import module namespace parse = "http://enahar.org/exist/apps/nabu/parse" at "../../FHIR/meta/parse-fhir-resources.xqm";
:)
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace date  ="http://eNahar.org/ns/lib/date";

declare namespace fhir   = "http://hl7.org/fhir";

(:~
 : GET: /UserConfig/{uuuid}
 : get user configuration
 : 
 : 
 : @return <UserConfig/>
 :)
declare function nuc:read-userconfig($request as map(*)) as item()
{
    let $accept := $request?accept
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    let $uuid := $request?parameters?uuid
    let $ucs := collection($config:userconfig-data)/UserConfig[id/@value=$uuid]
    return
      if (count($ucs)=1) then
        switch ($accept)
        case "application/xml" return $ucs
        case "application/json" return mutil:resource2json($ucs)
        default return error($errors:UNSUPPORTED_MEDIA_TYPE, "Accept: ", map { "info": "only xml and json allowed"})
      else error($errors:NOT_FOUND, "nuserconfig: ", map { "info": "invalid uuuid"})
};


