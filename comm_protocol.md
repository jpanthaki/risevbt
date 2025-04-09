Sensor Communication Protocol:

Send data in batches with labels. Data in JSON format. Note that dict values must have quotations "".

App will communicate with sensor when it's ready to start recording. Sensor should not send information
before this.

Sensor should either:

    Send 2 packets of data at the top of each rep

    or

    Send a packet each time a direction change is detected (ideal)

We should explore:

    multithreading: one thread to read from sensor, one thread to send, if possible... 




Packet Format:

{
    "packet_time_stamp": //self explanatory,
    "dir": "ecc" or "con"  // which part of the rep (eccentric vs concentric); we care more about concentric for metrics.
    "data": "[
        {
            "time_stamp": ,
            "velocity": ,
            "accel": ,
            "pitch": ,
            "yaw": ,
            ... (add other interesting metric values here)
        }
    ]
}