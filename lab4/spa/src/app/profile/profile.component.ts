import { Component, OnInit } from '@angular/core';
import axios from "axios";


@Component({
    selector: 'app-profile',
    templateUrl: './profile.component.html',
    styleUrls: ['./profile.component.css']
})
export class ProfileComponent implements OnInit {

    name = "";
    location = "";
    threshold = 0;
    contact_number = ""

    constructor() { }

    ngOnInit(): void {
        this.fetchProfile();
    }

    async fetchProfile() {
        let res = await axios.get("http://localhost:3000/sky/cloud/ckyvt5nvn001b3eou6nop1kpi/sensor_profile/profile");
        console.log(res.data);
        this.name = res.data.name;
        this.location = res.data.location;
        this.threshold = res.data.threshold;
        this.contact_number = res.data.contact_number;
    }

    async updateProfile(data: any) {
        let res = await axios.post("http://localhost:3000/sky/event/ckyvt5nvn001b3eou6nop1kpi/none/sensor/profile_updated", {
            "name": data.name,
            "location": data.location,
            "contact_number": data.contact_number,
            "threshold": data.threshold
        });
        console.log(res.data);
        this.fetchProfile();
    }
}
