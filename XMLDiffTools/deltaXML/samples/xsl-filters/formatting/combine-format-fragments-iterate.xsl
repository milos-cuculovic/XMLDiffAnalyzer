<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:math="http://www.w3.org/2005/xpath-functions/math"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:local="http://www.deltaxml.com/ns/functions/combine-format-fragments/local"
                exclude-result-prefixes="#all"
                version="3.0">
   
  <xsl:variable name="fullTag" as="xs:string" select="'deltaTag'"/>
  <xsl:variable name="startTag" as="xs:string" select="'deltaTagStart'"/>
  <xsl:variable name="middleTag" as="xs:string" select="'deltaTagMiddle'"/>
  <xsl:variable name="endTag" as="xs:string" select="'deltaTagEnd'"/>
  
  <!-- MODES: combine, delta-pushdown -->
  
  <xsl:template match="/">
    <xsl:apply-templates mode="combine"/>
  </xsl:template>
  
  <!-- identity transform -->
  <xsl:template match="node() | @*" mode="combine delta-pushdown">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="*[child::*[local:hasPartialTagOnly(.)]]" mode="combine delta-pushdown">
    <xsl:copy>
      <xsl:apply-templates select="@*" mode="combine"/>
      <xsl:call-template name="combine">
        <xsl:with-param name="sequence" select="node()" as="node()*"/>
      </xsl:call-template>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="node()[not(@deltaxml:deltaV2)][not(ancestor::deltaxml:*)][local:nearest-delta-is(., ('A', 'B'))]" mode="delta-pushdown">
    <xsl:variable name="delta" select="local:nearest-delta(.)"/>
    <xsl:choose>
      <xsl:when test="self::text()">
        <xsl:element name="deltaxml:textGroup">
          <xsl:attribute name="deltaxml:deltaV2" select="$delta"/>
          <xsl:element name="deltaxml:text">
            <xsl:attribute name="deltaxml:deltaV2" select="$delta"/>
            <xsl:copy-of select="."/>
          </xsl:element>
        </xsl:element>
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy>
          <xsl:attribute name="deltaxml:deltaV2" select="$delta"/>
          <xsl:apply-templates select="@*, node()" mode="combine"/>
        </xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template name="combine">
    <xsl:param name="sequence" as="node()*"/>
    <xsl:iterate select="$sequence">
      <xsl:param name="ongoing-combination" as="xs:boolean" select="false()"/>
      <xsl:param name="combine-start" as="xs:integer" select="0"/>
      
      <xsl:variable name="combinable-with-previous" as="xs:boolean">
        <!-- this choose gives a quick fail if we already know that the previous element cannot possibly be combined -->
        <xsl:choose>
          <xsl:when test="$ongoing-combination">
            <xsl:sequence select="local:hasPartialTagOnly(.) and local:combinable(subsequence($sequence, position()-1, 1), .)"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="false()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      
      <!-- some of these variables may be redundant/inefficient but are used to make the xsl:choose simpler to understand -->
      
      <xsl:variable name="is-combo-end" as="xs:boolean"
                    select="$combinable-with-previous and 
                            (exists(./@deltaxml:deltaTagEnd) or position() = last())"/>
      
      <xsl:variable name="continues-current-combo-without-ending" as="xs:boolean" 
                    select="$combinable-with-previous and not($is-combo-end)"/>
      
      <xsl:variable name="breaks-existing-combo" as="xs:boolean"
                    select="$ongoing-combination and not($combinable-with-previous)"/>
      
      <xsl:variable name="starts-new-combo" as="xs:boolean"
                    select="(not($ongoing-combination) or $breaks-existing-combo) and 
                            (local:hasPartialTagOnly(.) and local:hasCombinableTag(.) and not(local:hasMultipleTags(.)))"/>
      
      <xsl:if test="$breaks-existing-combo">
        <!-- output the combo up to this point -->
        <xsl:call-template name="output-combo">
          <xsl:with-param name="sequence" select="$sequence"/>
          <xsl:with-param name="start" select="$combine-start"/>
          <xsl:with-param name="end" select="position() - 1"/>
        </xsl:call-template>
      </xsl:if>
      
      <xsl:choose>
        <xsl:when test="$starts-new-combo and position() = last()">
          <!-- this is not really a combo and can be output as a single node -->
          <xsl:apply-templates select="subsequence($sequence, position(), 1)" mode="delta-pushdown"/>
        </xsl:when>
        <xsl:when test="$is-combo-end">
          <!-- output combo up to this point plus this item -->
          <xsl:call-template name="output-combo">
            <xsl:with-param name="sequence" select="$sequence"/>
            <xsl:with-param name="start" select="if ($starts-new-combo) then position() else $combine-start"/>
            <xsl:with-param name="end" select="position()"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="$starts-new-combo or $continues-current-combo-without-ending">
          <!-- do nothing here, just jump to the next iteration -->
          <xsl:value-of select="()"/> <!-- for adding a breakpoint -->
        </xsl:when>
        <xsl:otherwise>
          <!-- output this node - nothing special going on -->
          <xsl:apply-templates select="subsequence($sequence, position(), 1)" mode="delta-pushdown"/>
        </xsl:otherwise>
      </xsl:choose>
      
      <!-- now iterate -->
      <xsl:next-iteration>
        <xsl:with-param name="ongoing-combination" select="$continues-current-combo-without-ending or $starts-new-combo"/>
        <xsl:with-param name="combine-start" select="if ($starts-new-combo) then position() else $combine-start"/>
      </xsl:next-iteration>
      
    </xsl:iterate>
  </xsl:template>
  
  <xsl:template name="output-combo">
    <xsl:param name="sequence" as="node()*" required="yes"/>
    <xsl:param name="start" as="xs:integer" required="yes"/>
    <xsl:param name="end" as="xs:integer" required="yes"/>
    
    <xsl:choose>
      <xsl:when test="$start = $end">
        <xsl:apply-templates select="subsequence($sequence, $start, 1)" mode="combine"/>
      </xsl:when>
      <xsl:otherwise>
        <!-- All the CHILD nodes of the top-level items we are combining. It will be the content of the final combined item -->
        <xsl:variable name="items-to-combine" as="node()*" select="subsequence($sequence, $start, $end - $start + 1)/node()"/>
        
        <!-- The deltaTag type of the first top-level item being combined -->
        <xsl:variable name="first-tag" select="local:deltaTagType(subsequence($sequence, $start, 1))"/>
        
        <!-- The deltaTag type of the last top-level item being combined -->
        <xsl:variable name="last-tag" select="local:deltaTagType(subsequence($sequence, $end, 1))"/>
        
        <!-- The deltaTag type to add to the combined element -->
        <xsl:variable name="new-tag" as="xs:string">
          <xsl:choose>
            <xsl:when test="$first-tag = $startTag and $last-tag = $endTag">
              <xsl:sequence select="$fullTag"/>
            </xsl:when>
            <xsl:when test="$first-tag = $startTag and $last-tag = $middleTag">
              <xsl:sequence select="$startTag"/>
            </xsl:when>
            <xsl:when test="$first-tag = $middleTag and $last-tag = $middleTag">
              <xsl:sequence select="$middleTag"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:sequence select="$endTag"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        
        <xsl:variable name="start-elem" as="node()" select="subsequence($sequence, $start, 1)"/>
        
        <xsl:element name="{name($start-elem)}" namespace="{namespace-uri($start-elem)}">
          <xsl:variable name="fragment-deltas" as="xs:string*" select="subsequence($sequence, $start, $end - $start + 1)/@deltaxml:deltaV2"/>
          <xsl:variable name="child-deltas" as="xs:string*" select="$items-to-combine/@deltaxml:deltaV2"/>
          
          <xsl:variable name="delta" as="xs:string">
            <xsl:choose>
              <xsl:when test="('A!=B' = distinct-values($child-deltas)) or 
                              count(distinct-values(($child-deltas, $fragment-deltas))) gt 1">
                <xsl:sequence select="'A!=B'"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:sequence select="distinct-values(($child-deltas, $fragment-deltas))[1]"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:variable>
          
          <xsl:attribute name="deltaxml:deltaV2" select="$delta"/>
          <xsl:attribute name="{concat('deltaxml:', $new-tag)}" select="local:deltaTagValue($start-elem)"/>
          <xsl:copy-of select="$start-elem/@* except ($start-elem/@deltaxml:deltaV2, $start-elem/@deltaxml:deltaTagStart, $start-elem/@deltaxml:deltaTagMiddle)"/>
          
          <xsl:choose>
            <xsl:when test="$items-to-combine[local:hasPartialTagOnly(.)]">
              <xsl:call-template name="combine">
                <xsl:with-param name="sequence" select="$items-to-combine"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="$items-to-combine" mode="delta-pushdown"/>
            </xsl:otherwise>
          </xsl:choose>
          
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>
  
  <xsl:function name="local:combinable" as="xs:boolean">
    <xsl:param name="elem1" as="node()"/>
    <xsl:param name="elem2" as="node()"/>
    
    <xsl:sequence select="$elem1 instance of element() and
                          $elem2 instance of element() and
                          name($elem1) eq name($elem2) and
                          not(local:hasMultipleTags($elem2)) and
                          local:deltaTagValue($elem1) eq local:deltaTagValue($elem2) and
                          local:combinableTags(local:deltaTagType($elem1), local:deltaTagType($elem2))"/>
  </xsl:function>
  
  <xsl:function name="local:combinableTags" as="xs:boolean">
    <xsl:param name="tag1" as="xs:string"/>
    <xsl:param name="tag2" as="xs:string"/>
    
    <xsl:sequence select="($tag1 = $startTag and $tag2 = ($middleTag, $endTag)) or
                          ($tag1= $middleTag and $tag2= ($middleTag, $endTag))"/>
  </xsl:function>
  
  <xsl:function name="local:deltaTagValue" as="xs:string">
    <xsl:param name="elem" as="element()"/>
    <xsl:sequence select="($elem/@deltaxml:deltaTagStart, $elem/@deltaxml:deltaTagMiddle, $elem/@deltaxml:deltaTagEnd)[1]"/>
  </xsl:function>
  
  <xsl:function name="local:deltaTagType" as="xs:string">
    <xsl:param name="elem" as="element()"/>
    <xsl:sequence select="local-name(($elem/@deltaxml:deltaTagStart, $elem/@deltaxml:deltaTagMiddle, $elem/@deltaxml:deltaTagEnd)[1])"/>
  </xsl:function>
  
  <xsl:function name="local:hasPartialTagOnly" as="xs:boolean">
    <xsl:param name="elem" as="node()"/>
    <xsl:sequence select="$elem instance of element() and
                          not(exists($elem/@deltaxml:deltaTag)) and
                          (exists($elem/@deltaxml:deltaTagStart) or 
                          exists($elem/@deltaxml:deltaTagMiddle) or 
                          exists($elem/@deltaxml:deltaTagEnd))"/>
  </xsl:function>
  
  <xsl:function name="local:hasCombinableTag" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="$node instance of element() and
                  
                          (exists($node/@deltaxml:deltaTagStart) or 
                           exists($node/@deltaxml:deltaTagMiddle))"/>
  </xsl:function>
  
  <xsl:function name="local:hasMultipleTags" as="xs:boolean">
    <xsl:param name="elem" as="element()"/>
    <xsl:sequence select="count(($elem/@deltaxml:deltaTagStart, $elem/@deltaxml:deltaTagMiddle, $elem/@deltaxml:deltaTagEnd)) gt 1"/>
  </xsl:function>
  
  <xsl:function name="local:nearest-delta" as="xs:string">
    <xsl:param name="node" as="node()"/>
    <xsl:sequence select="($node/ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2, '')[1]"/>
  </xsl:function> 
  
  <xsl:function name="local:nearest-delta-is" as="xs:boolean">
    <xsl:param name="node" as="node()"/>
    <xsl:param name="deltas" as="xs:string+"/>
    
    <xsl:variable name="nearest-delta" select="$node/ancestor-or-self::*[@deltaxml:deltaV2][1]/@deltaxml:deltaV2" as="xs:string?"/>
    
    <xsl:sequence select="$nearest-delta = $deltas"/>    
  </xsl:function>
  
</xsl:stylesheet>