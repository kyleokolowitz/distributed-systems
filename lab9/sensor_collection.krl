ruleset sensor_collection {
    meta {
        use module manager_profile
        use module twilio
          with
            ssid = meta:rulesetConfig{"ssid"}
            auth_token = meta:rulesetConfig{"auth_token"}
    }

    global {
        twilio_number = "+19377447172";
    }

    rule threshold_notification {
        select when sensor threshold_violation
        pre {
            temp = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
            profile = manager_profile:profile()
            contact_number = profile{"contact_number"}.klog("Contact Number:")
            msg = "Threshold Violation! Temperature: " + temp + ", Timestamp: " + timestamp
        }
        //twilio:sendMessage(contact_number, twilio_number, msg);
        always {
            log info "Notification msg: " + msg
        }
    }

}