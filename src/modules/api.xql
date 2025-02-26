xquery version "3.1";

declare namespace api="http://eNahar.org/ns/nonfhir/api";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

import module namespace roaster="http://e-editiones.org/roaster";

import module namespace rutil="http://e-editiones.org/roaster/util";
import module namespace errors="http://e-editiones.org/roaster/errors";
(:
import module namespace auth="http://e-editiones.org/roaster/auth";
:)
import module namespace router="http://e-editiones.org/roaster/router";


(:
 : no authorization
import module namespace nauth = "https://eNahar.org/ns/nonfhir/nauth" at "nauth.xqm";
:)
import module namespace nbase    = "http://eNahar.org/ns/nonfhir/nbase"  at "../nonfhir/nbase.xqm";
import module namespace nevent   = "http://eNahar.org/ns/nonfhir/nevent" at "../nonfhir/nevent.xqm";
import module namespace nholiday = "http://eNahar.org/ns/nonfhir/nholiday" at "../nonfhir/nholiday.xqm";
import module namespace nical    = "http://eNahar.org/ns/nonfhir/nical" at "../nonfhir/nical.xqm";
import module namespace nleave   = "http://eNahar.org/ns/nonfhir/nleave" at "../nonfhir/nleave.xqm";
import module namespace nuserconfig = "http://eNahar.org/ns/nonfhir/nuserconfig" at "../nonfhir/nuserconfig.xqm";
import module namespace nerror   = "http://eNahar.org/ns/nonfhir/nerror" at "../nonfhir/nerror.xqm";
import module namespace nreport  = "http://eNahar.org/ns/nonfhir/nreport" at "../nonfhir/nreport.xqm";


(:~
 : list of definition files to use
 :)
declare variable $api:definitions := ("api.json");


(:~
 : You can add application specific route handlers here.
 : Having them in imported modules is preferred.
 :)

declare function api:date($request as map(*)) {
    $request?parameters?date instance of xs:date and
    $request?parameters?dateTime instance of xs:dateTime
};

(:~
 : An example how to throw a dynamic custom error (error:NOT_FOUND_404)
 : This error is handled in the router
 :)
declare function api:error-triggered($request as map(*)) {
    error($errors:NOT_FOUND, "document not found", "error details")
};

(:~
 : calling this function will throw dynamic XQuery error (err:XPST0003)
 :)
declare function api:error-dynamic($request as map(*)) {
    util:eval('1 + $undefined')
};

(:~
 : Handlers can also respond with an error directly 
 :)
declare function api:error-explicit($request as map(*)) {
    roaster:response(403, "application/xml", <forbidden/>)
};

(:~
 : This is used as an error-handler in the API definition 
 :)
declare function api:handle-error($error as map(*)) as element(html) {
    <html>
        <body>
            <h1>Error [{$error?code}]</h1>
            <p>{
                if (map:contains($error, "module"))
                then ``[An error occurred in `{$error?module}` at line `{$error?line}`, column `{$error?column}`]``
                else "An error occurred!"
            }</p>
            <h2>Description</h2>
            <p>{$error?description}</p>
        </body>
    </html>
};

(: end of route handlers :)

(:~
 : This function "knows" all modules and their functions
 : that are imported here 
 : You can leave it as it is, but it has to be here
 :)
declare function api:lookup ($name as xs:string) {
    function-lookup(xs:QName($name), 1)
};

declare function api:id($request, $response) {
    $request,
    $response
};
(: to switch out default auth :)
roaster:route($api:definitions, api:lookup#1, api:id#2)
