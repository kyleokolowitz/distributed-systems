ruleset wovyn_base {
    meta {
        use module io.picolabs.subscription alias subscription
        use module sensor_profile
    }

    global {
        managers = function() {
            subscription:established().filter(function(sensor) {
                sensor["Tx_role"] == "manager"
            });
        }
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
        foreach managers() setting (m)
            pre {
                temperature = event:attrs{"temperature"}
                timestamp = event:attrs{"timestamp"}
                profile = sensor_profile:profile().klog("Profile");
                name = profile["name"];
                manager = m.klog("Mangager: ")
                eci = manager["Tx"]
            }
            event:send({
                "eci": eci,
                "domain": "sensor", 
                "name": "threshold_violation",
                "attrs": {
                    "sensor": name,
                    "temperature": temperature,
                    "timestamp": timestamp
                }
            })
    }

}