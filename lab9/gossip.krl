ruleset gossip {
    meta {
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
        shares tempLogs, tempViolationLogs, thresholdViolationCounter, myHighestSeenSequences, peersStates, peers, sensorId
        provides sensorId
    }

    global {

        sensorId = function() {
            ent:mySensorId;
        }

        process = function() {
            ent:process.defaultsTo(true);
        }

        nodeSubscriptions = function() {
            subscription:established().filter(function(sensor) {
                sensor["Tx_role"] == "node"
            })
        }

        peers = function() {
            subscription:established().filter(function(sensor) {
                sensor["Tx_role"] == "node" && ent:peerSensorIds{sensor["Id"]} != null
            }).map(function(v, k) {
                return {
                    "Tx": v["Tx"],
                    "Rx": v["Rx"],
                    "sensorId": ent:peerSensorIds{v["Id"]}
                };
            });
        }

        getPeer = function() {
            peers(){[random:integer(peers().length()-1)]}
        }

        getPeerInNeed = function() {
            peersInNeed = peers().filter(function(peer) {
                myHighestSeenSequences().filter(function(v,k){
                    peersStates(){[peer["sensorId"], k]}.defaultsTo(-1) < v
                }).length() > 0
            });
            return peersInNeed{[random:integer(peersInNeed.length()-1)]}
        }

        prepareRumorMessage = function(peer) {
            neededPeer = myHighestSeenSequences().filter(function(v,k){
                peersStates(){[peer["sensorId"], k]}.defaultsTo(-1) < v
            }).keys()[0]
            neededSequenceId = peersStates(){[peer["sensorId"], neededPeer]}.defaultsTo(-1) + 1
            messageId = neededPeer + ":" + neededSequenceId
            return (ent:tempLogs{[neededPeer, messageId]} != null) => ent:tempLogs{[neededPeer, messageId]} | ent:tempViolationLogs{[neededPeer, messageId]}
        }

        prepareRumorForPeerInNeed = function() {
            prepareRumorMessage(getPeerInNeed())
        }

        prepareSeenMessage = function() {
            myHighestSeenSequences()
        }

        peersStates = function() {
            ent:peersStates.defaultsTo({})
        }

        tempLogs = function() {
            ent:tempLogs.defaultsTo({})
        }

        tempViolationLogs = function() {
            ent:tempViolationLogs.defaultsTo({})
        }

        myHighestSeenSequences = function() {
            ent:myHighestSeenSequences.defaultsTo({}) 
        }

        thresholdViolationCounter = function() {
            tempViolationLogs().values().reduce(function(a,b) {
                a.values().append(b.values())
            }).reduce(function(a,b) {
                a + b{"threshold_violation"}
            }, 0)
        }

        sendRumor = defaction(peerRx, message) {
            event:send({ 
                "eci": peerRx, 
                "eid": "rumor",
                "domain": "gossip", "type": "rumor",
                "attrs": {
                    "message": message
                }
            })
        }

        sendMessage = defaction(peer, messageType, message) {            
            event:send({ 
                "eci": peer{"Tx"}, 
                "eid": messageType,
                "domain": "gossip", "type": messageType,
                "attrs": {
                    "peerSensorId": sensorId(),
                    "peerRx": peer{"Rx"},
                    "message": message
                }
            });
        }
    }

    rule reset_gosip {
        select when gossip:reset
        always {
            //raise gossip event "stop_heartbeat"
            ent:period := 5;
            ent:process := true;
            ent:tempLogs := {}
            ent:tempViolationLogs := {}
            ent:peersStates := {}
            ent:myHighestSeenSequences := {}
            ent:threshold_violation := -1
        }
    }

    rule start_heartbeat {
        select when gossip:start_heartbeat
        pre {
            period = ent:period.defaultsTo(5)
        }
        always {
            schedule gossip event "gossip_heartbeat" repeat << */#{period} * * * * * >> attributes { } setting(id);
            ent:heartbeat_id := id;
        }
    }

    rule stop_heartbeat {
        select when gossip:stop_heartbeat
        if ent:heartbeat_id then 
            schedule:remove(ent:heartbeat_id);
    }

    rule new_heartbeat_period {
        select when gossip:new_heartbeat_period
        pre {
            period = event:attrs{"period"};
            currentPeriod = ent:period.klog("Current period: ")
        }
        always {
            ent:period := period;
            raise gossip event "stop_heartbeat"
            raise gossip event "start_heartbeat"
        }
    }

    rule process_changed {
        select when gossip:process_changed
        pre {
            process = event:attrs{"status"} == "on" // on | off
        }
        always {
            ent:process := process
        } 
    }

    rule new_temperature_reading {
        select when wovyn:new_temperature_reading
        pre {
            temperature = event:attrs{"temperature"};
            timestamp = event:attrs{"timestamp"} || time:now()
            sensorId = ent:mySensorId
            sequenceId = ent:myHighestSeenSequences{sensorId}.defaultsTo(-1) + 1
            messageId = sensorId + ":" + sequenceId
        }
        always {
            ent:tempLogs{[sensorId, messageId]} := {
                "messageId": messageId,
                "sensorId": sensorId,
                "rumorType": "temperature",
                "temperature": temperature,
                "timestamp": timestamp
            }.klog("rumor: ")
            ent:myHighestSeenSequences{sensorId} := sequenceId
        }
    }

    rule threshold_notification {
        select when gossip:threshold_violation
        pre {
            timestamp = event:attrs{"timestamp"} || time:now()
            in_threshold_violation = event:attrs{"in_threshold_violation"}
            sensorId = ent:mySensorId
            sequenceId = ent:myHighestSeenSequences{sensorId}.defaultsTo(-1) + 1
            messageId = sensorId + ":" + sequenceId
            statusChanged = in_threshold_violation != ent:threshold_violation.defaultsTo(-1)
            threshold_violation = ent:threshold_violation.defaultsTo(-1) * -1
        }
        if statusChanged then noop();
        fired {
            ent:threshold_violation := threshold_violation
            ent:tempViolationLogs{[sensorId, messageId]} := {
                "messageId": messageId,
                "sensorId": sensorId,
                "rumorType": "threshold_violation",
                "threshold_violation": threshold_violation,
                "timestamp": timestamp
            }.klog("rumor: ")
            ent:myHighestSeenSequences{sensorId} := sequenceId
        }
    }

    rule gossip_heartbeat {
        select when gossip:gossip_heartbeat
        pre {
            messageType = (random:integer(1) == 0 => "rumor" | "seen").klog("Message type: ")
            peer = (messageType == "rumor" => getPeerInNeed() | getPeer()).klog("peer: ")
            message = (messageType == "rumor" => prepareRumorMessage(peer) | prepareSeenMessage()).klog("message: ")
            sequenceId = messageType == "rumor" => message{"messageId"}.split(re#:#)[1].as("Number") | null
        }               
        if process() && peer != null then sendMessage(peer, messageType, message);
        fired {
            ent:peersStates{[peer{"sensorId"}, message{"sensorId"}]} := sequenceId if messageType == "rumor"
        } 
    }

    rule gossip_rumor {
        select when gossip:rumor
        if process() then noop();
        fired {
            raise gossip event "process_rumor" attributes event:attrs
        }
    }

    rule process_gossip_rumor {
        select when gossip:process_rumor
        pre {
            message = event:attrs{"message"}.klog("Message: ")
            messageId = message{"messageId"}
            sensorId = message{"sensorId"}
            rumorType = message{"rumorType"}
            temperature = message{"temperature"}
            timestamp = message{"timestamp"}
            sequenceId = messageId.split(re#:#)[1].as("Number")
            mySequenceId = ent:myHighestSeenSequences{sensorId}.defaultsTo(-1)
        }
        if mySequenceId + 1 == sequenceId then noop();
        fired {
            ent:myHighestSeenSequences{[sensorId]} := sequenceId;
        }
        finally {
            ent:tempLogs{[sensorId, messageId]} := message if rumorType == "temperature"
            ent:tempViolationLogs{[sensorId, messageId]} := message if rumorType == "threshold_violation"
        }
    }

    rule gossip_seen {
        select when gossip:seen
        pre {
            peerSensorId = event:attrs{"peerSensorId"}.klog("peerSensorId: ")
            peerRx = event:attrs{"peerRx"}.klog("peerRx: ")
            seenMessages = event:attrs{"message"}
        }
        if process then noop();
        fired {
            ent:peersStates{peerSensorId} := seenMessages
            raise gossip event "compare_seen" attributes event:attrs
        }
    }

    rule gossip_compare_seen {
        select when gossip:compare_seen
        foreach myHighestSeenSequences().keys() setting(sensorId)
            pre {
                peerSensorId = event:attrs{"peerSensorId"}
                peerRx = event:attrs{"peerRx"}
                seenMessages = event:attrs{"message"}
                highestSequenceId = seenMessages{sensorId}.defaultsTo(-1)
                mySequenceId = ent:myHighestSeenSequences{sensorId}
            }
            if mySequenceId > highestSequenceId then noop();
            fired {
                raise gossip event "send_missing_message" attributes {"peerSensorId": peerSensorId, "peerRx": peerRx, "sensorId": sensorId, "highestSequenceId": highestSequenceId}
            }
    }

    rule send_missing_message {
        select when gossip:send_missing_message
        pre {
            peerSensorId = event:attrs{"peerSensorId"}
            peerRx = event:attrs{"peerRx"}
            sensorId = event:attrs{"sensorId"}
            highestSequenceId = event:attrs{"highestSequenceId"}
            mySequenceId = ent:myHighestSeenSequences{sensorId}
            newHighestSequenceId = highestSequenceId + 1

            messageId = sensorId + ":" + (newHighestSequenceId)
            message = ((ent:tempLogs{[sensorId, messageId]} != null) => ent:tempLogs{[sensorId, messageId]} | ent:tempViolationLogs{[sensorId, messageId]}).klog("message: ")
        }
        if mySequenceId > highestSequenceId then sendRumor(peerRx, message);
        fired {
            ent:peersStates{[peerSensorId, sensorId]} := newHighestSequenceId
            raise gossip event "send_missing_message" attributes {"peerSensorId": peerSensorId, "peerRx": peerRx, "sensorId": sensorId, "highestSequenceId": newHighestSequenceId}
        }
    }

    rule initialize {
        select when gossip:initialize
        always {
            ent:mySensorId := random:uuid();
            raise gossip event "reset"
            raise gossip event "update_peer_ids"
        }
    }

    rule updatePeerIds {
        select when gossip:update_peer_ids
        foreach nodeSubscriptions() setting(node)
            pre {
                id = node["Id"]
                tx = node["Tx"]
                sensorId = wrangler:picoQuery(tx, "gossip", "sensorId");
            }
            fired {
                ent:peerSensorIds{id} := sensorId;
            }
    }
}