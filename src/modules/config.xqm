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
declare variable $config:app-path    := '/db/apps/metis';
declare variable $config:redirectURL := concat($config:server,'/',$config:app-path,'/index.html');

(:
    Returns the configuration document for the app.
:)
declare variable $config:metis-config :=
    doc(concat($config:app-root, "/configuration.xml"))
;

(:
    The root collection to be scanned for app data.
:)
declare variable $config:metis-root := 
    let $root := $config:metis-config/configuration/root/string()
    return
        if (starts-with($root, "/db")) then
            $root
        else
            concat($config:app-root, "/", $root)
;

declare variable $config:metis-rbac          := concat($config:metis-root,'/rbac');
declare variable $config:metis-users         := concat($config:metis-root,'/users');
declare variable $config:metis-fhir          := concat($config:metis-root,'/FHIR');
declare variable $config:metis-groups        := concat($config:metis-fhir,'/Groups');
declare variable $config:metis-organizations := concat($config:metis-fhir,'/Organizations');
declare variable $config:metis-locations     := concat($config:metis-fhir,'/Locations');
declare variable $config:metis-devices       := concat($config:metis-fhir,'/Devices');
declare variable $config:metis-practitioners := concat($config:metis-fhir,'/Practitioners');
declare variable $config:metis-persons       := concat($config:metis-fhir,'/Persons');
declare variable $config:metis-hcs           := concat($config:metis-fhir,'/HealthcareServices');
declare variable $config:metis-leaves        := concat($config:metis-fhir,'/Leaves');
declare variable $config:metis-fhir-data     := "/db/apps/metisData/data/FHIR";
declare variable $config:metis-nonfhir-data  := "/db/apps/metisData/data/NonFHIR";
declare variable $config:metis-history-data  := "/db/apps/metisHistory/data";
declare variable $config:metis-device-data   := concat($config:metis-fhir-data,'/Devices');
declare variable $config:metis-deviceHistory := concat($config:metis-history-data,'/Device');
declare variable $config:metis-group-data    := concat($config:metis-fhir-data,'/Groups');
declare variable $config:metis-groupHistory  := concat($config:metis-history-data,'/Group');
declare variable $config:metis-hcs-data      := concat($config:metis-fhir-data,'/HealthcareServices');
declare variable $config:metis-hcsHistory    := concat($config:metis-history-data,'/HealthcareService');
declare variable $config:metis-location-data := concat($config:metis-fhir-data,'/Locations');
declare variable $config:metis-locationHistory := concat($config:metis-history-data,'/Location');
declare variable $config:metis-leave-data    := concat($config:metis-nonfhir-data,'/Leaves');
declare variable $config:metis-leaveHistory  := concat($config:metis-history-data,'/Leave');
declare variable $config:metis-organization-data := concat($config:metis-fhir-data,'/Organizations');
declare variable $config:metis-organizationHistory := concat($config:metis-history-data,'/Organization');
declare variable $config:metis-pract-data    := concat($config:metis-fhir-data,'/Practitioners');
declare variable $config:metis-practHistory  := concat($config:metis-history-data,'/Practitioner');
declare variable $config:metis-practrole-data := concat($config:metis-fhir-data,'/PractitionerRoles');
declare variable $config:metis-practroleHistory := concat($config:metis-history-data,'/Practitioner');

declare variable $config:metis-resources := concat($config:metis-root,'/resources');
declare variable $config:metis-templs    := concat($config:metis-root,'/templates');
declare variable $config:metis-data-collections :=
    (   '/resources'
    ,   '/templates'
    );
    
declare variable $config:items-per-page := 
    let $itemsPerPage := $config:metis-config/configuration/items-per-page/string()
    return
        if ($itemsPerPage) then
            xs:int($itemsPerPage)
        else
            10
;

declare variable $config:default-agent :=
    $config:metis-config/configuration/agent/@default/string()
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
