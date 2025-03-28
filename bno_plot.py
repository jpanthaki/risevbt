import asyncio
import threading
import matplotlib
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

# === CONFIG ===
DEVICE_NAME = "JAMSHED_P"
CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8"
buffer_size = 100
smooth_window = 5
USE_SMOOTHING = True
csv_filename = "imu_log.csv"

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

recording = True
lock = threading.Lock()
logfile = open(csv_filename, "w", newline="")
writer = csv.writer(logfile)
writer.writerow(["Time", "Acc X", "Acc Y", "Acc Z", "Gyro X", "Gyro Y", "Gyro Z", "Vel X", "Vel Y", "Vel Z"])

# === Smoothing ===
def moving_average(data, window):
    if len(data) < window:
        return data
    return [sum(data[i - window:i]) / window for i in range(window, len(data) + 1)]

# === BLE Notification Handler ===
last_time = None
vel = [0.0, 0.0, 0.0]

def notification_handler(sender, data):
    global recording, last_time, vel
    line = data.decode().strip()
    print(f"\n🔵 RAW: '{line}'")

    match = re.search(
        r"LinAcc X:(-?\d+\.\d+)LinAcc Y:(-?\d+\.\d+)LinAcc Z:(-?\d+\.\d+);"
        r"Gyro X:(-?\d+\.\d+)Gyro Y:(-?\d+\.\d+)Gyro Z:(-?\d+\.\d+);"
        r"Roll \(Euler X\):(-?\d+\.\d+)Pitch \(Euler Y\):(-?\d+\.\d+)Yaw \(Euler Z\):(-?\d+\.\d+)",
        line
    )

    if match:
        now = datetime.now()
        if last_time is None:
            last_time = now

        dt = (now - last_time).total_seconds()
        last_time = now

        acc = [float(match.group(i)) for i in range(1, 4)]
        gyro = [float(match.group(i)) for i in range(4, 7)]

        vel = [v + a * dt for v, a in zip(vel, acc)]

        with lock:
            for axis, a in zip("xyz", acc):
                shared_data[f"acc_{axis}"].append(a)
            for axis, g in zip("xyz", gyro):
                shared_data[f"gyro_{axis}"].append(g)
            for axis, v in zip("xyz", vel):
                shared_data[f"vel_{axis}"].append(v)

        if recording:
            timestamp = now.isoformat()
            writer.writerow([timestamp] + acc + gyro + vel)
            print("✅ Logged and appended")
    else:
        print("❌ No match")

# === BLE Thread ===
async def ble_loop():
    print("🔍 Scanning for device...")
    devices = await BleakScanner.discover()
    target = None
    for d in devices:
        if d.name and DEVICE_NAME in d.name:
            target = d
            break

    if not target:
        print(f"❌ Device {DEVICE_NAME} not found")
        return

    async with BleakClient(target.address) as client:
        print(f"✅ Connected to {DEVICE_NAME}")
        await client.start_notify(CHARACTERISTIC_UUID, notification_handler)
        while True:
            await asyncio.sleep(1)

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
for key, ax in plots.items():
    ax.set_xlim(0, buffer_size)
    if key == "acc":
        ax.set_ylim(-2, 2)
    elif key == "gyro":
        ax.set_ylim(-10, 10)
    elif key == "vel":
        ax.set_ylim(-5, 5)
    ax.set_title(key.upper())
    ax.grid(True)

lines["acc"] = [plots["acc"].plot([], [], label=axis)[0] for axis in "XYZ"]
lines["gyro"] = [plots["gyro"].plot([], [], label=axis)[0] for axis in "XYZ"]
lines["vel"] = [plots["vel"].plot([], [], label=axis)[0] for axis in "XYZ"]

for ax in axs:
    ax.legend()

def update(frame):
    with lock:
        acc = [list(shared_data[f"acc_{axis.lower()}"]) for axis in "XYZ"]
        gyro = [list(shared_data[f"gyro_{axis.lower()}"]) for axis in "XYZ"]
        vel = [list(shared_data[f"vel_{axis.lower()}"]) for axis in "XYZ"]

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
