xquery version "3.1";

module namespace ncevent ="http://eNahar.org/ns/nonfhir/ncevent";

import module namespace mutil  = "http://eNahar.org/ns/nonfhir/util" at "../modules/mutils.xqm";
import module namespace config="http://eNahar.org/ns/nonfhir/config" at '../modules/config.xqm';

import module namespace roaster="http://e-editiones.org/roaster";
import module namespace errors="http://e-editiones.org/roaster/errors";
import module namespace date  ="http://eNahar.org/ns/lib/date";

declare namespace fhir   = "http://hl7.org/fhir";
 
