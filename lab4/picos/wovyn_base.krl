ruleset wovyn_base {
    meta {
        use module sensor_profile
        use module twilio
          with
            ssid = meta:rulesetConfig{"ssid"}
            auth_token = meta:rulesetConfig{"auth_token"}
    }

    global {
        twilio_number = "+19377447172";
    }

    rule process_heartbeat {
        select when wovyn heartbeat 
        pre {
            genericThing = event:attrs{"genericThing"}.klog("GenericThing: ")
            genericTemp = genericThing["data"]["temperature"][0]["temperatureF"].klog("Generic Temp: ")
            timestamp = time:now()
        }
        if not genericThing.isnull() then send_directive("Temperature: " + genericTemp);
        fired {
            raise wovyn event "new_temperature_reading"
                attributes {
                    "temperature" : genericTemp,
                    "timestamp" : timestamp
                }
        }
    }

    rule find_high_temps {
        select when wovyn new_temperature_reading
        pre {
            temp = event:attrs{"temperature"}.klog("Temperature: ")
            timestamp = event:attrs{"timestamp"}
            profile = sensor_profile:profile().klog("Profile");
            temperature_threshold = profile{"threshold"}.klog("Thresh");
        }
        if temp > temperature_threshold then send_directive("Temperature above threshold");
        fired {
            raise wovyn event "threshold_violation"
                attributes {
                    "temperature" : temp,
                    "temperature_threshold": temperature_threshold,
                    "timestamp" : timestamp
                }
        }
    }

    rule threshold_notification {
        select when wovyn threshold_violation
        pre {
            temp = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
            profile = sensor_profile:profile().klog("Profile");
            contact_number = profile{"contact_number"}.klog("Contact Number:")
            msg = "Threshold Violation! Temperature: " + temp + ", Timestamp: " + timestamp
        }
        twilio:sendMessage(contact_number, twilio_number, msg);
        always {
            log info "Notification msg: " + msg
        }
    }

}