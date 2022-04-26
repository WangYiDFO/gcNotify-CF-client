<cfcomponent name="GCNotifyClient" displayName="GCNotifyClient" output="false"	hint="Client to GC Notify Service.">

    <!--- GC Notify API service endpoint URL Definition. Add more for ex SMS, template, Callback in future--->
    <cfset GCNotifyEmailPostAPI = "/v2/notifications/email">

    <!--- GC Notify APIKey definition --->
    <cfset apiKeyMinimumLength = 74>
    <cfset serviceIDStartPosition = 73>
    <cfset secretIDStartPositioin = 36>
    <cfset uuidLength = 36>

    <!--- GC Notify API Service Email Post definition --->
    <cfset EmailPostContentType = "application/json">
    <cfset EmailPostAuthorizationPrefix ="ApiKey-v1 ">
    <cfset EmailPostUserAgent = "gcNotify-CF-client">
    
    <cfset EmailAttachmentFileSizeLimitEachFile = 2 * 1024 * 1024>
    <cfset EmailAttachmentFileSizeLimitOverAll = 10 * 1024 * 1024>


    <cffunction name="init" type="public" returntype="GCNotifyClient" output="false" hint="Constructor function configuring the connection settings for an account.">
        <cfargument name="apiKey" type="string" required="true" hint="apiKey of your Service. reference https://documentation.notification.canada.ca/en/start.html.">
        <cfargument name="GCNotifyBaseURL" type="string" required="false" default="https://api.notification.canada.ca" hint="GC Notify Base URL">
        
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

    <cffunction name="NewGCNotifyEmailStruct" access="public" returntype="struct" output="false" hint="Return a new Struct of GC Notify EmailOjbect">
        
        <cfset emailBodyStruct = StructNew()>
        <cfset emailBodyStruct["template_id"] = "">
        <cfset emailBodyStruct["email_address"] = "">        
        <cfset emailBodyStruct["reference"] = "">
        <cfset emailBodyStruct["email_reply_to_id"] = "">
        <cfset emailBodyStruct["personalisation"] = structNew()>
        <cfset emailBodyStruct["attachment"] = arrayNew(1)>
        <cfset emailBodyStruct["all_attachments_size"] = 0>

        <cfreturn emailBodyStruct>
    </cffunction>

    <cffunction name="AddAttachment" access="public" returntype="boolean" output="false" hint="Prepare attachment file.">
        <cfargument name="EmailStruct" type="struct" required="true" hint="emailstruct GC Notify Client created">
		<cfargument name="Filepath" type="string" required="true" hint="absolute file path to attached to email">
        <cfargument name="AttachAsLink" type="boolean" required="false" default="false" hint="attach file as download link? If yes, must have ((link_to_file)) in email Template">

        <cfif isNull(arguments.emailStruct["attachment"]) OR NOT IsArray(arguments.emailStruct["attachment"])>
            <cfthrow message="GC Notify Client Send Email error."
                    detail="Please use GC Notify Client generate valid email StructTemplate ID not provided.">
        </cfif>

        <cfif NOT FileExists(arguments.Filepath)>
            <cfthrow message="GC Notify Client error."
                    detail="File you are trying to attach, does not exist.">
        </cfif>
        
        <cfset fileinfo = GetFileInfo(arguments.Filepath)>
        
        <cfif fileinfo.Size GT EmailAttachmentFileSizeLimitEachFile>
            <cfthrow message="GC Notify Client error."
                    detail="Single attachment size limited to 2M.">
        </cfif>

        <cfif arguments.emailStruct["all_attachments_size"] + fileinfo.Size GT EmailAttachmentFileSizeLimitOverAll>
            <cfthrow message="GC Notify Client error."
                    detail="Overall file attachments size limited to 10M.">
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

        <cfset arrayAppend(arguments.emailStruct["attachment"], attachStruct, "true")>

        <cfset arguments.emailStruct["all_attachments_size"] = arguments.emailStruct["all_attachments_size"] + fileinfo.Size>

        <cfreturn true>

	</cffunction>

    <cffunction name="SendEmail" access="public" returntype="any" output="false" hint="Send Email without attached file.">
        <cfargument name="emailStruct" type="struct" required="true" hint="GC Notify Email Struct, created by GC Notify Client">

        <cfif isNull(arguments.emailStruct["template_id"]) OR arguments.emailStruct["template_id"] EQ "">
            <cfthrow message="GC Notify Client Send Email error."
                    detail="Template ID not provided.">
        </cfif>
        <cfif isNull(arguments.emailStruct["email_address"]) OR arguments.emailStruct["email_address"] EQ "">
            <cfthrow message="GC Notify Client Send Email error."
                    detail="recipient email_address not provided.">
        </cfif>

        <cfif isNull(arguments.emailStruct["personalisation"]) OR NOT isStruct(arguments.emailStruct["personalisation"])>
            <cfthrow message="GC Notify Client Send Email error."
                    detail="personalisation data provided is invalid. use NewGCNotifyEmailStruct create correct data structure.">
        </cfif>

        <cfif isArray(arguments.emailStruct["attachment"])>
            <cfloop index="i" from="1" to="#arrayLen(arguments.emailStruct["attachment"])#">
                <cfset emailBodyStruct["personalisation"]["file_attachment"&i] = arguments.emailStruct["attachment"][i]>   
            </cfloop>
        </cfif>

        <!--- clean up struct data --->
        <cfif arguments.emailStruct["personalisation"].isEmpty()>
            <cfset structDelete(arguments.emailStruct, "personalisation")>            
        </cfif>
        <cfif isNull(arguments.emailStruct["email_reply_to_id"]) OR arguments.emailStruct["email_reply_to_id"] EQ "">
            <cfset structDelete(arguments.emailStruct, "email_reply_to_id")>
        </cfif>
        <cfif isNull(arguments.emailStruct["reference"])  OR arguments.emailStruct["reference"] EQ "">
            <cfset structDelete(arguments.emailStruct, "reference")>
        </cfif>
        <cfset structDelete(arguments.emailStruct, "attachment")>
        <cfset structDelete(arguments.emailStruct, "all_attachments_size")>


        <cfset jsonEmailBody = serializeJSON(arguments.emailStruct)>

        <!---cfreturn jsonEmailBody--->

        <cfhttp url="#getProperty("GCNotifyBaseURL")&GCNotifyEmailPostAPI#" 
                useragent="#EmailPostUserAgent#"
                method="POST" 
                result="CFHTTPResult" 
                throwOnError="no">
            <cfhttpparam type="HEADER" name="Content-Type" value="#EmailPostContentType#">
            <cfhttpparam type="HEADER" name="Content-Length" value="#len(jsonEmailBody)#">
            <cfhttpparam type="HEADER" name="Authorization" value="#EmailPostAuthorizationPrefix&getProperty("secretID")#">

            <cfhttpparam type="body" value="#Trim(jsonEmailBody)#">
        </cfhttp>

		<cfreturn CFHTTPResult>
	</cffunction>

</cfcomponent>
