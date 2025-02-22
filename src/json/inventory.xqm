xquery version "3.1";


(:~
: Defines all the XSD related stuff, FHIR 3.0.1 and 4.3 (current)
: @author Peter Herkenrathi
: @version 1.1
: @see http://enahar.org
:
:)
module namespace inventory = "http://enahar.org/exist/apps/nabu/inventory";

declare variable $inventory:baseComplexTypes :=
    (
          'Extension'
        , "BackboneElement"
        , "Narrative"
        , "Element"
        , "Reference", "CodeableReference"
        , "Quantity"
        , "Period"
        , "Attachment"
        , 'Duration'
        , 'Count'
        , "Range"
        , "Annotation"
        , 'Money'
        , "Identifier"
        , "Coding"
        , "Signature"
        , "SampledData"
        , "Ratio", "RatioRange"
        , 'Distance'
        , 'Age'
        , "CodeableConcept"
        , "Meta"
        , "Address"
        , "TriggerDefinition"
        , "Contributor"
        , "DataRequirement"
        , "DataRequirement.CodeFilter"
        , "DataRequirement.DateFilter"
        , 'DataRequirement.Sort'
        , 'SortDirection'
        , "Dosage"
        , "RelatedArtifact"
        , "ContactDetail"
        , "HumanName"
        , "ContactPoint"
        , 'Expression'
        , 'ExpressionLanguage'
        , "UsageContext"
        , "Timing"
        , "Timing.Repeat"
        , "ElementDefinition"
        , "ElementDefinition.Constraint"
        , "ElementDefinition.Mapping"
        , "ElementDefinition.Base"
        , "ElementDefinition.Type"
        , "ElementDefinition.Example"
        , "ElementDefinition.Slicing"
        , "ElementDefinition.Binding"
        , "ElementDefinition.Discriminator"
        , "ParameterDefinition"
    );
declare variable $inventory:primitive :=
    (
          'decimal'
        , 'integer', 'unsignedInt', 'positiveInt', 'integer64'
        , 'boolean'
        , 'instant', 'date', 'time', 'dateTime'
        , 'base64Binary'
        , 'string', 'code', 'id', 'markdown'
        , 'uri', 'url', 'oid', 'canonical', 'uuid'
        , 'xhtml:div'
    );
declare variable $inventory:enum :=
    (
          "AddressType"
        , "AddressUse"
        , 'AdministrativeGender'
        , "AggregationMode"
        , "BindingStrength"
        , "ConceptMapEquivalence"
        , "ConstraintSeverity"
        , "ContactPointSystem"
        , "ContactPointUse"
        , "ContributorType"
        , "DiscriminatorType"
        , "DocumentReferenceStatus"
        , "EventTiming"
        , "IdentifierUse"
        , "NameUse"
        , 'NarrativeStatus'
        , "NoteType"
        , "PropertyRepresentation"
        , "PublicationStatus"
        , 'QuantityComparator'
        , "ReferenceVersionRules"
        , "RelatedArtifactType"
        , "RemittanceOutcome"
        , "SampledDataDataType"
        , "SearchParamType"
        , "SlicingRules"
        , "TriggerType"
        , "UnitsOfTime"
        , "BundleType"
        , "SearchEntryMode"
    );
    
declare variable $inventory:complex := 
    (
          'Address'
        , 'Annotation'
        , 'Attachment'
        , 'Coding'
        , 'CodeableConcept'
        , 'ContactPoint'
        , 'HumanName'
        , 'Identifier'
        , 'Money'
        , 'Period'
        , 'Quantity', 'MoneyQuantity', 'SimpleQuantity', 'Age', 'Distance', 'Count'
        , 'Range', 'Ratio', 'RatioRange'
        , 'SampledData'
        , 'Signature'
        , 'Timing'
        , 'meta'
    );
declare variable $inventory:complexMeta := 
    (
          'ContactDetail'
        , 'Contributor'
        , 'DataRequirement'
        , 'ParameterDefinition'
        , 'RelatedArtifact'
        , 'TriggerDefinition'
        , 'UsageContext'
        , 'ExtendedContactDetail'
        , 'Availability'
        , 'Expression'
        , 'MonetaryComponent'
        , 'VirtualServiceDetail'
    );
declare variable $inventory:special := ('CodeableReference', 'Reference', 'Narrative', 'Extension', 'Meta', 'Dosage');
declare variable $inventory:valueSet := 
    (     'AdministrativeGender'
        , 'CarePlanActivityKind'
        , 'CarePlanActivityStatus'
        , 'CarePlanIntent'
        , 'CareTeamStatus'
        , 'CompositionAttestationMode'
        , 'CompositionStatus'
        , 'Confidentiality'
        , 'ConsentDataMeaning'
        , 'ConsentProvisionType'
        , 'ConsentState'
        , 'DocumentRelationshipType'
        , 'EncounterLocationStatus'
        , 'EncounterStatus'
        , 'EpisodeOfCareStatus'
        , 'EventStatus'
        , 'GoalLifecycleStatus'
        , 'LinkType'
        , 'ListMode'
        , 'RequestPriority'
        , 'RequestStatus'
        , 'TaskIntent'
        , 'TaskStatus'
    );
(:~
 : baseInfo
 : 
 : 
 : @since 0.8.13
 : @return info item()?
 :)
declare function inventory:baseInfo(
        $fhir_version
    ) as element(base)
{
    let $inventory:base := doc('/db/apps/nabu/FHIR-XSD-' || $fhir_version || '/fhir-base.xsd')
    let $xsd-complex  := $inventory:base/xs:schema/xs:complexType[not(@name=$inventory:primitive)]
    let $simple := for $e in $inventory:primitive
            return
                <simple name='{$e}' class='primitive'/>
    let $complex := for $c in $xsd-complex
            let $cont := $c/xs:complexContent/xs:extension[@base='Element']
            return
                if ($cont/xs:sequence)
                then
                    inventory:sequence($c/@name/string(), $cont)
                else if ($cont/xs:attribute and $cont/xs:attribute/@name='value')
                then <simple name='{$c/@name/string()}' class="enum"/>
                else if ($c/xs:complexContent/xs:extension/@base=('Quantity','Resource'))
                then ()
                else  <error name="{$c/@name/string()}"/>
    return
        <base>
            {$simple}
            {$complex}
        </base>
};

declare %private function inventory:sequence(
      $name as xs:string
    , $c
    ) as element(complex)
{
    let $xsd-seqchilds := $c/xs:sequence/xs:element |
                          $c/xs:sequence/xs:choice                (: some elements are child of xs:choice :)
    let $xsd-seqattrs := $c/xs:attribute
            return
                (: extension can occur in every element :)
                <complex name="{$name}">
                    <element name="extension" type="Extension" req="false" array="true" sub="false" class="special"/>
                { for $e in $xsd-seqchilds
                    return
                        if (local-name($e)='element')
                        then inventory:element($e, ())
                        else if (local-name($e)='choice')
                        then inventory:choice($e)
                        else <error/>
                }
                {
                    <attribute name="id" type="string" req="optional"/>
                ,   for $a in $xsd-seqattrs
                    return
                        inventory:attribute($a)
                }
                </complex>
};

declare %private function inventory:element(
          $e as element(xs:element)
        , $domain as xs:string*) as element(element)
{
(:
let $lll := util:log-app('TRACE','apps.nabu',$e)
let $lll := util:log-app('TRACE','apps.nabu',$domain)
:)
    let $name  := ($e/@name/string(),$e/@ref/string())[1]
    let $req   := $e/@minOccurs>0
    let $array := $e/@maxOccurs='unbounded' or $e/@maxOccurs > '1'
    let $type  := ($e/@type/string(),$e/@ref/string())[1]
    let $isSub := $domain and contains($type,'.') (: only types with '.' are a backBone element :)
    let $class := if ($isSub)
        then 'isSub'
        else inventory:baseTypeclass($type)
    return
        <element name="{$name}" type="{$type}" req="{$req}" array="{$array}" sub="{$isSub}" class="{$class}"/>
};

declare function inventory:choice($c as element(xs:choice)) as element(element)*
{
(: 
let $lll := util:log-app('TRACE','apps.nabu',$c)
:)
    let $req   := $c/@minOccurs>0
    let $array := $c/@maxOccurs='unbounded' or $c/@maxOccurs>'1'
    for $elem in $c/xs:element
    let $name  := $elem/@name/string()
    let $type  := $elem/@type/string()
    let $class := inventory:baseTypeclass($type)
    return
        <element name="{$name}" type="{$type}" req="{$req}" array="{$array}" sub="false" class="{$class}"/>
};

declare %private function inventory:attribute($a) as element(attribute)
{
    let $name  := $a/@name/string()
    let $req   := $a/@use='required'
    let $type  := $a/@type/string()
    return
        <attribute name="{$name}" type="{$type}" req="{$req}"/>
};

declare function inventory:baseTypeclass($type) as xs:string
{
    if ($type=$inventory:baseComplexTypes)
    then 'complex'
    else if (inventory:isPrimitive($type))
    then 'primitive'
    else if ($type='ResourceContainer')
    then 'resource-container'
    else if (inventory:isCodeValue($type))
    then 'pseudo-primitive'
    else let $lll := util:log-app('DEBUG','apps.nabu', $type)
         return 'debug'
        (: error(QName('http://eNahar.org/exist/apps/nabu/inventory','FHIR-Base'), concat('unclassified basetype: ', $type)) :)
};

(:~
 : domainInfo
 : 
 : @param domain string
 : 
 : @since 0.8.13
 : @return info item()?
 :)
declare function inventory:domainInfo(
      $domain as xs:string
    , $fhir_version as xs:string
    ) as element(domain)
{
    let $inventory:xsd := collection('/db/apps/nabu/FHIR-XSD-' || $fhir_version)

    let $xsd-domain := $inventory:xsd/xs:schema/xs:complexType[@name=$domain]/xs:complexContent/xs:extension[@base=('DomainResource','BackboneElement','Resource')]
    let $xsd-elems  := $xsd-domain/xs:sequence/xs:element |
                        $xsd-domain/xs:sequence/xs:choice    (: some elements are child of xs:choice :)
    let $infos := for $e in $xsd-elems
            return
                if (local-name($e)='element')
                then inventory:element($e, $domain)
                else if (local-name($e)='choice') (: flattening choice :)
                then inventory:choice($e)
                else <error>should element or choice</error>
    return
        <domain name="{$domain}">
        {   if (contains($domain,'.'))
            then ()
            else
                (
                    <element name="id" type="oid" req="false" array="false" sub="false" class="primitive"/>
                ,   <element name="meta" type="Meta" req="false" array="false" sub="false" class="complex"/>
                ,   <element name="text" type="Narrative" req="false" array="false" sub="false" class="special"/>
                ,   <element name="implicitRules" type="uri" req="false" array="false" sub="false" class="primitive"/>
                ,   <element name="language" type="code" req="false" array="false" sub="false" class="primitive"/>
                )
        }
            <element name="extension" type="Extension" req="false" array="true" sub="false" class="special"/>
            {$infos}
        </domain>
};

(:~
 : datatypeInfo
 : 
 : @param resource string
 : @param property string
 : 
 : @since 0.8.13
 : @return info item()?
 :)
declare function inventory:datatypeInfo(
      $datatype as xs:string
    , $property as xs:string*
    , $fhir_version as xs:string
    ) as item()*
{
    let $inventory:xsd := collection('/db/apps/nabu/FHIR-XSD-' || $fhir_version)
    let $xsd-domain := $inventory:xsd/xs:schema/xs:complexType[@name=$datatype]/xs:complexContent/xs:extension[@base='Element']
    let $xsd-attribute := $xsd-domain/xs:attribute
    let $class := inventory:typeclass($datatype)
let $lll := util:log-app('TRACE','apps.nabu',$xsd-domain)
    return
        switch($class)
        case 'primitive' return
            let $type  := $xsd-attribute/@type/string()
            return
                ($class, $type)
        case 'complex' return
            let $els := $xsd-domain/xs:sequence/xs:element
            return
            ('complex', count($els), $els/@name/string())
        case 'meta' return
            ('meta')
        case 'special' return
            ('special')
        default return ()
};

(:~
 : propertyInfo
 : 
 : @param resource string
 : @param property string
 : 
 : @since 0.8.13
 : @return info item()?
 :)
declare function inventory:propertyInfo(
      $domain as xs:string
    , $property as xs:string
    ) as item()*
{
    let $xsd-domain := $inventory:xsd/xs:schema/xs:complexType[@name=$domain]/xs:complexContent/xs:extension[@base=('DomainResource','BackboneElement')]
    let $xsd-element := $xsd-domain/xs:sequence/xs:element[@name=$property]
let $lll := util:log-app('TRACE','apps.nabu',$xsd-element)
    let $req   := $xsd-element/@minOccurs>0
    let $array := $xsd-element/@maxOccurs='unbounded' or $xsd-element/@maxOccurs > '1'
    let $type  := $xsd-element/@type/string()
    let $sub   := starts-with($xsd-element/@type, $domain)
    let $class := if ($sub)
        then 'backbone'
        else inventory:typeclass($type)
    return
        ($type, $req, $array, $sub, $class)
};

(:~
 : typeclass
 : 
 : FHIR resources group into several typeclasses
 : 1. Simple / primitive types, which are single elements with a primitive value
 : 2. General purpose complex types, which are re-usable clusters of elements
 : 3. Complex data types for metadata
 : 4. Special purpose data types: Reference, Narrative, Extension, Meta, and Dosage

 : @since 0.8.13
 : @return xs:string
 :)
declare function inventory:typeclass(
      $xsd-type as xs:string
    ) as xs:string
{
    if (inventory:isPrimitive($xsd-type))
    then 'primitive'
    else if (inventory:isSpecial($xsd-type))
    then 'special'
    else if (inventory:isComplex($xsd-type))
    then 'complex'
    else if (inventory:isComplexMeta($xsd-type))
    then 'meta'
    else error(QName('http://eNahar.org/exist/apps/nabu/inventory','FHIR-Base'), concat('unclassified typeclass: ', $xsd-type))
};

declare %private function inventory:isPrimitive(
      $xsd-type as xs:string
    ) as xs:boolean
{
    $xsd-type = ($inventory:primitive, $inventory:enum)
};

declare %private function inventory:isComplex(
      $xsd-type as xs:string
    ) as xs:boolean
{
    $xsd-type = ($inventory:complex, $inventory:baseComplexTypes)
};

declare %private function inventory:isComplexMeta(
      $xsd-type as xs:string
    ) as xs:boolean
{
    $xsd-type = $inventory:complexMeta
};

declare %private function inventory:isSpecial(
      $xsd-type as xs:string
    ) as xs:boolean
{
    $xsd-type = $inventory:special
};

declare %private function inventory:isCodeValue(
      $xsd-type as xs:string
    ) as xs:boolean
{
    (: $xsd-type = $inventory:valueSet :)
    true()
};
