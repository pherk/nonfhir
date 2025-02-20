xquery version "3.0";
import module namespace config = "http://eNahar.org/ns/nonfhir/config"     at "../modules/config.xqm";
import module namespace calmigr = "http://eNahar.org/ns/nonfhir/cal-migration"     at "calmigr.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/eNaharData/data/schedules')
let $es := $ec/schedule

let $realm := 'kikl-spz'

for $o in $es
return
    let $data := calmigr:update-2.0($o)
    let $file := $data/@xml:id/string() || ".xml"
    let $cudir:= switch($data/cutype//code/@value)
        case 'individual' return 'Individual'
        case 'room'   return 'Room'
        case 'role'   return 'Role'
        case 'schedule' return 'Schedule'
        default return error('invalid cutype')
    let $ical-data := "/db/apps/icalData/data"
    return
        system:as-user('vdba', 'kikl823!', (
            xmldb:store($ical-data || '/' || $cudir  , $file, $data)
            , sm:chmod(xs:anyURI($ical-data || '/' || $cudir || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($ical-data || '/' || $cudir || '/' || $file), $config:data-group)))