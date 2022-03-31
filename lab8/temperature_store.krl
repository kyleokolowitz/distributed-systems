ruleset temperature_store {
    meta {
        use module sensor_profile
        provides temperatures, threshold_violations, inrange_temperatures
        shares temperatures, threshold_violations, inrange_temperatures
    }

    global {

        temperatures = function() {
            ent:temperatures.defaultsTo([])
        }

        threshold_violations = function() {
            ent:threshold_violations.defaultsTo([])
        }

        inrange_temperatures = function() {
            ent:temperatures.filter(function(x) {threshold_violations().index(x) == -1})
        }
    }

    rule collect_temperatures {
        select when wovyn new_temperature_reading 
        pre {
            temperature = event:attrs{"temperature"}
            timestamp = event:attrs{"timestamp"} || time:now()
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

    rule temperature_report_requested {
        select when sensor temperature_report
        pre {
            rcn = event:attrs{"report_correlation_number"};
            originator_eci = event:attrs{"originator_eci"};
            sensor_eci = event:attrs{"sensor_eci"};
            name = sensor_profile:profile(){"name"};
        }
        event:send({
            "eci": originator_eci,
            "domain": "reports", 
            "name": "temperatures_collected",
            "attrs": {
                "report_correlation_number": rcn,
                "temperatures": {"sensor": name, "temperatures": temperatures()}
            }
        });
    }
    
        
}