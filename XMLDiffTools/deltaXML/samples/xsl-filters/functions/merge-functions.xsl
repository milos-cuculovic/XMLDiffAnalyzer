<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:map="http://www.w3.org/2005/xpath-functions/map"
  exclude-result-prefixes="#all"
  version="2.0">

  <xsl:function name="deltaxml:getBase" as="xs:string">
    <xsl:param name="inElement" as="element()"/>
    <xsl:sequence select="deltaxml:getVersions($inElement/ancestor-or-self::*[last()]
                                               /@deltaxml:deltaV2)[1]"/>
  </xsl:function>
  
  <xsl:function name="deltaxml:getVersions" as="xs:string+">
    <xsl:param name="deltaV2" as="xs:string"/>
    <xsl:sequence select="tokenize($deltaV2, '!=|=')"/>
  </xsl:function>

  <xsl:function name="deltaxml:deltaV2Includes" as="xs:boolean">
    <xsl:param name="deltaV2" as="xs:string"/>
    <xsl:param name="versionLabel" as="xs:string"/>
    <xsl:sequence select="deltaxml:getVersions($deltaV2) = $versionLabel"/>
  </xsl:function>

  <xsl:function name="deltaxml:getParentVersions" as="xs:string+">
    <xsl:param name="currentElement" as="node()"/>
    <xsl:sequence select="deltaxml:getVersions($currentElement/ancestor::*[@deltaxml:deltaV2][not(self::deltaxml:attributes)][1]/@deltaxml:deltaV2)"/>
  </xsl:function>

    <xsl:function name="deltaxml:value-intersect" as="xs:anyAtomicType*">
        <xsl:param name="arg1" as="xs:anyAtomicType*"/>
        <xsl:param name="arg2" as="xs:anyAtomicType*"/>
        <xsl:sequence select="distinct-values($arg1[.=$arg2])"/>
    </xsl:function>
    
    <xsl:function name="deltaxml:value-except" as="xs:anyAtomicType*">
        <xsl:param name="arg1" as="xs:anyAtomicType*"/>
        <xsl:param name="arg2" as="xs:anyAtomicType*"/>
        <xsl:sequence select="distinct-values($arg1[not(.=$arg2)])"/>
    </xsl:function>
    
  <!-- true when all members of arg2 are in arg1 -->
  <xsl:function name="deltaxml:subset" as="xs:boolean">
    <xsl:param name="arg1" as="xs:anyAtomicType*"/>
    <xsl:param name="arg2" as="xs:anyAtomicType*"/>
    <xsl:sequence select="empty(deltaxml:value-except($arg2, $arg1))"/>
  </xsl:function>

  <!-- returns true if specified versions are in correct order w.r.t to version-order-->
  <xsl:function name="deltaxml:areVersionsInOrder" as="xs:boolean">
    <xsl:param name="versionOrder" as="xs:string*"/>
    <xsl:param name="versions" as="xs:string*"/>
    <xsl:choose>
      <xsl:when test="count($versions) gt 1">
        <xsl:choose>
          <xsl:when test="(index-of($versionOrder, $versions[2]) - index-of($versionOrder, $versions[1])) eq 1">
            <xsl:sequence select="deltaxml:areVersionsInOrder($versionOrder, deltaxml:tail($versions))" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence  select="false()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence  select="true()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <!-- this function is used in format reconstruction to correct delta for sequential merge.
        For example A=C=D!=B to A!=B!=C=D If version order is A, B, C, D-->
  <xsl:function name="deltaxml:correctDeltaForSequential" as="xs:string">
    <xsl:param name="versionOrder" as="xs:string*"/>
    <xsl:param name="delta" as="xs:string"/>
    <xsl:variable name="equal-groups" select="tokenize($delta, '!=')" as="xs:string*"/>
    <xsl:variable name="new-equal-groups" as="xs:string*">
      <xsl:for-each select="$equal-groups">
        <xsl:choose>
          <xsl:when test="deltaxml:areVersionsInOrder($versionOrder, tokenize(., '='))">
            <xsl:sequence select="."/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="deltaxml:createOrderedEqualGroups($versionOrder, tokenize(.,'='), 1, 1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:variable>
    
    <xsl:variable name="positionMap" as="map(xs:integer, xs:string)">
      <xsl:map>     
        <xsl:for-each select="$new-equal-groups">
          <xsl:map-entry key="index-of($versionOrder, tokenize(., '=')[1])" select="."/>
        </xsl:for-each>
      </xsl:map>
    </xsl:variable>
    
    <xsl:variable name="sortedKeys" as="xs:integer*">
      <xsl:perform-sort select="map:keys($positionMap)">
        <xsl:sort select="." data-type="number"/>
      </xsl:perform-sort>
    </xsl:variable>
    
    <xsl:variable name="returnDelta" as="xs:string" select="string-join((for $k in $sortedKeys return $positionMap($k)), '!=')"/>
    
    <xsl:sequence select="string-join((for $k in $sortedKeys return $positionMap($k)), '!=')"/>
  </xsl:function>
  
  <xsl:function name="deltaxml:createOrderedEqualGroups" as="xs:string*">
    <xsl:param name="versionOrder" as="xs:string*"/>
    <xsl:param name="equal-groups-versions" as="xs:string*"/>
    <xsl:param name="startIndex" as="xs:integer"/>
    <xsl:param name="index" as="xs:integer"/>
    
    <xsl:choose>
      <xsl:when test="$index le count($equal-groups-versions)">
        <xsl:choose>
          <xsl:when test="deltaxml:areVersionsInOrder($versionOrder, ($equal-groups-versions[$index], $equal-groups-versions[$index +1]))">
            <xsl:sequence select="deltaxml:createOrderedEqualGroups($versionOrder, $equal-groups-versions, $startIndex, $index + 1)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="string-join(subsequence($equal-groups-versions, $startIndex, $index), '=')"/>
            <xsl:sequence select="deltaxml:createOrderedEqualGroups($versionOrder, $equal-groups-versions, $index + 1 , $index + 1)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="string-join(subsequence($equal-groups-versions, $startIndex, $index), '=')"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:function name="deltaxml:tail" as="xs:string*">
    <xsl:param name="sequence" as="xs:string*"/>
    <xsl:sequence select="subsequence($sequence, 2)"/>
  </xsl:function>

</xsl:stylesheet>