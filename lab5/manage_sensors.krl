ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias wrangler
        shares sensors, temperatures
    }

    global {
        default_notification_number = "9378290896"
        default_temperature_threshold = 75

        sensors = function() {
            ent:sensors
        }

        install_ruleset = defaction(eci, name, ruleset_name, url) {
            event:send({ 
                "eci": eci, 
                "eid": "install-ruleset",
                "domain": "wrangler", "type": "install_ruleset_request",
                "attrs": {
                    "absoluteURL": url,
                    "rid": ruleset_name,
                    "config": {},
                    "name": name
                }
            })
        }

        temperatures = function() {
            sensors().map(function(v, k) {
                wrangler:picoQuery(v["eci"], "temperature_store", "temperatures");
            });
        }
    }

    rule create_sensor {
        select when sensor:new_sensor
        pre {
            name = event:attrs{"name"}
            exists = ent:sensors && ent:sensors >< name
        }
        if exists then 
            send_directive("Sensor already exists", {"name": name})
            
        notfired {
            ent:sensors := ent:sensors.defaultsTo({}).put([name], "")
            raise wrangler event "new_child_request"
                attributes { "name": name, "backgroundColor": "#ae85f9" }
        }
    }

    rule child_created {
        select when wrangler new_child_created
        pre {
            eci = event:attrs{"eci"}
            name = event:attrs{"name"}
        }
        every {
            install_ruleset(eci, name, "sensor_profile", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab5/sensor_profile.krl")
            install_ruleset(eci, name, "temperature_store", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab5/temperature_store.krl")
            install_ruleset(eci, name, "wovyn_base", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab5/wovyn_base.krl")
            install_ruleset(eci, name, "io.picolabs.wovyn.emitter", "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl")
            event:send({ 
                "eci": eci, 
                "eid": "profile-updated", 
                "domain": "sensor", "type": "profile_updated",
                "attrs": {
                    "name" : name,
                    "contact_number": default_notification_number,
                    "threshold" : default_temperature_threshold
                }
            })
        }
        fired {
            ent:sensors := ent:sensors.set([name], {"eci": eci})
        }
    }

    rule sensor_unneeded {
        select when sensor unneeded_sensor
        pre {
            name = event:attrs{"name"}
            exists = ent:sensors && ent:sensors >< name
            eci_to_delete = ent:sensors.get([name, "eci"])
        }
        if exists && eci_to_delete then
            send_directive("deleting_sensor", {"name": name})
        fired {
            raise wrangler event "child_deletion_request"
                attributes {"eci": eci_to_delete};
            ent:sensors := ent:sensors.delete([name])
        }
    }

    rule channel_created {
        select when sensor testing_channel_created
        pre {
            name = event:attrs{"name"}.klog("name: ")
            testing_eci = event:attrs{"testing_eci"}.klog("Testing_eci: ")
            eci = ent:sensors.get([name, "eci"])
        }
        always {
            ent:sensors{name} := {"eci": eci, "testing_eci": testing_eci}
        }
    }

}