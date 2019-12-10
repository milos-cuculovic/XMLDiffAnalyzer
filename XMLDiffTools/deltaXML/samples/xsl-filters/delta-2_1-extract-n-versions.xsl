<?xml version="1.0" encoding="UTF-8"?>
<!--
  Originally designed for use with dx2-threshold.xsl
  
  This stylesheet extracts any or all of the original inputs from an element in a delta v2.1 result file. 
  The param: $versions-to-extract is the sequence of version-identifiers to extract from the element - the default is (A,B).
  If this is not set then all versions identified in the top-level deltaV2 attribute are extracted.
  
  The result is one element (and modified content) for each specified version identifier - with each element having a deltaV2
  attribute value giving its version identifier.
  
  This is an extension of delta-2_1-extract-version.xsl - which extracts just one tree, A or B from the whold document.
  It is implemented as a two-pass process; the first pass removes all nodes that are not relevant for the version to be
  extracted and the second pass reconstructs elements that were fragmented due to the nature of representing overlapping 
  hierarchies.
  Templates relevant to the first pass are in the 'extract' mode and those relevant to the second pass are in the 'reconstruct' mode
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:local="http://www.deltaxml.com/ns/functions/delta-2_1-extract-version/local" exclude-result-prefixes="#all"
  version="2.0">

  <xsl:import href="functions/nearest-delta.xsl"/>
  <xsl:import href="functions/attribute-namespaces.xsl"/>

  <xsl:variable name="deltaV2Versions" as="xs:string*" select="local:getDeltaV2Versions(*/@deltaxml:deltaV2)"/>
  <xsl:variable name="deltaV2Xmlns" as="xs:anyURI" select="xs:anyURI('http://www.deltaxml.com/ns/well-formed-delta-v1')"/>

  <!-- The version that should be extracted from the delta file -->
  <xsl:param name="set-versions-to-extract" as="xs:string*" select="()"/>
  <xsl:param name="detect-moves" as="xs:string" select="'false'"/>
  <xsl:template match="*" mode="split-element-v21">
    
  <!-- check that the specified required versions are present -->
  <xsl:variable name="non-matching-versions" as="xs:string*"
    select="for $v in $set-versions-to-extract return
                        if ($v = $deltaV2Versions) then () else $v"/>

    <xsl:if test="exists($non-matching-versions)">
      <xsl:sequence
        select="error(QName('', 'invalidVersion'), 
                                  concat('The specified versions: ''', 
                                         string-join($non-matching-versions, ','), 
                                         ''' do not exist in this document.'))"
      />
    </xsl:if>

    <xsl:variable name="top-element" as="element()" select="."/>
    <xsl:variable name="versions-to-extract" 
      select="if(exists($set-versions-to-extract)) then 
              $set-versions-to-extract 
              else local:getDeltaV2Versions(@deltaxml:deltaV2)"/>
    <!-- For each version, store the results of the first pass in a variable and then run the second pass on it -->
      <xsl:for-each select="$versions-to-extract">
        <xsl:variable name="first-pass">
          <xsl:apply-templates select="$top-element" mode="extract">
            <xsl:with-param name="version-to-extract" select="current()" as="xs:string" tunnel="yes"/>
          </xsl:apply-templates>
        </xsl:variable>
        <xsl:apply-templates select="$first-pass" mode="reconstruct">
          <xsl:with-param name="version" select="current()"/>
        </xsl:apply-templates>
      </xsl:for-each>    
  </xsl:template>

  <!-- EXTRACT MODE -->

  <xsl:template match="@*" mode="extract">
    <xsl:param name="version-to-extract" as="xs:string" tunnel="yes"/>
    <xsl:if
      test="local:include-node(./parent::*, $version-to-extract) and not(local:remove-attribute(. , $version-to-extract))">
      <xsl:copy copy-namespaces="no"/>
    </xsl:if>
  </xsl:template>

  <!-- Remove all attributes that aren't necessary for reconstructing fragments -->
  <xsl:function name="local:remove-attribute" as="xs:boolean">
    <xsl:param name="attribute" as="attribute()"/>
    <xsl:param name="version-to-extract" as="xs:string"/>
    <xsl:variable name="att-name" select="local-name($attribute)"/>

    <xsl:variable name="xmlns" as="xs:anyURI" select="namespace-uri($attribute)"/>
    <xsl:sequence
      select="if ($xmlns ne $deltaV2Xmlns) then false() 
      else if($att-name = ('deltaV2','version','content-type','deltaTag')) then true() 
      else if(local-name($attribute) = ('deltaTagStart','deltaTagMiddle','deltaTagEnd') 
              and not(local:deltaTagIncludes($attribute, $version-to-extract))) then true()
      else false()"
    />
  </xsl:function>

  <xsl:template match="node()" mode="extract">
    <xsl:param name="version-to-extract" as="xs:string" tunnel="yes"/>
    <xsl:if test="local:process-node(., $version-to-extract)">
      <xsl:choose>
        <xsl:when test="local:include-node(., $version-to-extract)">
          <xsl:copy copy-namespaces="no">
            <xsl:apply-templates select="@*, deltaxml:attributes, node() except deltaxml:attributes" mode="#current"/>
          </xsl:copy>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="node() except deltaxml:attributes" mode="#current"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <xsl:template match="deltaxml:attributes" mode="extract">
    <xsl:apply-templates select="*" mode="#current"/>
  </xsl:template>

  <xsl:template match="deltaxml:attributes/*" mode="extract">
    <xsl:param name="version-to-extract" as="xs:string" tunnel="yes"/>
    <xsl:if test="local:include-node(., $version-to-extract)">
      <xsl:variable name="xmlns" as="xs:string" select="deltaxml:get-attribute-ns(.)"/>
      <xsl:variable name="prefix" as="xs:string"
        select="if ($xmlns eq $xml-namespace) then 'xml:' 
                else if ($xmlns eq '') then '' 
                else concat(prefix-from-QName(node-name(.)), ':')"/>
      <xsl:attribute name="{$prefix}{local-name(.)}" namespace="{$xmlns}">
        <xsl:value-of
          select="deltaxml:attributeValue[local:deltaV2Includes(@deltaxml:deltaV2, $version-to-extract)]/text()"/>
      </xsl:attribute>
    </xsl:if>
  </xsl:template>

  <!-- END OF EXTRACT MODE -->

  <!-- RECONSTRUCT MODE -->

  <!-- identity transform -->
  <xsl:template match="node() | @*" mode="reconstruct">
    <xsl:param name="version" as="xs:string?" select="()"/>
    <xsl:copy copy-namespaces="no">
      <xsl:if test="exists($version)">
        <xsl:attribute name="deltaxml:deltaV2" select="$version"/>
        <xsl:if test="$detect-moves eq 'true'">
          <xsl:attribute name="deltaxml:split" select="'true'"/>
        </xsl:if>
      </xsl:if>
      <xsl:apply-templates select="@* except @deltaxml:deltaV2 | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@deltaxml:deltaTagStart | @deltaxml:deltaTagMiddle | @deltaxml:deltaTagEnd" mode="reconstruct"/>

  <!-- Matches elements that have children with deltaTags -->
  <xsl:template match="node()[child::*[string-length(local:getDeltaTags(.)) gt 0]]" mode="reconstruct">
    <xsl:param name="version" as="xs:string?" select="()"/>
    <xsl:copy copy-namespaces="no">
      <xsl:if test="exists($version)">
        <xsl:attribute name="deltaxml:deltaV2" select="$version"/>
      </xsl:if>
      <xsl:apply-templates select="@* except @deltaxml:deltaV2" mode="#current"/>

      <xsl:call-template name="reconstruct-level">
        <xsl:with-param name="nodes" select="node()"/>
        <xsl:with-param name="version" select="$version"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>

  <!-- 
    Although not technically in the reconstruct mode, this named template is used for reconstruction.
    It performs a double grouping to group fragmented elements into groups that look like (shorthand):
    
    <elem deltaTagStart="..">..</elem>
    <elem deltaTagMiddle="..">..</elem> (optional)
    <elem deltaTagMiddle="..">..</elem> (optional)
    ...
    <elem deltaTagEnd="..">..</elem>
    
    A group like this is converted into the relevant element and then this named template is recursively called on the 
    aggregated content of all items in the group
  -->
  <xsl:template name="reconstruct-level">
    <xsl:param name="nodes" as="node()*"/>
    <xsl:param name="version" as="xs:string?" select="()"/>
    <xsl:for-each-group select="$nodes" group-starting-with="*[@deltaxml:deltaTagStart]">
      <xsl:for-each-group select="current-group()" group-ending-with="*[@deltaxml:deltaTagEnd]">
        <xsl:choose>
          <xsl:when test="exists(current-group()[1]/@deltaxml:deltaTagStart)">
            <xsl:element name="{name(current-group()[1])}" namespace="{namespace-uri(current-group()[1])}">
              <xsl:if test="exists($version)">
                <xsl:attribute name="deltaxml:deltaV2" select="$version"/>
              </xsl:if>
              <xsl:apply-templates select="current-group()[1]/@*" mode="reconstruct"/>
              <xsl:call-template name="reconstruct-level">
                <!-- select the children of each member of the current-group -->
                <xsl:with-param name="nodes" as="node()*" select="for $n in current-group() return $n/node()"/>
              </xsl:call-template>
            </xsl:element>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="current-group()" mode="reconstruct"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each-group>
    </xsl:for-each-group>
  </xsl:template>

  <!-- END OF RECONSTRUCT MODE -->

  <!-- FUNCTIONS -->

  <!-- Converts a deltaV2 attribute value into a sequence of strings representing the versions it contains -->
  <xsl:function name="local:getDeltaV2Versions" as="xs:string+">
    <xsl:param name="deltaV2" as="xs:string"/>
    <xsl:sequence select="tokenize($deltaV2, '!=|=')"/>
  </xsl:function>

  <!-- States whether a deltaV2 value includes the supplied version -->
  <xsl:function name="local:deltaV2Includes" as="xs:boolean">
    <xsl:param name="deltaV2" as="xs:string"/>
    <xsl:param name="version" as="xs:string"/>
    <xsl:sequence select="$version = local:getDeltaV2Versions($deltaV2)"/>
  </xsl:function>

  <!-- Returns all of the values of deltaTag elements joined together as a comma separated string -->
  <xsl:function name="local:getDeltaTags" as="xs:string?">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence
      select="string-join((xs:string($node/@deltaxml:deltaTag), 
                                       xs:string($node/@deltaxml:deltaTagStart), 
                                       xs:string($node/@deltaxml:deltaTagMiddle), 
                                       xs:string($node/@deltaxml:deltaTagEnd)), ',')"
    />
  </xsl:function>

  <!-- Converts a deltaTag value into a sequence of strings representing the versions it contains -->
  <xsl:function name="local:getDeltaTagVersions" as="xs:string+">
    <xsl:param name="deltaTag" as="xs:string"/>
    <xsl:sequence select="tokenize($deltaTag, ',')"/>
  </xsl:function>

  <!-- States whether the supplied deltaTag value includes the supplied version -->
  <xsl:function name="local:deltaTagIncludes" as="xs:boolean">
    <xsl:param name="deltaTag" as="xs:string"/>
    <xsl:param name="version" as="xs:string"/>
    <xsl:sequence select="$version = local:getDeltaTagVersions($deltaTag)"/>
  </xsl:function>

  <!-- 
    States whether a node should be processed or not. This does not neccessarily mean that it will be output but means that 
    it and its subtree should be considered for output
  -->
  <xsl:function name="local:process-node" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="version-to-extract" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$node/self::deltaxml:attributes">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="local:deltaV2Includes(deltaxml:nearest-delta($node), $version-to-extract)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- States whether a node should be included in the output -->
  <xsl:function name="local:include-node" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="version-to-extract" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="$node/self::text()">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:when test="$node/self::deltaxml:textGroup or $node/self::deltaxml:text or $node/self::deltaxml:attributes">
        <xsl:sequence select="false()"/>
      </xsl:when>
      <xsl:when test="string-length(local:getDeltaTags($node)) gt 0">
        <xsl:sequence select="local:deltaTagIncludes(local:getDeltaTags($node), $version-to-extract)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="local:deltaV2Includes(deltaxml:nearest-delta($node), $version-to-extract)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

</xsl:stylesheet>
