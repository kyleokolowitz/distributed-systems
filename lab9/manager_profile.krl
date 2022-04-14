ruleset manager_profile {
    meta {
        use module twilio
          with
            ssid = meta:rulesetConfig{"ssid"}
            auth_token = meta:rulesetConfig{"auth_token"}
        provides profile
        shares profile
    }

    global {
        twilio_number = "+19377447172";
        profile = function() {
            { "contact_number": ent:contact_number.defaultsTo("9378290896") }
        }
    }

    rule update_profile {
        select when sensor:profile_updated 
        pre {
            contact_number = event:attrs{"contact_number"}
        }
        always {
            ent:contact_number := contact_number || ent:contact_number
        }
    }

    rule send_notification {
        select when manager notification_send
        pre {
            contact_number = profile(){"contact_number"}
            message = event:attrs{"message"}
        }
        //twilio:sendMessage(contact_number, twilio_number, message);
        always {
            log info "Notification msg: " + message
        }
    }

}