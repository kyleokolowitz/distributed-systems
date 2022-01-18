ruleset twilio_tester {
    meta {
        use module twilio
          with
            ssid = meta:rulesetConfig{"ssid"}
            auth_token = meta:rulesetConfig{"auth_token"}
        shares messages
    }
    global {
        messages = function(to, from, pageSize, page, pageToken) {
            twilio:messages(to, from, pageSize, page, pageToken)
        }
    }

    rule send_message {
        select when send message
        pre {
            from = "+19377447172"
        }
        twilio:sendMessage(event:attr("to"), from, event:attr("body")) setting(response);
    }

    rule successful_message {
        select when http post 
            label re#messageSent#
            status_code re#(2\d\d)# setting (status)
            send_directive("Reponse", {"content": event:attr("content")});
    }
       
}