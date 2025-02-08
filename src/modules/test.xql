xquery version "3.0";

import module namespace xmldb    = "http://exist-db.org/xquery/xmldb";
import module namespace util     = "http://exist-db.org/xquery/util";
import module namespace request  = "http://exist-db.org/xquery/request";
import module namespace response = "http://exist-db.org/xquery/response";

import module namespace config = "http://enahar.org/exist/apps/metis/config" at "../modules/config.xqm";
import module namespace user   = "http://enahar.org/exist/apps/metis/user"    at "../user/user.xqm";
import module namespace r-user = "http://enahar.org/exist/restxq/metis/users" at "../user/user-routes.xqm";
import module namespace r-practitioner = "http://enahar.org/exist/restxq/metis/practitioners"  at "../Practitioner/practitioner-routes.xqm";
import module namespace r-group = "http://enahar.org/exist/restxq/metis/groups"  at "../Group/group-routes.xqm";
import module namespace tei2fo = "http://eNahar.org/ns/lib/tei2fo";

(: provides highest, lowest, sort :)
import module namespace xxpath = "http://eNahar.org/ns/lib/xxpath";

declare namespace rest="http://exquery.org/ns/restxq";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare namespace fo="http://www.w3.org/1999/XSL/Format";
declare namespace xslfo="http://exist-db.org/xquery/xslfo";
declare namespace tei="http://www.tei-c.org/ns/1.0";
declare namespace fhir   = "http://hl7.org/fhir";

let $p := collection($config:metis-practitioners)
return
    util:index-keys($p/fhir:Practitioner/fhir:name/fhir:family/@value, "Ab", 
        function($key, $count) {
            <term name="{$key}" count="{$count[1]}"
                docs="{$count[2]}"/>
        }, -1, "range-index")
