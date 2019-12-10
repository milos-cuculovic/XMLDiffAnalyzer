<?xml version="1.0" encoding="UTF-8"?>
<!--
 
  This stylesheet extracts any version tree from an element in a delta v2.1 result file. 
  The param: $version-to-extract is the version-identifier to extract from the element - the default is 'B'.
  
  Note that there is no potential for conflicting formatting elements because only one tree is currently extracted
  
  When extracting, deltaV2 attributes on parent formatting elements that are removed are added to the any
  child elements, to ensure inherited deltaV2 information is not lost.
 
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:local="http://www.deltaxml.com/ns/functions/delta-2_1-extract-version/local" exclude-result-prefixes="#all"
  version="2.0">

  <xsl:variable name="deltaV2Xmlns" as="xs:anyURI" select="xs:anyURI('http://www.deltaxml.com/ns/well-formed-delta-v1')"/>

  <!-- The version that should be extracted from the delta file -->
  <xsl:param name="version-to-extract" as="xs:string" select="'B'"/>
  
  <xsl:template match="*" mode="split-element-v21">
    <xsl:param name="version" as="xs:string" select="$version-to-extract"/>
    <!-- store the results of the first pass in a variable and then run the second pass on it -->

    <xsl:variable name="first-pass">
      <xsl:apply-templates select="." mode="extract">
        <xsl:with-param name="version" select="$version" tunnel="yes"/>
      </xsl:apply-templates>     
    </xsl:variable>

    <xsl:apply-templates select="$first-pass" mode="reconstruct">
       <xsl:with-param name="version" select="$version" tunnel="yes"/>
    </xsl:apply-templates> 
  </xsl:template>

  <!-- EXTRACT MODE -->

  <xsl:template match="@*" mode="extract">
    <xsl:param name="version" as="xs:string" tunnel="yes"/>
    <xsl:if
      test="local:include-node(./parent::*, $version) and not(local:remove-attribute(. , $version))">
      <xsl:copy copy-namespaces="no"/>
    </xsl:if>
  </xsl:template>

  <!-- Remove all attributes that aren't necessary for reconstructing fragments -->
  <xsl:function name="local:remove-attribute" as="xs:boolean">
    <xsl:param name="attribute" as="attribute()"/>
    <xsl:param name="version" as="xs:string"/>
    <xsl:variable name="att-name" select="local-name($attribute)"/>

    <xsl:variable name="xmlns" as="xs:anyURI" select="namespace-uri($attribute)"/>
    <xsl:sequence
      select="if ($xmlns ne $deltaV2Xmlns) then false() 
      else if(local-name($attribute) = ('deltaTagStart','deltaTagMiddle','deltaTagEnd') 
              and not(local:deltaTagIncludes($attribute, $version))) then true()
      else if(local-name($attribute) eq 'deltaTag') then true()
      else false()"
    />
  </xsl:function>

  <xsl:template match="node()" mode="extract">
    <xsl:param name="version" as="xs:string" tunnel="yes"/>
    <xsl:param name="parent-deltaV2" as="attribute()?" select="()"/>
      <xsl:choose>
        <xsl:when test="local:include-node(., $version)">
          <xsl:copy copy-namespaces="no">
            <xsl:if test=". instance of element() and empty(@deltaxml:deltaV2)">
              <xsl:copy-of select="$parent-deltaV2"/>
            </xsl:if>
            <xsl:apply-templates select="@*, node()" mode="#current"/>            
          </xsl:copy>
        </xsl:when>
        <xsl:otherwise>
          <xsl:apply-templates select="node()" mode="#current">
            <xsl:with-param name="parent-deltaV2" select="(@deltaxml:deltaV2, $parent-deltaV2)[1]"/>
          </xsl:apply-templates>
        </xsl:otherwise>
      </xsl:choose>   
  </xsl:template>
  
  <xsl:template match="text()[not(ancestor::deltaxml:textGroup)][not(ancestor::deltaxml:attributes)][ancestor::*[@deltaxml:deltaV2=('A', 'B')]]" mode="extract">
    <xsl:variable name="delta" select="ancestor::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2"/>
    <xsl:element name="deltaxml:textGroup">
      <xsl:attribute name="deltaxml:deltaV2" select="$delta"/>
      <xsl:element name="deltaxml:text">
        <xsl:attribute name="deltaxml:deltaV2" select="$delta"/>
        <xsl:copy/>
      </xsl:element>
    </xsl:element>
  </xsl:template>


  <!-- END OF EXTRACT MODE -->

  <!-- RECONSTRUCT MODE -->

  <!-- identity transform -->
  <xsl:template match="node() | @*" mode="reconstruct">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="@deltaxml:deltaTagStart | @deltaxml:deltaTagMiddle | @deltaxml:deltaTagEnd" mode="reconstruct"/>

  <!-- Matches elements that have children with deltaTags -->
  <xsl:template match="node()[child::*[string-length(local:getDeltaTags(.)) gt 0]]" mode="reconstruct">
    <xsl:param name="version" as="xs:string" tunnel="yes"/>
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="#current"/>

      <xsl:call-template name="reconstruct-level">
        <xsl:with-param name="nodes" select="node()"/>
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
    <xsl:param name="version" as="xs:string" tunnel="yes"/>

    <xsl:for-each-group select="$nodes" group-starting-with="*[@deltaxml:deltaTagStart]">
      <xsl:for-each-group select="current-group()" group-ending-with="*[@deltaxml:deltaTagEnd]">
        <xsl:choose>
          <xsl:when test="exists(current-group()[1]/@deltaxml:deltaTagStart)">
            <xsl:element name="{name(current-group()[1])}" namespace="{namespace-uri(current-group()[1])}">            
              <xsl:apply-templates select="current-group()[1]/@* except current-group()[1]/@deltaxml:deltaV2" mode="reconstruct"/>
              <xsl:variable name="deltas" select="distinct-values(current-group()//@deltaxml:deltaV2)"/>
              <xsl:variable name="delta" as="xs:string">
                <xsl:choose>
                  <xsl:when test="count($deltas) gt 1">
                    <xsl:sequence select="'A!=B'"/>
                  </xsl:when>
                  <xsl:when test="count($deltas) eq 0">
                    <xsl:sequence select="''"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:sequence select="$deltas[1]"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              
              <xsl:if test="$delta != ''">
                <xsl:attribute name="deltaxml:deltaV2" select="$delta"/>
              </xsl:if>
              
              <xsl:call-template name="reconstruct-level">
                <!-- select the children of each member of the current-group -->
                <xsl:with-param name="nodes" as="node()*" select="for $n in current-group() return if (string-length(local:getDeltaTags($n))
                  gt 0) then $n/node() else $n"/>
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


  <!-- States whether a node should be included in the output -->
  <xsl:function name="local:include-node" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="version" as="xs:string"/>
    <xsl:choose>
      <xsl:when test="string-length(local:getDeltaTags($node)) gt 0">
        <xsl:sequence select="local:deltaTagIncludes(local:getDeltaTags($node), $version)"/>
      </xsl:when>
      <!-- we must not assume that the format element itself has a delta - we need to check ancestor formatting elements for deltas as well
        -->
      <xsl:when test="$node/@deltaxml:format and $node/ancestor-or-self::*[@deltaxml:format][@deltaxml:deltaV2][1]/@deltaxml:deltaV2 and
        not(tokenize($node/ancestor-or-self::*[@deltaxml:format][@deltaxml:deltaV2][1]/@deltaxml:deltaV2, '=|!=') = $version)">
        <xsl:sequence select="false()"/> 
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="true()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

</xsl:stylesheet>
