<?xml version="1.0" encoding="UTF-8"?>
<!-- Copyright (c) 2012 DeltaXML Ltd. All rights reserved -->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0"
  xmlns:dxa="http://www.deltaxml.com/ns/non-namespaced-attribute"
  xmlns:dxx="http://www.deltaxml.com/ns/xml-namespaced-attribute"
  xmlns:deltaxml="http://www.deltaxml.com/ns/well-formed-delta-v1"
  xmlns:saxon="http://saxon.sf.net/"
  xmlns:preserve="http://www.deltaxml.com/ns/preserve"
  xmlns:xs="http://www.w3.org/2001/XMLSchema">

  <xsl:import href="functions/nearest-delta.xsl"/>
  <xsl:include href="functions/attribute-namespaces.xsl"/>

  <xsl:template match="/">
    <xsl:apply-templates mode="apply-ignore"/>
  </xsl:template>
  
  <!-- Usual XSLT2 identity transform to copy input to output -->
  <xsl:template match="@* | comment() | processing-instruction()" mode="apply-ignore">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()" mode="#current"/>
    </xsl:copy>
  </xsl:template>
  
  <!-- Don't copy the ignore-changes attribute to the output -->
  <xsl:template match="@deltaxml:ignore-changes" mode="apply-ignore"/>
  
  <!--
    Principles:
      if deltaV2='A' and nearest ignore-changes contains A then it goes in the result, similarly for B
      Any != in a deltaV2 inside @ignore-changes becomes =
      
      if deltaxml:attributes has an ancestor or self with @ignore-changes it will not appear in the result and vice-versa
      A textGroup, a deltaxml:attributes or deltaxml:attributes/* node with an ancestor or self deltaxml:ignore-changes will never appear in
      the result.  There will either be some text, attributes or nothing, depending on the ignore-changes setting and the attributes.
      The converse is also true, if there is not an ancestor ignore-changes then these elements appear in the result (unchanged).
      -->
  <xsl:template match="*" mode="apply-ignore">
    <xsl:variable name="nearest-ignore" as="xs:string?" select="deltaxml:neareset-ignore(.)"/>
    <xsl:choose>
      <xsl:when test="empty($nearest-ignore)">
        <xsl:copy>
          <xsl:apply-templates select="@*, deltaxml:attributes/*[@deltaxml:ignore-changes],
                                       deltaxml:attributes, node()[not(self::deltaxml:attributes)]"
                               mode="#current"/>
        </xsl:copy>
      </xsl:when>
      <xsl:when test="exists($nearest-ignore) and deltaxml:presence-in-result(., $nearest-ignore)">
        <xsl:copy>
          <xsl:if test="/*/@deltaxml:version eq '2.1' and /*/@deltaxml:meta-formatting-elements eq 'true'">
            <xsl:attribute name="deltaxml:ignored" select="'true'"/>
          </xsl:if>
          <xsl:attribute name="deltaxml:deltaV2" select="'A=B'"/>
          <xsl:apply-templates select="@* except (@deltaxml:deltaV2, @deltaxml:deltaTag, @deltaxml:deltaTagStart, @deltaxml:deltaTagMiddle,
            @deltaxml:deltaTagEnd)" mode="#current"/>
          <xsl:choose>
            <xsl:when test="starts-with($nearest-ignore, 'A')">
              <xsl:if test="self::preserve:ignorable and @deltaxml:deltaV2 eq 'A'">
                <xsl:attribute name="deltaxml:origin" select="'A'"/>
              </xsl:if>
              <xsl:apply-templates select="@deltaxml:deltaTag, @deltaxml:deltaTagStart, @deltaxml:deltaTagMiddle, @deltaxml:deltaTagEnd" mode="A-only"/>
            </xsl:when>
            <xsl:when test="starts-with($nearest-ignore, 'B')">
              <xsl:if test="self::preserve:ignorable and @deltaxml:deltaV2 eq 'B'">
                <xsl:attribute name="deltaxml:origin" select="'B'"/>
              </xsl:if>
              <xsl:apply-templates select="@deltaxml:deltaTag, @deltaxml:deltaTagStart, @deltaxml:deltaTagMiddle, @deltaxml:deltaTagEnd" mode="B-only"/>
            </xsl:when>
          </xsl:choose>
          <xsl:apply-templates select="deltaxml:attributes/*, node()[not(self::deltaxml:attributes)]" mode="#current"/>
        </xsl:copy>
      </xsl:when>
      <xsl:when test="exists($nearest-ignore) and not(deltaxml:presence-in-result(., $nearest-ignore))">
        <!-- don't copy elements, but do recurse -->
        <xsl:apply-templates select="node()[not(self::deltaxml:attributes)]" mode="#current"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">Illegal ignore change state</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
 
  <xsl:template match="@*[name(.) = ('deltaxml:deltaTag', 'deltaxml:deltaTagStart', 'deltaxml:deltaTagMiddle', 'deltaxml:deltaTagEnd')]" mode="A-only">
    <xsl:if test="contains(., 'A')">
      <xsl:attribute name="{name(.)}" select="'A'"/>
    </xsl:if>
  </xsl:template>
  <xsl:template match="@*[name(.) = ('deltaxml:deltaTag', 'deltaxml:deltaTagStart', 'deltaxml:deltaTagMiddle', 'deltaxml:deltaTagEnd')]" mode="B-only">
    <xsl:if test="contains(., 'B')">
      <xsl:attribute name="{name(.)}" select="'B'"/>
    </xsl:if>
  </xsl:template>

  <xsl:template match="text()" mode="apply-ignore">
    <xsl:variable name="nearest-ignore" as="xs:string?" select="deltaxml:neareset-ignore(.)"/>
    <xsl:choose>
      <xsl:when test="empty($nearest-ignore)">
        <xsl:copy/>
      </xsl:when>
      <xsl:when test="exists($nearest-ignore) and deltaxml:presence-in-result(., $nearest-ignore)">
        <xsl:copy/>
      </xsl:when>
      <xsl:when test="exists($nearest-ignore) and not(deltaxml:presence-in-result(., $nearest-ignore))">
        <!-- do nothing - no contribution to the result -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:message terminate="yes">Illegal ignore change state</xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <!--
    Determines whether an element is included/present in the result
    based on the nearest delta and nearest ignore.

    The follow table summarizes the behaviour, with Y corresponding
    to a true() result.

          ''  A   B   A,B  B,A/true

A          -   Y   -    Y    Y
B          -   -   Y    Y    Y
A=B        -   Y   Y    Y    Y
A!=B       -   Y   Y    Y    Y
  -->

  <xsl:function name="deltaxml:presence-in-result" as="xs:boolean">
    <xsl:param name="current-node" as="node()"/>
    <xsl:param name="nearest-ignore" as="xs:string"/> <!--'', 'A', 'B', 'A,B', 'B,A', 'true' -->
    <xsl:variable name="nearest-delta" as="xs:string" select="deltaxml:nearest-delta($current-node)"/>
    <xsl:variable name="delta-tags" as="xs:string" 
                  select="string-join(($current-node/@deltaxml:deltaTag,
                                       $current-node/@deltaxml:deltaTagStart, 
                                       $current-node/@deltaxml:deltaTagMiddle, 
                                       $current-node/@deltaxml:deltaTagEnd), '')"/>
    
   <!-- <xsl:message>presence: nearest: <xsl:value-of select="$nearest-ignore"/>, delta: <xsl:value-of select="$nearest-delta"/>.</xsl:message> -->
    <xsl:sequence select="if ($nearest-ignore eq '') then false()
                          else if ($nearest-ignore eq 'true' and $delta-tags eq '') then true()
                          else (contains($nearest-delta, 'A') and ($delta-tags eq '') and contains($nearest-ignore, 'A')) or
                               (contains($nearest-delta, 'B') and ($delta-tags eq '') and contains($nearest-ignore, 'B')) or
                               (contains($nearest-delta, 'B') and (contains($delta-tags, 'B')) and (starts-with($nearest-ignore, 'B') or $nearest-ignore eq 'true')) or
                               (contains($nearest-delta, 'A') and (contains($delta-tags, 'A')) and starts-with($nearest-ignore, 'A'))"/>
  </xsl:function>
  
  <!-- handle ignoring of text changes. -->
  <xsl:template match="deltaxml:textGroup" mode="apply-ignore">
    <xsl:variable name="nearest-ignore" as="xs:string?" select="deltaxml:neareset-ignore(.)"/>
    <xsl:choose>
      <xsl:when test="not(exists($nearest-ignore))">
        <xsl:copy-of select="."/>
      </xsl:when>

      <xsl:when test="$nearest-ignore eq ''">
        <!-- dont output anything -->
      </xsl:when>

      <xsl:when test="$nearest-ignore eq 'A'">
        <xsl:if test="exists(deltaxml:text[@deltaxml:deltaV2='A'])">
          <xsl:value-of select="deltaxml:text[@deltaxml:deltaV2='A']/text()"/>
        </xsl:if>
      </xsl:when>
      
      <xsl:when test="$nearest-ignore eq 'B'">
        <xsl:if test="exists(deltaxml:text[@deltaxml:deltaV2='B'])">
          <xsl:value-of select="deltaxml:text[@deltaxml:deltaV2='B']/text()"/>
        </xsl:if>
      </xsl:when>
      
      <xsl:when test="$nearest-ignore eq 'A,B'">
        <xsl:choose>
          <xsl:when test="deltaxml:text[@deltaxml:deltaV2='A']">
            <xsl:value-of select="deltaxml:text[@deltaxml:deltaV2='A']/text()"/>
          </xsl:when>
          <xsl:when test="deltaxml:text[@deltaxml:deltaV2='B']">
            <xsl:value-of select="deltaxml:text[@deltaxml:deltaV2='B']/text()"/>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      
      <xsl:when test="$nearest-ignore = ('B,A','true')">
        <xsl:choose>
          <xsl:when test="deltaxml:text[@deltaxml:deltaV2='B']">
            <xsl:value-of select="deltaxml:text[@deltaxml:deltaV2='B']/text()"/>
          </xsl:when>
          <xsl:when test="deltaxml:text[@deltaxml:deltaV2='A']">
            <xsl:value-of select="deltaxml:text[@deltaxml:deltaV2='A']/text()"/>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      
      <xsl:otherwise>
        <xsl:message terminate="yes">Unexpected ignore-change mask: <xsl:value-of select="$nearest-ignore"/></xsl:message>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>
  
  <xsl:template match="deltaxml:contentGroup" mode="apply-ignore">
    <xsl:variable name="nearest-ignore" as="xs:string?" select="deltaxml:neareset-ignore(.)"/>
    <xsl:choose>
      <xsl:when test="not(exists($nearest-ignore))">
        <xsl:copy-of select="."/>
      </xsl:when>
      
      <xsl:when test="$nearest-ignore eq ''">
        <!-- dont output anything -->
      </xsl:when>
      
      <xsl:when test="$nearest-ignore eq 'A'">
        <xsl:if test="exists(deltaxml:content[@deltaxml:deltaV2='A'])">
          <xsl:copy-of select="deltaxml:content[@deltaxml:deltaV2='A']/node()"/>
        </xsl:if>
      </xsl:when>
      
      <xsl:when test="$nearest-ignore eq 'B'">
        <xsl:if test="exists(deltaxml:content[@deltaxml:deltaV2='B'])">
          <xsl:copy-of select="deltaxml:content[@deltaxml:deltaV2='B']/node()"/>
        </xsl:if>
      </xsl:when>
      
      <xsl:when test="$nearest-ignore eq 'A,B'">
        <xsl:choose>
          <xsl:when test="deltaxml:content[@deltaxml:deltaV2='A']">
            <xsl:copy-of select="deltaxml:content[@deltaxml:deltaV2='A']/node()"/>
          </xsl:when>
          <xsl:when test="deltaxml:content[@deltaxml:deltaV2='B']">
            <xsl:copy-of select="deltaxml:content[@deltaxml:deltaV2='B']/node()"/>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      
      <xsl:when test="$nearest-ignore = ('B,A','true')">
        <xsl:choose>
          <xsl:when test="deltaxml:content[@deltaxml:deltaV2='B']">
            <xsl:copy-of select="deltaxml:content[@deltaxml:deltaV2='B']/node()"/>
          </xsl:when>
          <xsl:when test="deltaxml:content[@deltaxml:deltaV2='A']">
            <xsl:copy-of select="deltaxml:content[@deltaxml:deltaV2='A']/node()"/>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      
      <xsl:otherwise>
        <xsl:message terminate="yes">Unexpected ignore-change mask: <xsl:value-of select="$nearest-ignore"/></xsl:message>
      </xsl:otherwise>
    </xsl:choose>
    
  </xsl:template>
  
  
  <xsl:template match="deltaxml:attributes" mode="apply-ignore" >
    <xsl:variable name="nearest-ignore" as="xs:string?" select="deltaxml:neareset-ignore(.)"/>
    <xsl:choose>
      <xsl:when test="not(exists($nearest-ignore))">
        <xsl:apply-templates select="node()[@deltaxml:ignore-changes]" mode="#current"/>
        <xsl:copy>
          <xsl:apply-templates select="@*, node()[not(@deltaxml:ignore-changes)]" mode="#current"/>
        </xsl:copy>
      </xsl:when>
      <xsl:when test="$nearest-ignore eq ''">
        <!-- don't output anything -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="*" mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="deltaxml:attributes/*" mode="apply-ignore">
    <xsl:variable name="nearest-ignore" as="xs:string?" select="deltaxml:neareset-ignore(.)"/>
    <xsl:choose>
      <xsl:when test="not(exists($nearest-ignore))">
        <xsl:copy>
          <xsl:apply-templates select="@*, node()" mode="#current"/>
        </xsl:copy>
      </xsl:when>
      <xsl:when test="$nearest-ignore eq ''">
        <!-- don't output anything -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:copy-of select="deltaxml:generate-attribute(., $nearest-ignore)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:function name="deltaxml:neareset-ignore" as="xs:string?">
    <xsl:param name="n" as="node()"/>
    <xsl:sequence select="$n/ancestor-or-self::*[@deltaxml:ignore-changes][empty(@deltaxml:format)][1]/@deltaxml:ignore-changes"/>
  </xsl:function>
  
  <xsl:function name="deltaxml:generate-attribute" as="attribute()?">
    <xsl:param name="attribute-node" as="node()"/>
    <xsl:param name="ignore-mask" as="xs:string"/>
    
    <xsl:variable name="namespace" select="deltaxml:get-attribute-ns($attribute-node)"/>
    <xsl:variable name="local-name" select="local-name($attribute-node)"/>
    <xsl:variable name="qname" as="xs:QName" select="node-name($attribute-node)"/>
    <xsl:variable name="prefix" select="for $a in prefix-from-QName($qname) return if ($a = ('dxa','dxx')) then '' else $a"/>
    <xsl:variable name="qualified-name" select="if (string-length($prefix) eq 0) then $local-name else concat($prefix, ':', $local-name)"/>
    
    <xsl:choose>
      <xsl:when test="$ignore-mask=''"/>
      
      <xsl:when test="$ignore-mask='A'">
        <xsl:if test="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='A']">
          <xsl:attribute name="{$qualified-name}"  namespace="{$namespace}" select="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='A']"/>
        </xsl:if>
      </xsl:when>
      
      <xsl:when test="$ignore-mask='B'">
        <xsl:if test="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='B']">
          <xsl:attribute name="{$qualified-name}" namespace="{$namespace}" select="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='B']"/>
        </xsl:if>
      </xsl:when>
      
      <xsl:when test="$ignore-mask='A,B'">
        <xsl:choose>
          <xsl:when test="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='A']">
            <xsl:attribute name="{$qualified-name}" namespace="{$namespace}" select="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='A']"/>
          </xsl:when>
          <xsl:when test="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='B']">
            <xsl:attribute name="{$qualified-name}" namespace="{$namespace}" select="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='B']"/>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      
      <xsl:when test="$ignore-mask=('true','B,A')">
        <xsl:choose>
          <xsl:when test="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='B']">
            <xsl:attribute name="{$qualified-name}" namespace="{$namespace}" select="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='B']"/>
          </xsl:when>
          <xsl:when test="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='A']">
            <xsl:attribute name="{$qualified-name}" namespace="{$namespace}" select="$attribute-node/deltaxml:attributeValue[@deltaxml:deltaV2='A']"/>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      
      <xsl:otherwise>
        <xsl:message terminate="yes">Unexpected ignore-changes mask: <xsl:value-of select="$ignore-mask"/></xsl:message>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

</xsl:stylesheet>
