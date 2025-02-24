xquery version "3.0";

import module namespace config = "http://eNahar.org/ns/nonfhir/config"     at "../modules/config.xqm";
import module namespace leavemigr = "http://eNahar.org/ns/nonfhir/leave-migration"     at "leavemigr.xqm";

declare namespace rest   = "http://exquery.org/ns/restxq";
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fhir   = "http://hl7.org/fhir";

let $ec := collection('/db/apps/metisData/data/FHIR/Leaves')
let $es := $ec/leave

let $realm := 'kikl-spz'

for $o in $es
return
    let $data := leavemigr:update-2.0($o)
    let $file := $data/@xml:id/string() || ".xml"
    return
        system:as-user('vdba', 'kikl823!', (
            xmldb:store($config:leave-data, $file, $data)
            , sm:chmod(xs:anyURI($config:leave-data || '/' || $file), $config:data-perms)
            , sm:chgrp(xs:anyURI($config:leave-data || '/' || $file), $config:data-group)))