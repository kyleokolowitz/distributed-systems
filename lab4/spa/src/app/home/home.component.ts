import { Component, OnInit } from '@angular/core';
import axios from "axios";


@Component({
    selector: 'app-home',
    templateUrl: './home.component.html',
    styleUrls: ['./home.component.css']
})
export class HomeComponent implements OnInit {

    constructor() { }

    ngOnInit(): void {
        this.refresh();
    }

    recentTemps = [
        { temperature: 0, timestamp: '0' },
    ];
    thesholdViolations = [
        { temperature: 0, timestamp: '0' },
    ];

    refresh() {
        console.log("refreshing...");
        this.fetchRecentTemps();
        this.fetchThresholdViolations();
    }

    async fetchRecentTemps() {
        let res = await axios.get("http://localhost:3000/sky/cloud/ckyvt5nvn001b3eou6nop1kpi/temperature_store/temperatures");
        console.log(res.data);
        this.recentTemps = res.data
        this.recentTemps.sort((a, b) => +new Date(b.timestamp) - +new Date(a.timestamp));
    }

    async fetchThresholdViolations() {
        let res = await axios.get("http://localhost:3000/sky/cloud/ckyvt5nvn001b3eou6nop1kpi/temperature_store/threshold_violations");
        console.log(res.data);
        this.thesholdViolations = res.data
        this.thesholdViolations.sort((a, b) => +new Date(b.timestamp) - +new Date(a.timestamp));
    }

    async resetReadings() {
        let res = await axios.get("http://localhost:3000/sky/event/ckyvt5nvn001b3eou6nop1kpi/none/sensor/reading_reset");
        this.refresh();
    }

}
