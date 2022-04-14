ruleset manage_managers {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
    }

    global {

        install_ruleset = defaction(eci, name, ruleset_name, url, config) {
            event:send({ 
                "eci": eci, 
                "eid": "install-ruleset",
                "domain": "wrangler", "type": "install_ruleset_request",
                "attrs": {
                    "absoluteURL": url,
                    "rid": ruleset_name,
                    "config": config,
                    "name": name
                }
            })
        }
    }

    rule create_sensor {
        select when sensor new_sensor
        pre {
            name = event:attrs{"name"}
        }
        always {
            ent:sensors := ent:sensors.defaultsTo({}).put([name], "")
            raise wrangler event "new_child_request"
                attributes { "name": name, "backgroundColor": "#85f789" }
        }
    }

    rule child_created {
        select when wrangler new_child_created
        pre {
            eci = event:attrs{"eci"}
            name = event:attrs{"name"}
            twilio_config = {"ssid": meta:rulesetConfig{"ssid"}, "auth_token": meta:rulesetConfig{"auth_token"}}
        }
        every {
            install_ruleset(eci, name, "twilio", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab9/twilio.krl", {})
            install_ruleset(eci, name, "sensor_collection", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab9/wovyn_base.krl", twilio_config)
            install_ruleset(eci, name, "manager_profile", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab9/manager_profile.krl", twilio_config)
            install_ruleset(eci, name, "manage_sensors", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab9/manage_sensors.krl", twilio_config)
            install_ruleset(eci, name, "gossip_manager", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab9/gossip_manager.krl", {})
        }
        fired {
            ent:sensors := ent:sensors.set([name], {"eci": eci})
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