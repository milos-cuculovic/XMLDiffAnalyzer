<?xml version="1.0" encoding="UTF-8"?>
<!-- (c) 2007, 2008 DeltaXML Ltd.  All rights reserved. -->
<!-- $Id$ -->
<!-- Ordering dependency: Needs to come after remove-exchange.xsl -->
<!-- Ordering dependency: Needs to come before odt-table-row-selector.xsl -->
<!-- Ordering dependency: Needs to come before span unflattener, otherwise style changes will tend
to count towards added/deleted words-->
<!-- Ordering dependency: Needs to come before style unflattener, same reason as above -->

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" 
                 xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1" 
                 xmlns:xs="http://www.w3.org/2001/XMLSchema"
                 xmlns:saxon="http://saxon.sf.net/"
                 xmlns:preserve="http://www.deltaxml.com/ns/preserve" 
                 xmlns:local="http://www.deltaxml.com/ns/local"
                 version="2.0">
  
  <xsl:import href="delta-2_1-extract-n-versions.xsl"/>
  <!-- override the param $set-versions-to-extract in delta-2_1-extract-n-versions.xsl  -->
  <xsl:param name="set-versions-to-extract" as="xs:string*" select="('A','B')"/>

  <!-- 
  The following parameter is used to control whether a modified object (such
  as a paragraph or table row), is replaced by equivalent added and deleted objects.
  
  The replacement process used is switched according to whether the document contains
  formatting elements and is determined by the value of $isVersion21. The '2.1' replacement
  is performed by the imported delta-2_1-extract-both-versions.xsl stylesheet.

  The replacement process takes all the added/new and unchanged objects from the modified
  object and creates an added object from them, similarly the deleted/old and unchanged
  child objects from the corresponding deleted object.

  The control parameter is expressed using a threshold:  the size in characters of the unchanged
  (non- modified, added or deleted) text as a percentage of the overall text size.  Any
  objects with values lower than this parameter will be converted.

  Setting the parameter to 0.0 or less has the effect of turning this filter off - it will
  not modify any objects.

  While setting the parameter to 100.0 will turn objects with textual modifications
  into pairs of added/deleted objects.

  For english text a setting of 10.0 to 20.0 has proved useful during testing.
  -->
  <xsl:param name="ObjectCommonTextMinPercentage" select="10.0"/>
  <xsl:variable name="ObjectCommonTextMinPercentageNumber" as="xs:double" 
	       select="number($ObjectCommonTextMinPercentage)"/>
  <!-- 
  Setting the following paramter to 'yes' will cause a debug message to be printed
  when candidate (usually modified) objects are processed.  This message identifies
  the object in terms of its XPath and reports the change threshold and also optionally
  some text from the object.
  -->
  <xsl:param name="ThresholdDebug" select="'no'" as="xs:string"/>

  <!-- 
  The following parameter controls how much, if any, object text is 
  printed as part of the any debug messages.
  Setting the value to zero will turn off object text reporting.
  Select a value that is compatible with your screen width and/or
  editing tools.
  -->
  <xsl:param name="ThresholdDebugTextReportSize" select="40"/>
  <xsl:variable name="ThresholdDebugTextReportSizeNumber" as="xs:integer" 
    select="xs:integer($ThresholdDebugTextReportSize)"/>
  
  <xsl:variable name="isVersion21" as="xs:boolean" select="/*/@deltaxml:version eq '2.1'"></xsl:variable>
  
  <!-- XSLT2 Identity transform -->
  <xsl:template match="node() | @*" mode="#default ignore-deletes ignore-adds">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <!-- Determine the change threshold for an (odf) element -->
   <xsl:function name="deltaxml:pcdataThreshold" as="xs:double">
     <xsl:param name="element" as="node()"/>
     <xsl:variable name="deleteLength" as="xs:integer" 
                   select="string-length(string-join($element//*[@deltaxml:deltaV2='A']//text()[not(ancestor::deltaxml:attributes)], ''))"/>  
     <xsl:variable name="addLength" as="xs:integer"
                   select="string-length(string-join($element//*[@deltaxml:deltaV2='B']//text()[not(ancestor::deltaxml:attributes)], ''))"/>
     <xsl:variable name="totalLength" as="xs:integer"
                   select="string-length(string-join($element//text()[not(ancestor::deltaxml:attributes)], ''))"/>
     <xsl:variable name="unchangedLength" as="xs:integer" select="$totalLength - ($deleteLength + $addLength)"/>
     <xsl:choose>
       <xsl:when test="$totalLength=0">
         <xsl:value-of select="100"/>
       </xsl:when>
       <!-- there MUST be some unchanged text in the paragraph to leave it as a single paragraph -->
       <!-- see p18 case of Imprima comments 22/02/08 -->
       <xsl:when test="(($addLength = 0) or ($deleteLength = 0)) and $unchangedLength gt 0">
         <xsl:value-of select="100"/>
       </xsl:when>
       <!-- when the whole para is just adds or just deletes, don't split it -->
      <xsl:when test="($addLength = $totalLength) or ($deleteLength = $totalLength)">
        <xsl:value-of select="100"/>
      </xsl:when>
       <xsl:otherwise>
         <xsl:value-of select="(($totalLength - ($deleteLength + $addLength)) div $totalLength) * 100"/>
       </xsl:otherwise>
     </xsl:choose>
   </xsl:function>
  
    <!-- Note that we have added the restriction the exists(ancestor::element()) to ensure that the root node is not matched -->
  <xsl:template match="*[not(self::preserve:ignorable)][@deltaxml:deltaV2='A!=B'][deltaxml:textGroup][local:isThresholdingEnabled(.)][exists(ancestor::element())]">
    <xsl:variable name="thisObjectsThreshold" as="xs:double" select="deltaxml:pcdataThreshold(.)"/>
    <xsl:if test="($ThresholdDebug eq 'yes') and ($thisObjectsThreshold lt 100.0)">
      <xsl:message>
        <xsl:text>path: </xsl:text>
        <xsl:value-of select="saxon:path()"/> 
        <xsl:text> threshold: </xsl:text>
        <xsl:value-of select="format-number($thisObjectsThreshold, '##0.00')"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="if ($ThresholdDebugTextReportSizeNumber > 0) then concat('''', substring(string(.), 1, $ThresholdDebugTextReportSizeNumber), '''') else ''"/>
      </xsl:message> 
    </xsl:if>
    <xsl:choose>
      <xsl:when test="($thisObjectsThreshold lt $ObjectCommonTextMinPercentageNumber) and ($thisObjectsThreshold lt 100.0)">
        <!-- The filtering process should never operate unless there is some added/or deleted text,
        this is not the case when the threshold == 100.0 -->
        <!-- TODO is there a sensible way to decide which to output first? -->
        <xsl:choose>         
          <xsl:when test="$isVersion21">
             <xsl:apply-templates select="." mode="split-element-v21"/>            
          </xsl:when>
          <xsl:otherwise>
             <xsl:apply-templates select="." mode="split-element"/>           
          </xsl:otherwise>
        </xsl:choose>        
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:apply-templates select="@* except @deltaxml:threshold | node()"/>  
        </xsl:copy>
      </xsl:otherwise>      
    </xsl:choose> 
  </xsl:template>
  
  <xsl:function name="local:isThresholdingEnabled" as="xs:boolean">
    <xsl:param name="element" as="element()"/>
    <xsl:for-each select="$element">
      <xsl:sequence select="(not(@deltaxml:threshold='false') and empty(@deltaxml:key))
                          and (not($isVersion21) or empty((@deltaxml:deltaTag, @deltaxml:deltaTagStart, @deltaxml:deltaTagMiddle, @deltaxml:deltaTagEnd)))"/>
    </xsl:for-each>
  </xsl:function>

  <!-- Note that we have added the restriction the exists(ancestor::element()) to ensure that the root node is not matched -->
  <xsl:template match="*" mode="split-element">
        <xsl:copy>
          <xsl:attribute name="deltaxml:deltaV2" select="'A'"/>
          <xsl:if test="$detect-moves eq 'true'">
            <xsl:attribute name="deltaxml:split" select="'true'"/>
          </xsl:if>
          <xsl:apply-templates select="@* except (@deltaxml:deltaV2 | @deltaxml:threshold)" mode="ignore-adds"/>
          <xsl:apply-templates select="deltaxml:attributes" mode="ignore-adds"/>
          <xsl:apply-templates select="node() except deltaxml:attributes" mode="ignore-adds"/>
        </xsl:copy>
        <xsl:copy>
          <xsl:attribute name="deltaxml:deltaV2" select="'B'"/>
          <xsl:if test="$detect-moves eq 'true'">
            <xsl:attribute name="deltaxml:split" select="'true'"/>
          </xsl:if>
          <xsl:apply-templates select="@* except (@deltaxml:deltaV2 | @deltaxml:threshold)" mode="ignore-deletes"/>  
          <xsl:apply-templates select="deltaxml:attributes" mode="ignore-deletes"/>
          <xsl:apply-templates select="node() except deltaxml:attributes" mode="ignore-deletes"/>
        </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[@deltaxml:deltaV2='A']" mode="ignore-deletes"/>
  <xsl:template match="*[@deltaxml:deltaV2='B']" mode="ignore-adds"/>
  
  <xsl:template match="deltaxml:textGroup" mode="ignore-deletes">
    <xsl:apply-templates select="deltaxml:text[@deltaxml:deltaV2='B']/text()"/>
  </xsl:template>
  
  <xsl:template match="deltaxml:textGroup" mode="ignore-adds">
    <xsl:apply-templates select="deltaxml:text[@deltaxml:deltaV2='A']/text()"/>
  </xsl:template>
  
  <xsl:template match="@deltaxml:deltaV2" mode="ignore-adds"/>  
  <xsl:template match="@deltaxml:deltaV2" mode="ignore-deletes"/>
  
  
  <xsl:function name="deltaxml:get-attribute-for-version" as="attribute()?">
    <xsl:param name="current-attribute" as="node()"/>
    <xsl:param name="version" as="xs:string"/>
    
    <xsl:choose>
      <xsl:when test="$current-attribute/deltaxml:attributeValue[@deltaxml:deltaV2=$version]">
        <xsl:choose>
          <xsl:when test="namespace-uri($current-attribute)='http://www.deltaxml.com/ns/non-namespaced-attribute'">
            <xsl:attribute name="{local-name($current-attribute)}" namespace="" select="$current-attribute/deltaxml:attributeValue[@deltaxml:deltaV2=$version]"/>
          </xsl:when>
          <xsl:when test="namespace-uri($current-attribute)='http://www.deltaxml.com/ns/xml-namespaced-attribute'">
            <xsl:attribute name="{local-name($current-attribute)}" namespace="http://www.w3.org/XML/1998/namespace" select="$current-attribute/deltaxml:attributeValue[@deltaxml:deltaV2=$version]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:attribute name="{local-name($current-attribute)}" namespace="{namespace-uri($current-attribute)}" select="$current-attribute/deltaxml:attributeValue[@deltaxml:deltaV2=$version]"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise/>
    </xsl:choose>
  </xsl:function>
  
  <xsl:template match="deltaxml:attributes" mode="ignore-adds">
    <xsl:for-each select="*">
      <xsl:copy-of select="deltaxml:get-attribute-for-version(., 'A')"/>
    </xsl:for-each>
  </xsl:template>
  <xsl:template match="deltaxml:attributes" mode="ignore-deletes">
    <xsl:for-each select="*">
      <xsl:copy-of select="deltaxml:get-attribute-for-version(., 'B')"/>
    </xsl:for-each>
  </xsl:template>
  
</xsl:stylesheet>