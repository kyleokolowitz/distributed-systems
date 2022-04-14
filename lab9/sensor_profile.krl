ruleset sensor_profile {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
        provides profile
        shares profile
    }

    global {

        channel_tags = ["testing"]
        channel_event_policy = {
            "allow": [ { "domain": "*", "name": "*" }, ],
            "deny": []
        }
        channel_query_policy = {
            "allow": [ { "rid": "*", "name": "*" } ],
            "deny": []
        }

        profile = function() {
            {
                "name": ent:name.defaultsTo("Sensor 1"),
                "location": ent:location.defaultsTo("Provo"),
                "contact_number": ent:contact_number.defaultsTo("9378290896"),
                "threshold": ent:temperature_threshold.defaultsTo(74)
            }
        }
    }

    rule update_profile {
        select when sensor:profile_updated 
        pre {
            name = event:attrs{"name"}
            location = event:attrs{"location"}
            contact_number = event:attrs{"contact_number"}
            threshold = event:attrs{"threshold"}
        }
        always {
            ent:name := name || ent:name
            ent:location := location || ent:location
            ent:contact_number := contact_number || ent:contact_number
            ent:temperature_threshold := threshold || ent:temperature_threshold
        }
    }

    rule ruleset_installed {
        select when wrangler ruleset_installed
            where event:attr("rids") >< meta:rid
        pre {
            name = event:attrs{"name"}.klog("name: ")
            parent_eci = wrangler:parent_eci()
            wellKnown_eci = subscription:wellKnown_Rx(){"id"}
        }
        every {
            wrangler:createChannel(channel_tags, channel_event_policy, channel_query_policy) setting(channel)
            event:send({ 
                "eci": parent_eci, 
                "eid": "testing_channel_created", 
                "domain": "sensor", "type": "testing_channel_created",
                "attrs": {
                    "name" : name,
                    "testing_eci": channel{"id"}
                }
            })
            event:send({
                "eci": parent_eci,
                "domain": "sensor", "type": "identify",
                "attrs": {
                    "name": name,
                    "wellKnown_eci": wellKnown_eci
                }
            })
        }
    }

}