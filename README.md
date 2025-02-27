# New NonFHIR server components for eXist-db

Instructions and documentation on its use is given in the app itself.

## Building

You should have a npm installation at hand.

After cloning run:

```
npm install
```

To build the app:

```
gulp xar
```

To install the xar in eXist-db:

```
gulp install
```

## Indexing

<collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns:fhir="http://hl7.org/fhir" xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <range><!-- nonFHIR objects -->
            <create qname="id">
                <field name="id" match="@value" type="xs:string"/>
            </create>
            <create qname="code">
                <field name="code" match="@value" type="xs:string"/>
            </create>
            <create qname="reference">
                <field name="reference" match="@value" type="xs:string"/>
            </create>
        </range>
    </index>
</collection>

## LOC
