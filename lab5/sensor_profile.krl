ruleset sensor_profile {
    meta {
        provides profile
        shares profile
    }

    global {
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
}