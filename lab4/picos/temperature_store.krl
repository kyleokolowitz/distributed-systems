ruleset temperature_store {
    meta {
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }

    global {
        temperatures = function() {
            ent:temperatures
        }

        threshold_violations = function() {
            ent:threshold_violations
        }

        inrange_temperatures = function() {
            ent:temperatures.filter(function(x) {threshold_violations().index(x) == -1})
        }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading 
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        fired {
            ent:temperatures := ent:temperatures.defaultsTo([]).append({"timestamp": timestamp, "temperature": temperature})
        }
    }

    rule collect_threshold_violations {
        select when wovyn threshold_violation 
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"}
        }
        always {
            ent:threshold_violations := ent:threshold_violations.defaultsTo([]).append({"timestamp": timestamp, "temperature": temperature})
        }
    }

    rule clear_temperatures {
        select when sensor reading_reset 
        always {
            ent:temperatures := []
            ent:threshold_violations := []
        }
    }
}