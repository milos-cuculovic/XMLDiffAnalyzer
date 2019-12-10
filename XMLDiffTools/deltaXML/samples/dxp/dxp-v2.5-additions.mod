<!ENTITY % cdataName "CDATA" >
<!ENTITY % retainWithModes "(retain,processingMode?,outputType?)" >

<!ELEMENT lexicalPreservation (defaults, overrides?)>
<!ELEMENT defaults %retainWithModes;>

<!ELEMENT retain EMPTY>
<!ATTLIST retain
          literalValue (true|false) #IMPLIED
          parameterRef CDATA #IMPLIED 
          xpath CDATA #IMPLIED>
          
<!ELEMENT processingMode EMPTY>
<!ATTLIST processingMode
          literalValue (useDefault|A|AB|AdB|B|BA|BdA|change) #IMPLIED
          parameterRef CDATA #IMPLIED 
          xpath CDATA #IMPLIED>
          
<!ELEMENT outputType EMPTY>
<!ATTLIST outputType
          literalValue (useDefault|encoded|normal) #IMPLIED
          parameterRef CDATA #IMPLIED 
          xpath CDATA #IMPLIED>
          
<!ELEMENT overrides (preserveItems?,outerPiAndCommentProcessingMode?,advancedEntityReferenceUsage?)>
<!ELEMENT preserveItems (%cdataName;?,comments?,contentModel?,defaultAttributeInfo?,doctype?,documentLocation?,entityReferences?,entityReplacementText?,
                        ignorableWhitespace?,nestedEntityReferences?,processingInstructions?,XMLDeclaration?)>
                        
<!ELEMENT %cdataName; %retainWithModes;>
<!ELEMENT comments %retainWithModes;>
<!ELEMENT defaultAttributeInfo %retainWithModes;>
<!ELEMENT documentLocation %retainWithModes;>
<!ELEMENT entityReferences %retainWithModes;>
<!ELEMENT doctype %retainWithModes;>
<!ELEMENT entityReplacementText (retain)>
<!ELEMENT contentModel %retainWithModes;>
<!ELEMENT ignorableWhitespace %retainWithModes;>
<!ELEMENT nestedEntityReferences (retain)>
<!ELEMENT processingInstructions %retainWithModes;>
<!ELEMENT XMLDeclaration %retainWithModes;>

<!ELEMENT outerPiAndCommentProcessingMode (processingMode)>
<!ELEMENT advancedEntityReferenceUsage EMPTY>
<!ATTLIST advancedEntityReferenceUsage
          literalValue (useDefault|change|replace|split) #IMPLIED
          parameterRef CDATA #IMPLIED 
          xpath CDATA #IMPLIED>