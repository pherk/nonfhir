(:~
 : This is the main XQuery which will (by default) be called by controller.xql
 : to process any URI ending with ".html". It receives the HTML from
 : the controller and passes it to the templating system.
 :)
xquery version "3.1";

import module namespace templates="http://exist-db.org/xquery/html-templating";  (: at "templates.xql"; :)

(: 
 : The following modules provide functions which will be called by the 
 : templating.
 :)
import module namespace config ="http://enahar.org/exist/apps/metis/config" at "config.xqm";
import module namespace app    ="http://enahar.org/exist/apps/metis" at "app.xql";

(: 
declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html5";
declare option output:media-type "text/html";

declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=yes indent=yes";
:)
declare option exist:serialize "method=xhtml media-type=text/html omit-xml-declaration=no indent=yes 
        doctype-public=-//W3C//DTD&#160;XHTML&#160;1.0&#160;Transitional//EN
        doctype-system=http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd";

let $config := map {
    $templates:CONFIG_APP_ROOT : $config:app-root,
    $templates:CONFIG_STOP_ON_ERROR : true()
}
(:
 : We have to provide a lookup function to templates:apply to help it
 : find functions in the imported application modules. The templates
 : module cannot see the application modules, but the inline function
 : below does see them.
 :)
let $lookup := function($functionName as xs:string, $arity as xs:int) {
    try {
        function-lookup(xs:QName($functionName), $arity)
    } catch * {
        ()
    }
}
(:
 : The HTML is passed in the request from the controller.
 : Run it through the templating system and return the result.
 :)
let $content := request:get-data()
return
    templates:apply($content, $lookup, (), $config)
