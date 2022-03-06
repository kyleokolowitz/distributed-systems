ruleset manage_sensors {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
        shares sensors, temperatures
    }

    global {
        default_notification_number = "9378290896"
        default_temperature_threshold = 73

        sensors = function() {
            ent:sensors
        }

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

        temperatures = function() {
            subscription:established().filter(function(sensor) {
                sensor["Tx_role"] == "sensor"
            }).map(function(v, k) {
                wrangler:picoQuery(v["Tx"], "temperature_store", "temperatures");
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
            twilio_config = {"ssid": meta:rulesetConfig{"ssid"}, "auth_token": meta:rulesetConfig{"auth_token"}}
        }
        every {
            install_ruleset(eci, name, "sensor_profile", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab6/sensor_profile.krl", {})
            install_ruleset(eci, name, "temperature_store", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab6/temperature_store.krl", {})
            install_ruleset(eci, name, "twilio", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab6/twilio.krl", {})
            install_ruleset(eci, name, "wovyn_base", "file:///Users/kyleokolowitz/Repositories/distributed-systems/lab6/wovyn_base.krl", twilio_config)
            install_ruleset(eci, name, "io.picolabs.wovyn.emitter", "https://raw.githubusercontent.com/windley/temperature-network/main/io.picolabs.wovyn.emitter.krl", {})
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
        }
        finally {
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

    rule introduced_sensor {
        select when sensor introduced
        pre {
            name = event:attrs{"name"}
            wellKnown_eci = event:attrs{"wellKnown_eci"}
        }
        always {
            ent:sensors{name} := {"wellKnown_eci": wellKnown_eci}
            raise sensor event "new_subscription_request"
                attributes {
                    "wellKnown_eci": wellKnown_eci,
                    "name": name
                }
        }
    }

    rule accept_wellKnown {
        select when sensor identify
            name re#(.+)#
            wellKnown_eci re#(.+)#
            setting(name, wellKnown_eci)
        fired {
            ent:sensors{[name, "wellKnown_eci"]} := wellKnown_eci
            raise sensor event "new_subscription_request"
                attributes {
                    "wellKnown_eci": wellKnown_eci,
                    "name": name
                }
        }
    }

    rule make_a_subscription {
        select when sensor new_subscription_request
        event:send({
            "eci": event:attr("wellKnown_eci"),
            "domain": "wrangler", 
            "name": "subscription",
            "attrs": {
                "wellKnown_Tx":subscription:wellKnown_Rx(){"id"},
                "Rx_role":"sensor", 
                "Tx_role":"manager",
                "name": event:attr("name")+"-manager", 
                "channel_type":"subscription"
            }
        })
    }

    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            my_role = event:attr("Rx_role")
            their_role = event:attr("Tx_role")
        }
        if my_role=="manager" && their_role=="sensor" then noop()
        fired {
            raise wrangler event "pending_subscription_approval"
                attributes event:attrs
            ent:subscriptionTx := event:attr("Tx")
        } else {
            raise wrangler event "inbound_rejection"
                attributes event:attrs
        }
    }

}