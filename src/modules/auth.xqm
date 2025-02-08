xquery version "3.1";

module namespace auth="https://jinntec.de/fore-exist/auth";

import module namespace config="https://jinntec.de/fore-exist/config" at 'config.xqm';
import module namespace roaster="http://e-editiones.org/roaster";

declare function auth:login(
        $request as map(*)
    ) as map(*)
{
    roaster:response( 200,
        map {
            "user": "admin",
            "groups": ["dba", "spz"],
            "dba": true,
            "domain" : "spz"
        })
};

declare function auth:logout(
        $request as map(*)
    ) as map(*)
{
    map {
            "success": true
        }
};
