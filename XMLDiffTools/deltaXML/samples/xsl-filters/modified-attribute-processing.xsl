<?xml version="1.0" encoding="UTF-8"?>
<!-- This filter is used to provided the modified attribute processing modes
     It deliberately doesn't use the ignore-changes mechanism so that elements with attribute
     changes still have a deltaV2 of A!=B left on them. This allows filters such as the dita-outfilter
     to still mark elements whose attributes changed
  -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
                xmlns:ac="http://www.deltaxml.com/ns/attribute-change"
                exclude-result-prefixes="#all"
                version="2.0">
  
  <xsl:import href="functions/nearest-delta.xsl"/>
  
  <xsl:param name="attribute-processing-mode" select="'automatic'"/>
  <xsl:param name="leave-marker" select="'false'"/>
  
  <xsl:variable name="mark" select="$leave-marker = ('yes', 'true')"/>
  
  <!-- match the document mode so that the whole document can be processed in the relevant mode for 
        attribute processing. This avoids testing the parameter every time an element is processed -->
  <xsl:template match="/">
    <xsl:param name="attribute-processing-mode" select="$attribute-processing-mode" tunnel="yes"/> <!-- for XSpec -->
    <xsl:choose>
      <xsl:when test="$attribute-processing-mode = ('automatic', 'B', 'encode-as-attributes')">
        <xsl:apply-templates mode="B"/>
      </xsl:when>
      <xsl:when test="$attribute-processing-mode = 'BA'">
        <xsl:apply-templates mode="BA"/>
      </xsl:when>
      <xsl:when test="$attribute-processing-mode = 'A'">
        <xsl:apply-templates mode="A"/>
      </xsl:when>
      <xsl:when test="$attribute-processing-mode='AB'">
        <xsl:apply-templates mode="AB"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="node() | @*" mode="#all">
    <xsl:param name="attribute-processing-mode" select="$attribute-processing-mode" tunnel="yes"/> <!-- for XSpec -->
        <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:apply-templates select="deltaxml:attributes" mode="#current"/> <!-- this will be the mode chosen at the document node -->
      <xsl:if test="$attribute-processing-mode = 'encode-as-attributes'">
        <xsl:apply-templates select="deltaxml:attributes" mode="encode"/>
      </xsl:if>
      <xsl:if test="$mark and deltaxml:attributes">
        <xsl:attribute name="deltaxml:attributeChanges" select="'true'"/>
      </xsl:if>
      <xsl:apply-templates select="node() except deltaxml:attributes" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- THE SELECTED-VERSION MODE PUTS THE APPROPRIATE ATTRIBUTES ON THE ELEMENT AS NORMAL ATTRIBUTES -->
  <xsl:template match="deltaxml:attributes" mode="A B AB BA encode">
    <xsl:apply-templates select="*" mode="#current"/>
  </xsl:template>
  
  <!-- increased priority so that it doesn't match the default #all mode template -->
  <xsl:template match="deltaxml:attributes/*[deltaxml:nearest-delta-is(., 'A')]" mode="A AB BA" priority="2.0">
    <xsl:call-template name="output-attribute">
      <xsl:with-param name="attribute" select="."/>
      <xsl:with-param name="version" select="'A'"/>
    </xsl:call-template>
  </xsl:template>
  
  <!-- increased priority so that it doesn't match the default #all mode template -->
  <xsl:template match="deltaxml:attributes/*[deltaxml:nearest-delta-is(., 'A')]" mode="B" priority="2.0"/>
  
  <!-- increased priority so that it doesn't match the default #all mode template -->
  <xsl:template match="deltaxml:attributes/*[deltaxml:nearest-delta-is(., 'B')]" mode="B AB BA" priority="2.0">
    <xsl:call-template name="output-attribute">
      <xsl:with-param name="attribute" select="."/>
      <xsl:with-param name="version" select="'B'"/>
    </xsl:call-template>
  </xsl:template>
  
  <!-- increased priority so that it doesn't match the default #all mode template -->
  <xsl:template match="deltaxml:attributes/*[deltaxml:nearest-delta-is(., 'B')]" mode="A" priority="2.0"/>
  
  <!-- increased priority so that it doesn't match the default #all mode template -->
  <xsl:template match="deltaxml:attributes/*[deltaxml:nearest-delta-is(., 'A!=B')]" mode="A AB" priority="2.0">
    <xsl:call-template name="output-attribute">
      <xsl:with-param name="attribute" select="."/>
      <xsl:with-param name="version" select="'A'"/>
    </xsl:call-template>
  </xsl:template>
  
  <!-- increased priority so that it doesn't match the default #all mode template -->
  <xsl:template match="deltaxml:attributes/*[deltaxml:nearest-delta-is(., 'A!=B')]" mode="B BA" priority="2.0">
    <xsl:call-template name="output-attribute">
      <xsl:with-param name="attribute" select="."/>
      <xsl:with-param name="version" select="'B'"/>
    </xsl:call-template>
  </xsl:template>
  
  <!-- THE ENCODE MODE PUTS THE APPROPRIATE ATTRIBUTES ON THE ELEMENT AS ENCODED CHANGES -->
  <!-- increased priority so that it doesn't match the default #all mode template -->
  <xsl:template match="deltaxml:attributes/*" mode="encode" priority="2.0">
    
    <xsl:variable name="change-type">
      <xsl:choose>
        <xsl:when test="deltaxml:nearest-delta-is(., 'A')">remove</xsl:when>
        <xsl:when test="deltaxml:nearest-delta-is(., 'B')">insert</xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="'modify'"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="att-name">
      <xsl:choose>
        <xsl:when test="namespace-uri(.) = 'http://www.deltaxml.com/ns/non-namespaced-attribute'">
          <xsl:value-of select="local-name(.)"/>
        </xsl:when>
        <xsl:when test="namespace-uri(.) = 'http://www.deltaxml.com/ns/xml-namespaced-attribute'">
          <xsl:value-of select="concat('xml:', local-name(.))"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="name(.)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="att-value">
      <xsl:choose>
        <xsl:when test="deltaxml:nearest-delta-is(., 'B')"></xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="deltaxml:attributeValue[deltaxml:nearest-delta-is(., 'A')]"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <!-- if the attribute is namespaced, we need to ensure that the mapping os in scope here -->
    <xsl:if test="not(namespace-uri(.) = ('', 
                                          'http://www.deltaxml.com/ns/non-namespaced-attribute', 
                                          'http://www.deltaxml.com/ns/xml-namespaced-attribute'))">
      <xsl:namespace name="{prefix-from-QName(QName(namespace-uri(.), name(.)))}" select="namespace-uri(.)"/>
    </xsl:if>
    
    <xsl:variable name="encoded-att" 
                  select="concat(generate-id(/*), ',', 
                                 $change-type, ',', 
                                 $att-name, if (string-length($att-value) gt 0) then ',' else '', $att-value)"/>
    
    <xsl:attribute name="{concat('ac:attr', count(preceding-sibling::*) + 1)}" select="$encoded-att"/>
  </xsl:template>
  
  <xsl:template name="output-attribute">
    <xsl:param name="attribute" as="element()" required="yes"/>
    <xsl:param name="version" as="xs:string" required="yes"/>
    <xsl:variable name="att-local-name" select="local-name($attribute)"/>
    
    <xsl:variable name="att-namespace">
      <xsl:choose>
        <xsl:when test="namespace-uri($attribute) = 'http://www.deltaxml.com/ns/non-namespaced-attribute'">
          <xsl:value-of select="''"/>
        </xsl:when>
        <xsl:when test="namespace-uri($attribute) = 'http://www.deltaxml.com/ns/xml-namespaced-attribute'">
          <xsl:value-of select="'http://www.w3.org/XML/1998/namespace'"/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="namespace-uri($attribute)"/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    
    <xsl:variable name="att-value" select="deltaxml:attributeValue[deltaxml:nearest-delta-is(., $version)]"/>
    
    <xsl:choose>
      <xsl:when test="prefix-from-QName(node-name($attribute)) = ('dxx', 'dxa')" >
        <xsl:attribute name="{$att-local-name}" namespace="{$att-namespace}" select="$att-value"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:attribute name="{name($attribute)}" namespace="{$att-namespace}" select="$att-value"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
</xsl:stylesheet>