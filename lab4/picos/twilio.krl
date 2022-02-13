ruleset twilio {
    meta {
        configure using 
            ssid = ""
            auth_token = ""
        provides messages, sendMessage
    }
    global {

        base_url = "https://api.twilio.com/2010-04-01"

        messages = function(to, from, pageSize, page, pageToken) {

            query_string = {"To": to, "From": from, "PageSize": pageSize || 50, "Page": page || 0, "PageToken": pageToken};
                
            http:get(<<#{base_url}/Accounts/#{ssid}/Messages.json>>, auth = {
                "username": ssid,
                "password": auth_token 
            }, qs = query_string){"content"}.decode()
        }

        sendMessage = defaction(to, from, body) {
            http:post(<<#{base_url}/Accounts/#{ssid}/Messages.json>>, auth = {
                "username": ssid,
                "password": auth_token 
            }, form = {
                "From": from,
                "To": to,
                "Body": body
            }, autoraise = "messageSent") setting(response)
            return response.klog("Response from Twilio module: ")
        }
    }
}