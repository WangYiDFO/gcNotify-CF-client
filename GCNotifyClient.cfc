<cfcomponent name="GCNotifyClient" displayName="GCNotifyClient" output="false"	hint="Client to GC Notify Service.">

    <cffunction name="init" type="public" returntype="GCNotifyClient" output="false" hint="Constructor function configuring the connection settings for an account.">
        <cfargument name="apiKey" type="string" required="true" hint="apiKey of your Service. reference https://documentation.notification.canada.ca/en/start.html.">
        <cfargument name="GCNotifyBaseURL" type="string" required="false" default="https://api.notification.canada.ca" hint="GC Notify Base URL">
        <cfargument name="GCNotifyEmailPostAPI" type="string" required="false" default="/v2/notifications/email" hint="GC Notify Email Post API, default to /v2/notifications/email">
        
        <cfset apiKeyMinimumLength = 74>
        <cfset serviceIDStartPosition = 73>
        <cfset secretIDStartPositioin = 36>
        <cfset uuidLength = 36>

        <cfif Len(arguments.apiKey) LT apiKeyMinimumLength OR FindNoCase(" ", arguments.apiKey)>
            <!--- if apiKey not in good length or contains empty char --->
            <cfthrow message="GC Notify API Key not valid."
                    detail="The API Key you provide not correct length, or contains empty char.">
        </cfif>

        <cfset serviceID = Mid(arguments.apiKey, Len(arguments.apiKey) - serviceIDStartPosition + 1, uuidLength)>
        <cfset secretID =  Mid(arguments.apiKey, Len(arguments.apiKey) - secretIDStartPositioin + 1, uuidLength)>
        <cfset clientInstance = hash(serviceID)>

        <cfif NOT IsDefined("#clientInstance#")>
            <cfset StructInsert(variables, "#clientInstance#", StructNew())>  
        </cfif>
        
        <cfset setProperty("serviceID", "#serviceID#")>
        <cfset setProperty("secretID", "#secretID#")>
        <cfset setProperty("GCNotifyBaseURL", arguments.GCNotifyBaseURL)>
        <cfset setProperty("GCNotifyEmailPostAPI", arguments.GCNotifyEmailPostAPI)>

        <cfset setProperty("Content-Type", "application/json")>
        <cfset setProperty("Authorization", "ApiKey-v1 "&getProperty("secretID"))>
        
        <!--- implenment singleton, so only one thread been called at a time --->
        <cfset setProperty("lockhash", hash(arguments.GCNotifyBaseURL&arguments.apiKey))>

        <cfreturn this>
    </cffunction>

    <cffunction name="setProperty" access="public" returntype="boolean" output="false"	hint="Sets a property in the object instance.">
		<cfargument name="property" type="string" required="true" hint="The name of the instance property to be set.">
		<cfargument name="propertyValue" type="any" required="true" hint="The value of the instance property to be set.">

        <cfset StructInsert(variables["#clientInstance#"], arguments.property, arguments.propertyValue, true)>

        <cfreturn true>
	</cffunction>

	<cffunction name="getProperty" access="public" returntype="any" output="false"	hint="Returns the value of the property in the object instance.">
		<cfargument name="property" type="string" required="true" hint="The name of the instance property to retrieve.">

		<cfreturn variables["#clientInstance#"][arguments.property]>
	</cffunction>


    <cffunction name="SendEmail" access="public" returntype="any" output="false" hint="Send Email without attached file.">
		<cfargument name="TemplateID" type="string" required="true" hint="GC Notify Email Template ID">
        <cfargument name="ToEmailAddress" type="string" required="true" hint="Recipient email">
        <cfargument name="Personalisation" type="struct" required="false" hint="Personalisation data according to your template">
        <cfargument name="Attachment" type="struct" required="false" hint="Attachment Struct, prepared by PrepareAttachment function">
        <cfargument name="ReferenceCode" type="string" required="false" hint="Refernce code, UNIQUE service wide, be CAREFULE set this value">
        <cfargument name="EmailReplyToID" type="string" required="false" hint="Reply-To uuid that set up on GC Notify">

        <!--- build json email body --->
        <cfset emailBodyStruct = StructNew()>
        <cfset emailBodyStruct["template_id"] = arguments.TemplateID>
        <cfset emailBodyStruct["email_address"] = arguments.ToEmailAddress>
        <cfif IsDefined("arguments.Personalisation") AND IsStruct(arguments.Personalisation)>
            <cfset emailBodyStruct["personalisation"] = arguments.Personalisation>
        </cfif>
        <cfif IsDefined("arguments.ReferenceCode")>
            <cfset emailBodyStruct["reference"] = arguments.ReferenceCode>
        </cfif>
        <cfif IsDefined("arguments.EmailReplyToID")>
            <cfset emailBodyStruct["email_reply_to_id"] = arguments.EmailReplyToID>
        </cfif>
        <cfif IsDefined("arguments.Attachment")>
            <cfif IsStruct(arguments.Attachment) 
                  AND StructKeyExists(arguments.Attachment,"sending_method") 
                  AND StructKeyExists(arguments.Attachment,"file") 
                  AND StructKeyExists(arguments.Attachment,"filename")
                  AND (arguments.Attachment["sending_method"] EQ "link" OR arguments.Attachment["sending_method"] EQ "attach") >
                <cfif arguments.Attachment["sending_method"] EQ "link">
                    <cfset emailBodyStruct["personalisation"]["link_to_file"] = arguments.Attachment>                
                <cfelse>
                    <cfset emailBodyStruct["personalisation"]["application_file"] = arguments.Attachment> 
                </cfif>                
            <cfelse>
                <cfthrow message="GC Notify Client error."
                    detail="Attachement Struct not valid, need to use PrepareAttachment function to generate proper struct.">
            </cfif>
        </cfif> 

        <cfset jsonEmailBody = serializeJSON(emailBodyStruct)>

        <!---cfreturn jsonEmailBody--->

		<cflock name="#getProperty("lockhash")#" type="exclusive" timeout="10">
            <cfhttp url="#getProperty("GCNotifyBaseURL")&getProperty("GCNotifyEmailPostAPI")#" method="POST" result="CFHTTPResult" throwOnError="no">
                <cfhttpparam type="HEADER" name="Content-Type" value="#getProperty("Content-Type")#">
                <cfhttpparam type="HEADER" name="Content-Length" value="#len(jsonEmailBody)#">
                <cfhttpparam type="HEADER" name="Authorization" value="#getProperty("Authorization")#">
    
                <cfhttpparam type="body" value="#Trim(jsonEmailBody)#">
            </cfhttp>
    	</cflock>

		<cfreturn CFHTTPResult>
	</cffunction>

    <cffunction name="PrepareAttachment" access="public" returntype="struct" output="false" hint="Prepare attachment file.">
		<cfargument name="Filepath" type="string" required="true" hint="absolute file path to attached to email">
        <cfargument name="AttachAsLink" type="boolean" required="false" default="false" hint="attach file as download link? If yes, must have ((link_to_file)) in email Template">

        <cfif NOT FileExists(arguments.Filepath)>
            <cfthrow message="GC Notify Client error."
                    detail="File you are trying to attach, does not exist.">
        </cfif>
        
        <cfset fileinfo = GetFileInfo(arguments.Filepath)>
        
        <cfif fileinfo.Size GT 2 * 1024 * 1024>
            <cfthrow message="GC Notify Client error."
                    detail="File size limited to 2M.">
        </cfif>
        
        <cfset filename = fileinfo.Name>
        <cfset fileextention = listLast(filename,".")>

        <cfset validExtName = ["pdf","csv","jpeg","png","odt","txt","rtf","doc","docx","xls","xlsx"]>
        <cfif NOT arrayFindNoCase(validExtName, fileextention)>
            <cfthrow message="GC Notify Client error."
                    detail="File type you are trying to attach is not supported.">
        </cfif>

        <cfset file64String = ToBase64(FileReadBinary(filepath))>
        
        <cfset attachStruct = structNew()>
        <cfset attachStruct["file"] = file64String>
        <cfset attachStruct["filename"] = filename>
        
        <cfif arguments.AttachAsLink>            
            <cfset attachStruct["sending_method"] = "link">
        <cfelse> 
            <cfset attachStruct["sending_method"] = "attach">
        </cfif>

        <cfreturn attachStruct>

	</cffunction>

</cfcomponent>