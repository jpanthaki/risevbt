import asyncio
import threading
import matplotlib
import math
matplotlib.use("TkAgg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation
from bleak import BleakClient, BleakScanner
from collections import deque
import re
from time import sleep
from datetime import datetime
import csv
import tkinter as tk
from tkinter import ttk
import matplotlib.backends.backend_tkagg as tkagg
import json

json_filename = "imu_log.json"
logfile = open(json_filename, "a")  # append mode

# === CONFIG ===
DEVICE_NAME = "RiseVBT_sensor"
CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
COMMAND_CHARACTERISTIC_UUID = "1c902c8d-88bb-44f9-9dea-0bc5bf2d0af4"
buffer_size = 100
smooth_window = 5
USE_SMOOTHING = True
# csv_filename = "imu_log.csv"

# === Smoothing ===
def moving_average(data, window):
    if len(data) < window:
        return data
    return [sum(data[i - window:i]) / window for i in range(window, len(data) + 1)]


# === Kalman Filter Class ===
class KalmanFilter:
    def __init__(self, process_noise=1e-5, measurement_noise=1e-2, estimate_error=1.0):
        self.q = process_noise
        self.r = measurement_noise
        self.p = estimate_error
        self.x = 0.0

    def update(self, measurement):
        self.p += self.q
        k = self.p / (self.p + self.r)
        self.x += k * (measurement - self.x)
        self.p *= (1 - k)
        return self.x

# === Shared Buffers ===
shared_data = {
    "acc_x": deque(maxlen=buffer_size),
    "acc_y": deque(maxlen=buffer_size),
    "acc_z": deque(maxlen=buffer_size),
    "gyro_x": deque(maxlen=buffer_size),
    "gyro_y": deque(maxlen=buffer_size),
    "gyro_z": deque(maxlen=buffer_size),
    "vel_x": deque(maxlen=buffer_size),
    "vel_y": deque(maxlen=buffer_size),
    "vel_z": deque(maxlen=buffer_size),
}

kalman = {
    "vel_x": KalmanFilter(),
    "vel_y": KalmanFilter(),
    "vel_z": KalmanFilter(),
}

recording = True
lock = threading.Lock()
# logfile = open(csv_filename, "w", newline="")
# writer = csv.writer(logfile)
# writer.writerow([
#     "Time", "Acc X", "Acc Y", "Acc Z",
#     "Gyro X", "Gyro Y", "Gyro Z",
#     "Euler X", "Euler Y", "Euler Z",
#     "Calib Sys", "Calib Gyro", "Calib Accel", "Calib Mag"
# ])

# === BLE Notification Handler ===
# === BLE Notification Handler ===
last_time = None
vel = [0.0, 0.0, 0.0]
alpha = 0.5  # Low-pass filter coefficient (0 = smoothest, 1 = raw)

# Previous raw acceleration for filtering
acc_prev = [0.0, 0.0, 0.0]

# === BLE Notification Handler ===
last_time = None

def notification_handler(sender, data):
    try:
        raw_line = data.decode().strip()
        print(f"\n🔵 RAW: {raw_line}")

        packet = json.loads(raw_line)
        direction = packet.get("dir", "con")
        entries = packet.get("data", [])

        for entry in entries:
            timestamp = entry.get("time_stamp", 0)
            velocity = entry.get("velocity", 0)
            accel = entry.get("accel", 0)
            pitch = entry.get("pitch", 0)
            yaw = entry.get("yaw", 0)

            with lock:
                shared_data["vel_x"].append(velocity)
                shared_data["acc_z"].append(accel)
                shared_data["gyro_x"].append(pitch)
                shared_data["gyro_y"].append(yaw)

            if recording:
                log_entry = {
                    "time": datetime.now().isoformat(),
                    "dir": direction,
                    "timestamp": timestamp,
                    "velocity": velocity,
                    "accel": accel,
                    "pitch": pitch,
                    "yaw": yaw
                }
                json.dump(log_entry, logfile)
                logfile.write("\n")
                print("✅ Logged and appended")

    except Exception as e:
        print(f"❌ Failed to parse or handle data: {e}")



# === BLE Thread ===
async def ble_loop():
    print("🔍 Scanning for device...")
    devices = await BleakScanner.discover()
    target = next((d for d in devices if d.name and DEVICE_NAME in d.name), None)

    if not target:
        print(f"❌ Device {DEVICE_NAME} not found")
        return

    async with BleakClient(target.address) as client:
        print(f"✅ Connected to {DEVICE_NAME}")
        await client.write_gatt_char(COMMAND_CHARACTERISTIC_UUID, b"start", response=True)
        print("📡 Sent start command to device")

        await client.start_notify(CHARACTERISTIC_UUID, notification_handler)

        try:
            while True:
                await asyncio.sleep(1)
        except asyncio.CancelledError:
            pass
        finally:
            print("🛑 Sending stop command to device...")
            await client.write_gatt_char(COMMAND_CHARACTERISTIC_UUID, b"stop", response=True)
            await client.stop_notify(CHARACTERISTIC_UUID)



def start_ble_thread():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(ble_loop())

# === Plot Setup ===
fig, axs = plt.subplots(3, 1, figsize=(8, 8))
plots = {
    "acc": axs[0],
    "gyro": axs[1],
    "vel": axs[2],
}

lines = {}
unit_labels = {
    "acc": "Acceleration (m/s²)",
    "gyro": "Angular Velocity (°/s)",
    "vel": "Velocity (m/s)"
}
for key, ax in plots.items():
    ax.set_xlim(0, buffer_size)
    if key == "acc":
        ax.set_ylim(-1, 1)
    elif key == "gyro":
        ax.set_ylim(-50, 50)
    elif key == "vel":
        ax.set_ylim(-1, 1)

    ax.set_title(f"{key.upper()} - {unit_labels[key]}")
    ax.set_ylabel(unit_labels[key])


    # ax.set_title(key.upper())
    ax.grid(True)

lines["acc"] = [plots["acc"].plot([], [], label=axis)[0] for axis in "XYZ"]
lines["gyro"] = [plots["gyro"].plot([], [], label=axis)[0] for axis in "XYZ"]
lines["vel"] = [plots["vel"].plot([], [], label=axis)[0] for axis in "XYZ"]

for ax in axs:
    ax.legend()


def update(frame):
    with lock:
        acc = [list(shared_data[f"acc_{axis}"]) for axis in "xyz"]
        gyro = [list(shared_data[f"gyro_{axis}"]) for axis in "xyz"]
        vel = [list(shared_data[f"vel_{axis}"]) for axis in "xyz"]

    def safe_plot(ax, line_objs, data_group):
        ax.relim()
        ax.autoscale_view()
        for i in range(3):
            raw = data_group[i]
            if USE_SMOOTHING and len(raw) >= smooth_window:
                ydata = moving_average(raw, smooth_window)
                xdata = range(len(ydata))
            else:
                ydata = raw
                xdata = range(len(raw))
            line_objs[i].set_data(xdata, ydata)

    safe_plot(plots["acc"], lines["acc"], acc)
    safe_plot(plots["gyro"], lines["gyro"], gyro)
    safe_plot(plots["vel"], lines["vel"], vel)

    return sum(lines.values(), [])

# === Dashboard GUI ===
def toggle_recording():
    global recording
    recording = not recording
    record_btn.config(text="Pause Recording" if recording else "Resume Recording")

root = tk.Tk()
root.title("IMU BLE Dashboard")
record_btn = ttk.Button(root, text="Pause Recording", command=toggle_recording)
record_btn.pack(pady=10)

threading.Thread(target=start_ble_thread, daemon=True).start()
ani = FuncAnimation(fig, update, blit=False, interval=200)

canvas = tkagg.FigureCanvasTkAgg(fig, master=root)
canvas.draw()
canvas.get_tk_widget().pack(fill=tk.BOTH, expand=1)

root.protocol("WM_DELETE_WINDOW", lambda: (logfile.close(), root.destroy()))
root.mainloop()
