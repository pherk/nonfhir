xquery version "3.1";

module namespace nbase ="http://eNahar.org/ns/nonfhir/nbase";

import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";

import module namespace config="http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';
import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace date  ="http://eNahar.org/ns/lib/date";

declare namespace fhir   = "http://hl7.org/fhir";

(:~
 : GET: nonfhir/metadata
 : get Capabilities
 : 
 : 
 : @return <Capabilitities/>
 :)
declare function nbase:metadata($request as map(*)) as item()
{
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    return
      <Capabilities>
      </Capabilities>
};

(:~
 : GET: nonfhir/health
 : get health
 : 
 : 
 : @return <ok/>
 :)
declare function nbase:health($request as map(*)) as item()
{
    let $realm  := $request?parameters?realm
    let $loguid := $request?parameters?loguid
    let $lognam := $request?parameters?lognam
    return
      <ok/>
};

