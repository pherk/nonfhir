xquery version "3.0";

module namespace help = "http://enahar.org/exist/apps/metis/help";


declare namespace  ev="http://www.w3.org/2001/xml-events";
declare namespace  xf="http://www.w3.org/2002/xforms";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace html="http://www.w3.org/1999/xhtml";


declare function help:showFunctions()
{
    <div>
        <h3>Hilfe:</h3>
        <ul>
            <li><a href="index.html?action=help&amp;topic=overview">Allgemein</a></li>
            <li><a href="index.html?action=help&amp;topic=bugs">Bugs, Anregungen</a></li>
        </ul>
    </div>
};

declare function help:help($topic)
{
    if ($topic='bugs') then help:bugs()
    else                    help:overview()
};

declare function help:overview()
{
    <div><h3>Allgemeines</h3>
        <p>Der <strong>apud SPZ Manager</strong> ist das Nachfolgesystem zu "Paule", gewissermaßen "Paule2".</p>
        <p>Wesentliche Funktionen von "Paule" Terminkalender, Scheinverwaltung, Leistungserfassung sind oder werden
           demnächst auf ORBIS übertragen. Der Task-Manager basiert auf einem Ticket-System mit flexibler Rollenzuordnung.
           Damit können der interne Informationsaustausch und externe Anfragen digital abgebildet und effizient erledigt werden.
           Das Ticket-System ist zur Zeit in Erprobung.</p>
        <p>In weiteren Ausbaustufen ("Roadmap") bietet das System:
           <ul>
               <li>die Rettung der Paule-Daten (Patienten, Termine, Fallführende, Adressen; Version 0.6)</li>
               <li>Medizinisch-administrative Synopsis zu Patienten (Version 0.6)</li>
               <li>Zugriff auf SPZ-Briefe (ab 2005; Version 0.7)</li>
               <li>Leitlinien-gerechte Surveillance der Patienten in den Spezialsprechstunden (z.B. Cerebralparese; Version 0.8)</li>
           </ul>
        </p>
        <div>
            <h4>Technische Hinweise</h4>
            <p>Es gibt in einem Teil der Formulare  keinen <strong>Zurück-Knopf</strong>.<br/>
               Um aus Formularen herauszugehen ohne zu speichern, gibt es zwei Möglichkeiten:<br/>
               - den <strong>Zurück-Button</strong> des Browsers oder<br/>
               - einen Link vom Dashboard (rechte Spalte) benutzen.</p>
            <p>Die <strong>Textfilter</strong> arbeiten mit <em>Reguläre Ausdrücke (regex)</em>.
                Bei einfachem Text passt das Filter auch innerhalb des Suchbegriffs;
                will man unbedingt am Anfang des Textes filtern, sollte man vorne  weg ein"^" benutzen.<br/>
                "Extrem"-Nutzer -kennen regex ohnehin ;-)-, andernfalls hilft der Link
                <a href="http://de.wikipedia.org/wiki/Regul%C3%A4rer_Ausdruck">Reguläre Ausdrücke </a>weiter.</p>
        </div>
        <p><strong>apud</strong> (lateinisch): bei, in der Nähe von, im Hause von, zitiert aus</p>
    </div>
};

declare function help:bugs()
{
    <div><h3>Probleme, Probleme</h3>
        <p>Einige bekannte Probleme:</p>
        <ul>
            <li>Kontakte: keine?</li>
        </ul>
        <p>Neue Probleme, Anregungen oder Fragen gerne an den metis-admin per Ticket ;-)</p>
    </div>
};