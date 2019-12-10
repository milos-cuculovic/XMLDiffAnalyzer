<!ELEMENT comparatorPipeline (fullDescription?, pipelineParameters?, 
                              (inputFilters | (input1Filters?, input2Filters?))?, outputFilters?, 
                               outputProperties?, outputFileExtension?,
        parserFeatures?, comparatorFeatures?, comparatorProperties?, transformerAttributes?, lexicalPreservation?)>
<!ATTLIST comparatorPipeline
          id CDATA #REQUIRED
          description CDATA #REQUIRED>

<!ELEMENT fullDescription (#PCDATA)>
<!ELEMENT pipelineParameters (booleanParameter | stringParameter)+>
<!ELEMENT description (#PCDATA)>
<!ELEMENT booleanParameter (description?)>
<!ATTLIST booleanParameter 
          name CDATA #REQUIRED
          defaultValue (true|false) #REQUIRED>
<!ELEMENT stringParameter (description?)>
<!ATTLIST stringParameter
          name CDATA #REQUIRED
          defaultValue CDATA #REQUIRED>

<!ELEMENT inputFilters (filter+)>
<!ELEMENT input1Filters (filter+)>
<!ELEMENT input2Filters (filter+)>
<!ELEMENT outputFilters (filter+)>

<!ELEMENT filter ((class | resource | http | file), parameter*) >
<!ATTLIST filter
          if CDATA #IMPLIED
          unless CDATA #IMPLIED>

  
<!ELEMENT class EMPTY>
<!ATTLIST class name CDATA #REQUIRED>

<!ELEMENT resource EMPTY>
<!ATTLIST resource name CDATA #REQUIRED>

<!ELEMENT http EMPTY>
<!ATTLIST http url CDATA #REQUIRED>

<!ELEMENT file EMPTY>
<!ATTLIST file path CDATA #REQUIRED>

<!ELEMENT parameter EMPTY>
<!ATTLIST parameter
          name CDATA #REQUIRED
          parameterRef CDATA #IMPLIED
          literalValue CDATA #IMPLIED>

<!ELEMENT comparatorFeatures (feature+)>
<!ELEMENT parserFeatures (feature+)>
<!ELEMENT comparatorProperties (property+)>
<!ELEMENT transformerAttributes (booleanAttribute|stringAttribute)+>

<!ELEMENT feature EMPTY>
<!ATTLIST feature
          name CDATA #REQUIRED
          parameterRef CDATA #IMPLIED
          literalValue (true|false) #IMPLIED>

<!ELEMENT booleanAttribute EMPTY>
<!ATTLIST booleanAttribute
          name CDATA #REQUIRED
          parameterRef CDATA #IMPLIED
          literalValue (true|false) #IMPLIED>


<!ELEMENT outputProperties (property+)>

<!ELEMENT outputFileExtension EMPTY>
<!ATTLIST outputFileExtension
          extension CDATA #REQUIRED>      

<!ELEMENT property EMPTY>
<!ATTLIST property 
          name CDATA #REQUIRED
          parameterRef CDATA #IMPLIED
          literalValue CDATA #IMPLIED>

<!ELEMENT stringAttribute EMPTY>
<!ATTLIST stringAttribute 
          name CDATA #REQUIRED
          parameterRef CDATA #IMPLIED
          literalValue CDATA #IMPLIED>
