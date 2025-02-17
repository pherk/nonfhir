xquery version "3.0";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace config="http://eNahar.org/ns/nonfhir/config";

declare namespace templates="http://exist-db.org/xquery/html-templating";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

declare variable $config:default-user  := ("spz", "spz5900");
declare variable $config:default-group := "spz";
declare variable $config:admin-user    := "enahar-admin";
declare variable $config:admin-group   := "enahar-admin";
declare variable $config:data-perms    := "rwxrw-r--";
declare variable $config:data-group    := $config:default-group;
(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;

(: 
 : returns the server
 :)
declare variable $config:server      := concat('http://', request:get-header('host'));
declare variable $config:app-path    := '/db/apps/nonfhir';
declare variable $config:redirectURL := concat($config:server,'/',$config:app-path,'/index.html');

(:
    Returns the configuration document for the app.
:)
declare variable $config:config :=
    doc(concat($config:app-root, "/configuration.xml"))
;

(:
    The root collection to be scanned for app data.
:)
declare variable $config:root := 
    let $root := $config:config/configuration/root/string()
    return
        if (starts-with($root, "/db")) then
            $root
        else
            concat($config:app-root, "/", $root)
;

declare variable $config:fhir-data     := "/db/apps/metisData/data/FHIR";
declare variable $config:nonfhir-data  := "/db/apps/metisData/data/NonFHIR";
declare variable $config:history-data  := "/db/apps/metisHistory/data";
declare variable $config:holiday-data    := concat($config:nonfhir-data,'/Holiday');
declare variable $config:holidayHistory  := concat($config:history-data,'/Holiday');
declare variable $config:leave-data    := concat($config:nonfhir-data,'/Leave');
declare variable $config:leaveHistory  := concat($config:history-data,'/Leave');
declare variable $config:ical-data    := concat($config:nonfhir-data,'/ICal');
declare variable $config:icalHistory  := concat($config:history-data,'/ICal');

declare variable $config:resources := concat($config:root,'/resources');
declare variable $config:templs    := concat($config:root,'/templates');
declare variable $config:data-collections :=
    (   '/resources'
    ,   '/templates'
    );
    
declare variable $config:items-per-page := 
    let $itemsPerPage := $config:config/configuration/items-per-page/string()
    return
        if ($itemsPerPage) then
            xs:int($itemsPerPage)
        else
            10
;

declare variable $config:default-agent :=
    $config:config/configuration/agent/@default/string()
;


declare variable $config:repo-descriptor := doc(concat($config:app-root, "/repo.xml"))/repo:meta;

declare variable $config:expath-descriptor := doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package;

(:~
 : Resolve the given path using the current application context.
 : If the app resides in the file system,
 :)
declare function config:resolve($relPath as xs:string) {
    if (starts-with($config:app-root, "/db")) then
        doc(concat($config:app-root, "/", $relPath))
    else
        doc(concat("file://", $config:app-root, "/", $relPath))
};

(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare function config:expath-descriptor() as element(expath:package) {
    $config:expath-descriptor
};

declare %templates:wrap function config:app-title($node as node(), $model as map(*)) as text() {
    $config:expath-descriptor/expath:title/text()
};

declare function config:app-meta($node as node(), $model as map(*)) as element()* {
    <meta xmlns="http://www.w3.org/1999/xhtml" name="description" content="{$config:repo-descriptor/repo:description/text()}"/>,
    for $author in $config:repo-descriptor/repo:author
    return
        <meta xmlns="http://www.w3.org/1999/xhtml" name="creator" content="{$author/text()}"/>
};

(:~
 : For debugging: generates a table showing all properties defined
 : in the application descriptors.
 :)
declare function config:app-info($node as node(), $model as map(*)) {
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return
        <table class="app-info">
            <tr>
                <td>app collection:</td>
                <td>{$config:app-root}</td>
            </tr>
            {
                for $attr in ($expath/@*, $expath/*, $repo/*)
                return
                    <tr>
                        <td>{node-name($attr)}:</td>
                        <td>{$attr/string()}</td>
                    </tr>
            }
            <tr>
                <td>Controller:</td>
                <td>{ request:get-attribute("$exist:controller") }</td>
            </tr>
        </table>
};
