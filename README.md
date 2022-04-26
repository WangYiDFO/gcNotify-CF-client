# gcNotify-CF-client
Coldfusion component for easy access GC Notify service

Keep the public informed every step of the way
Try GC Notify, a better way to send service updates to your clients.

GC Notify is a government-run service, using it does not require any external procurement. You can send up to 10 million emails and 25,000 text messages per year for free for each of your Government of Canada services. No set up fee and no cost to use.

for more info: https://notification.canada.ca/

There are several client that availbe
https://documentation.notification.canada.ca/en/clients.html

We use Coldfusion on some of our applications, and this is to provide a Coldfusion client "library" for whom may interested.

Sample code to call this cfc componment

            <!---init gcNotifyClient object--->
	    <cfset gcNotifyClient = createObject("component", "GCNotifyClient").init(aipKey)>

            <cfset emailStruct = gcNotifyClient.NewGCNotifyEmailStruct()>

            <cfset emailStruct["template_id"] = TemplateID>
            <cfset emailStruct["email_address"] = ToEmail>
                       
            <cfset emailStruct["personalisation"]["first_name"] = "samplevalue">
            <cfset emailStruct["personalisation"]["poc_result"] = "sample_result">

            <cfset gcNotifyClient.AddAttachment(emailStruct,absolut_file_path)>

            <cfset emailResult = gcNotifyClient.SendEmail(emailStruct)>
	    
Please check emailResult.StausCode for successful. emailResult.filecontent has more info returned from GC Notify.
          

# Todo
add more implementation, full support GC Notify API. for ex. SMS, Callback, Notification
