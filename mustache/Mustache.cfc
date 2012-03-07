<!---
	Mustache.cfc
	https://github.com/pmcelhaney/Mustache.cfc
	
	The MIT License
	
	Copyright (c) 2009 Chris Wanstrath (Ruby)
	Copyright (c) 2010 Patrick McElhaney (ColdFusion)
	
	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:
	
	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.
	
	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
	LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
	OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
	WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--->
<cfcomponent output="false">

	<!---
		reference for string building
		http://www.aliaspooryorik.com/blog/index.cfm/e/posts.details/post/string-concatenation-performance-test-128
	--->

	<cfset variables.sectionRegEx = createObject("java","java.util.regex.Pattern").compile("\{\{(##|\^)\s*(\w+)\s*}}(.*?)\{\{/\s*\2\s*\}\}", 32)>
	<cfset variables.tagRegEx = createObject("java","java.util.regex.Pattern").compile("\{\{(!|\{|&|\>)?\s*(\w+|\.).*?\}?\}\}", 32) />

	<cffunction name="init" returntype="Mustache">
		<cfreturn this />
	</cffunction>

	<cffunction name="render" returntype="string" output="false">
		<cfargument name="template" default="#readMustacheFile(ListLast(getMetaData(this).name, '.'))#" type="string" />
		<cfargument name="context" default="#this#" />
		
		<cfset template = renderSections(template, context) />
		<cfset template = renderTags(template, context) />
		
		<cfreturn template />
	</cffunction>
	
	<!---
		SECTION
	--->
	
	<cffunction name="renderSections" access="private" returntype="string">
		<cfargument name="template" type="string" required="true" />
		<cfargument name="context" required="true" />
		
		<cfset var tag = ""/>
		<cfset var tagName = ""/>
		<cfset var type = "" />
		<cfset var inner = "" />
		<cfset var matches = arrayNew(1) />
		
		<cfloop condition="true">
			<cfset matches = reFindNoCaseValues(template, variables.sectionRegEx) />
			
			<cfif arrayLen(matches) EQ 0>
				<cfbreak>
			</cfif>
			
			<cfset tag = matches[1] />
			<cfset type = matches[2] />
			<cfset tagName = matches[3] />
			<cfset inner = matches[4] />
			
			<cfset template = replace(template, tag, renderSection(tagName, type, inner, context)) />
		</cfloop>
		
		<cfreturn template />
	</cffunction>

	<cffunction name="renderSection" access="private" returntype="string">
		<cfargument name="tagName" type="string" required="true" />
		<cfargument name="type" type="string" required="true" />
		<cfargument name="inner" type="string" required="true" />
		<cfargument name="context" required="true" />
		
		<cfset var ctx = get(tagName, context) />
		
		<cfif isStruct(ctx) AND !structIsEmpty(ctx)>
			<cfreturn render(inner, ctx) />
			
		<cfelseif isQuery(ctx) AND ctx.recordCount>
			<cfreturn renderQuerySection(inner, ctx) />
			
		<cfelseif isArray(ctx) AND !ArrayIsEmpty(ctx)>
			<cfreturn renderArraySection(inner, ctx) />
			
		<cfelseif structKeyExists(context, tagName) AND isCustomFunction(context[tagName])>
			<cfreturn evaluate("context.#tagName#(inner)") />
			
		</cfif>
		
		<cfif convertToBoolean(ctx) XOR type EQ "^">
			<cfreturn inner />
		</cfif>
		
		<cfreturn "" />
	</cffunction>

	<cffunction name="renderQuerySection" access="private" returntype="string">
		<cfargument name="template" type="string" required="true" />
		<cfargument name="context" type="query" required="true" />
		
		<cfset var result = [] />
		
		<cfloop query="context">
			<cfset arrayAppend(result, render(template, context)) />
		</cfloop>
		
		<cfreturn arrayToList(result, "") />
	</cffunction>

	<cffunction name="renderArraySection" access="private" returntype="string">
		<cfargument name="template" type="string" required="true" />
		<cfargument name="context" type="array" required="true" />
		
		<cfset var result = [] />
		<cfset var item = "" />
		
		<cfloop array="#context#" index="item">
			<cfif !isStruct(item)>
				<cfset item = { "." = item } />
			</cfif>
			<cfset arrayAppend(result, render(template, item)) />
		</cfloop>
		
		<cfreturn arrayToList(result, "") />
	</cffunction>
	
	<!---
		TAG
	--->

	<cffunction name="renderTags" access="private" returntype="string">
		<cfargument name="template" type="string" required="true" />
		<cfargument name="context" required="true" />
		
		<cfset var tag = ""/>
		<cfset var tagName = ""/>
		<cfset var matches = arrayNew(1) />
		
		<cfloop condition = "true" >
			<cfset matches = reFindNoCaseValues(template, variables.tagRegEx) />
			
			<cfif arrayLen(matches) EQ 0>
				<cfbreak>
			</cfif>
			
			<cfset tag = matches[1] />
			<cfset type = matches[2] />
			<cfset tagName = matches[3] />
			
			<cfset template = replace(template, tag, renderTag(type, tagName, context)) />
		</cfloop>
		
		<cfreturn template />
	</cffunction>

	<cffunction name="renderTag" access="private" returntype="string">
		<cfargument name="type" type="string" required="true" />
		<cfargument name="tagName" type="string" required="true" />
		<cfargument name="context" required="true" />
		
		<cfif type EQ "!">
			<cfreturn "" />
			
		<cfelseif type EQ "{" or type EQ "&">
			<cfreturn get(tagName, context) />
			
		<cfelseif type EQ ">">
			<cfreturn render(readMustacheFile(tagName), context) />
			
		</cfif>
		
		<cfreturn htmlEditFormat(get(tagName, context)) />
	</cffunction>
	
	<!---
		UTILITARY
	--->

	<cffunction name="convertToBoolean" access="private" returntype="boolean">
		<cfargument name="value" type="string" required="true" />
		<cfreturn isBoolean(value) OR ( isSimpleValue(value) AND value NEQ "" ) />
	</cffunction>
	
	<cffunction name="readMustacheFile" access="private" returntype="string">
		<cfargument name="filename" type="string" required="true" />
		<cfset var template = "" />
		<cffile action="read" file="#getDirectoryFromPath(getMetaData(this).path)##filename#.mustache" variable="template"/>
		<cfreturn trim(template) />
	</cffunction>
	
	<cffunction name="get" access="private">
		<cfargument name="key" type="string" required="true" />
		<cfargument name="context" required="true" />
    
		<cfif isQuery(context)>
			<cfif listContainsNoCase(context.columnList, key)>
				<cfreturn context[key][context.currentrow] />
			<cfelse>
				<cfreturn "" />
			</cfif>
		</cfif>
		
		<cfif not isStruct(context) OR not structKeyExists(context, key)>
			<cfreturn "" />
		</cfif>
		
		<cfif isCustomFunction(context[key])>
			<cfreturn evaluate("context.#key#('')") />
		<cfelse>
			<cfreturn context[key] />
		</cfif>
		
		<cfreturn "" />
	</cffunction>

	<cffunction name="ReFindNoCaseValues" access="private">
		<cfargument name="text" type="string" required="true" />
		<cfargument name="re" type="string" required="true" />
		
		<cfset var results = arrayNew(1) />
		<cfset var matcher = re.matcher(arguments.text)/>
		<cfset var i = 0 />
		<cfset var nextMatch = "" />
		
		<cfif matcher.Find()>
			<cfloop index="i" from="0" to="#matcher.groupCount()#">
				<cfset nextMatch = matcher.group(i) />
				<cfif isDefined('nextMatch')>
					<cfset arrayAppend(results, nextMatch) />
				<cfelse>
					<cfset arrayAppend(results, "") />
				</cfif>
			</cfloop>
		</cfif>
		
		<cfreturn results />
	</cffunction>

</cfcomponent>