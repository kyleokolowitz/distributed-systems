ruleset gossip_manager {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
        use module manage_sensors
    }

    global {
        sensor_subscriptions = function() {
            subscription:established().filter(function(sensor) {
                sensor["Tx_role"] == "sensor"
            })
        }
    }

    rule reset_environment {
        select when gossip reset_environment
        always {
            raise manager event "delete_all_subscriptions"
            raise sensor event "unneeded_sensor" attributes {"name": "Sensor 1"}
            raise sensor event "unneeded_sensor" attributes {"name": "Sensor 2"}
            raise sensor event "unneeded_sensor" attributes {"name": "Sensor 3"}
            raise sensor event "unneeded_sensor" attributes {"name": "Sensor 4"}
            raise sensor event "unneeded_sensor" attributes {"name": "Sensor 5"}
            raise sensor event "new_sensor" attributes {"name": "Sensor 1"}
            raise sensor event "new_sensor" attributes {"name": "Sensor 2"}
            raise sensor event "new_sensor" attributes {"name": "Sensor 3"}
            raise sensor event "new_sensor" attributes {"name": "Sensor 4"}
            raise sensor event "new_sensor" attributes {"name": "Sensor 5"}
            raise gossip event "reset_gossip_environment"
        }
    }

    rule delete_all_subscriptions {
        select when manager delete_all_subscriptions
        foreach sensor_subscriptions() setting(subscription)
            pre {
                id = subscription{"Id"};
            }
            always {
                raise wrangler event "subscription_cancellation" attributes { "Id": id }
            }
    }

    rule reset_gossip_environment {
        select when gossip reset_gossip_environment
        foreach sensor_subscriptions() setting(subscription)
            pre {
                sensor_eci = subscription{"Tx"};
                manager_eci = subscription{"Rx"};
            }
            event:send({
                "eci": sensor_eci,
                "domain": "gossip", 
                "name": "reset",
                "attrs": {}
            });
    }

    rule start_gossip_environment {
        select when gossip start_gossip_environment
        foreach sensor_subscriptions() setting(subscription)
            pre {
                sensor_eci = subscription{"Tx"};
                manager_eci = subscription{"Rx"};
            }
            event:send({
                "eci": sensor_eci,
                "domain": "gossip", 
                "name": "start_heartbeat",
                "attrs": {}
            });
    }

}